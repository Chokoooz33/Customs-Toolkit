import Foundation

/// Shared import-duty calculator used by both Air Services and Sea Services.
///
/// This engine intentionally remains separate from Difference Calculator because
/// the two features represent different operational workflows.
public enum DutyCalculatorService {
    public struct Configuration {
        /// Operating rule confirmed for Customs Toolkit:
        /// - CFR: add 1% insurance to the CFR amount to derive CIF.
        /// - FOB / EXW: add 1% insurance to Cost + Freight to derive CIF.
        public static let insuranceRate: Decimal = Decimal(string: "0.01")!

        /// Standard Oman VAT rate for this first operational workflow.
        public static let standardVATRate: Decimal = AppConfig.Calculator.defaultVatRate

        /// Used only when the operator explicitly chooses Quick Estimate.
        public static let quickEstimateDutyRate: Decimal = Decimal(string: "0.05")!

        /// Documentation guarantee is 2% of CIF when documents are not original
        /// and the final CIF is strictly greater than 1,000 OMR.
        public static let documentationGuaranteeRate: Decimal = Decimal(string: "0.02")!
        public static let documentationGuaranteeThresholdOMR: Decimal = Decimal(1000)
    }

    public static func parsePercentage(_ text: String?) -> Decimal? {
        guard let raw = text?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        let cleaned = raw
            .replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let percent = Decimal(string: cleaned), percent >= .zero else { return nil }
        return DecimalMath.divide(percent, by: Decimal(100))
    }

    /// Converts an amount to OMR using an operator-supplied customs exchange rate.
    /// `omrPerCurrencyUnit` means: 1 source currency unit = X OMR.
    public static func convertToOMR(
        amount: Decimal?,
        currency: Currency,
        omrPerCurrencyUnit: Decimal?
    ) -> Decimal? {
        guard let amount, amount >= .zero else { return nil }
        if currency == .omr { return amount }
        guard let rate = omrPerCurrencyUnit, rate > .zero else { return nil }
        return DecimalMath.multiply(amount, by: rate)
    }

    /// Calculates import duty, VAT, operational documentation charges and final payable total in OMR.
    ///
    /// Customs logic used in this workflow:
    /// - CIF: entered directly; no insurance is added.
    /// - CFR: CIF = CFR + 1% insurance.
    /// - FOB / EXW: CIF = Cost + Freight + 1% insurance on Cost + Freight.
    /// - Duty = CIF × duty rate.
    /// - VAT base = CIF + Duty.
    /// - VAT = VAT base × VAT rate.
    /// - Documentation Guarantee = 2% × CIF only when documents are not original and CIF > 1,000 OMR.
    /// - Bayan Documentation = 15 OMR for Company, 5 OMR for Personal.
    /// - Total Payable = Duty + VAT + Documentation Guarantee + Bayan Documentation.
    public static func calculate(
        deliveryTerm: DeliveryTerm,
        cifValue: Decimal? = nil,
        cifCurrency: Currency = .omr,
        cifRateToOMR: Decimal? = nil,
        cfrValue: Decimal? = nil,
        cfrCurrency: Currency = .omr,
        cfrRateToOMR: Decimal? = nil,
        costValue: Decimal? = nil,
        costCurrency: Currency = .omr,
        costRateToOMR: Decimal? = nil,
        freightValue: Decimal? = nil,
        freightCurrency: Currency = .omr,
        freightRateToOMR: Decimal? = nil,
        dutyRate: Decimal,
        vatRate: Decimal = Configuration.standardVATRate,
        importerType: ImporterType = .company,
        documentStatus: DocumentStatus = .original,
        hsCode: String? = nil,
        isEstimate: Bool = false
    ) -> DutyCalculationResult? {
        guard dutyRate >= .zero, vatRate >= .zero else { return nil }

        var costOMR: Decimal = .zero
        var freightOMR: Decimal = .zero
        let insuranceOMR: Decimal
        let cifOMRRaw: Decimal

        switch deliveryTerm {
        case .cif:
            guard let directCIF = convertToOMR(
                amount: cifValue,
                currency: cifCurrency,
                omrPerCurrencyUnit: cifRateToOMR
            ) else { return nil }
            cifOMRRaw = directCIF
            insuranceOMR = .zero

        case .cfr:
            guard let cfrOMR = convertToOMR(
                amount: cfrValue,
                currency: cfrCurrency,
                omrPerCurrencyUnit: cfrRateToOMR
            ) else { return nil }
            insuranceOMR = DecimalMath.multiply(cfrOMR, by: Configuration.insuranceRate)
            cifOMRRaw = DecimalMath.add(cfrOMR, and: insuranceOMR)

        case .fob, .exw:
            guard let convertedCost = convertToOMR(
                amount: costValue,
                currency: costCurrency,
                omrPerCurrencyUnit: costRateToOMR
            ), let convertedFreight = convertToOMR(
                amount: freightValue,
                currency: freightCurrency,
                omrPerCurrencyUnit: freightRateToOMR
            ) else { return nil }

            costOMR = convertedCost
            freightOMR = convertedFreight
            let costAndFreightOMR = DecimalMath.add(convertedCost, and: convertedFreight)
            insuranceOMR = DecimalMath.multiply(costAndFreightOMR, by: Configuration.insuranceRate)
            cifOMRRaw = DecimalMath.add(costAndFreightOMR, and: insuranceOMR)
        }

        let duty = DecimalMath.multiply(cifOMRRaw, by: dutyRate)
        let vatBase = DecimalMath.add(cifOMRRaw, and: duty)
        let vat = DecimalMath.multiply(vatBase, by: vatRate)
        let totalTaxes = DecimalMath.add(duty, and: vat)

        let guarantee: Decimal
        if documentStatus == .notOriginal,
           cifOMRRaw > Configuration.documentationGuaranteeThresholdOMR {
            guarantee = DecimalMath.multiply(cifOMRRaw, by: Configuration.documentationGuaranteeRate)
        } else {
            guarantee = .zero
        }

        let bayanDocumentation = importerType.bayanDocumentationFeeOMR
        let totalPayable = DecimalMath.add(
            DecimalMath.add(totalTaxes, and: guarantee),
            and: bayanDocumentation
        )

        return DutyCalculationResult(
            deliveryTerm: deliveryTerm,
            importerType: importerType,
            documentStatus: documentStatus,
            costOMR: DecimalMath.round(costOMR, scale: 3),
            freightOMR: DecimalMath.round(freightOMR, scale: 3),
            insuranceOMR: DecimalMath.round(insuranceOMR, scale: 3),
            cifOMR: DecimalMath.round(cifOMRRaw, scale: 3),
            dutyRate: dutyRate,
            dutyOMR: DecimalMath.round(duty, scale: 3),
            vatRate: vatRate,
            vatBaseOMR: DecimalMath.round(vatBase, scale: 3),
            vatOMR: DecimalMath.round(vat, scale: 3),
            totalTaxesOMR: DecimalMath.round(totalTaxes, scale: 3),
            documentationGuaranteeOMR: DecimalMath.round(guarantee, scale: 3),
            bayanDocumentationOMR: DecimalMath.round(bayanDocumentation, scale: 3),
            totalPayableOMR: DecimalMath.round(totalPayable, scale: 3),
            hsCode: hsCode,
            isEstimate: isEstimate
        )
    }
}
