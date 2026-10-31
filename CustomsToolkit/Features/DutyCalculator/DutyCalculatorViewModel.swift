import SwiftUI

@MainActor
@Observable
public final class DutyCalculatorViewModel {
    public var deliveryTerm: DeliveryTerm = .cif { didSet { recalculate() } }
    public var importerType: ImporterType = .company { didSet { recalculate() } }
    public var documentStatus: DocumentStatus = .original { didSet { recalculate() } }

    public var lookupMode: DutyLookupMode = .hsCode {
        didSet {
            if lookupMode == .quickEstimate {
                selectedHSItem = nil
                hsQuery = ""
                suggestions = []
            }
            recalculate()
        }
    }

    // Direct CIF
    public var cifText: String = "" { didSet { recalculate() } }
    public var cifCurrency: Currency = .omr {
        didSet {
            if oldValue != cifCurrency { cifExchangeRateText = suggestedRateText(for: cifCurrency) }
            recalculate()
        }
    }
    public var cifExchangeRateText: String = "" { didSet { recalculate() } }

    // Direct CFR
    public var cfrText: String = "" { didSet { recalculate() } }
    public var cfrCurrency: Currency = .omr {
        didSet {
            if oldValue != cfrCurrency { cfrExchangeRateText = suggestedRateText(for: cfrCurrency) }
            recalculate()
        }
    }
    public var cfrExchangeRateText: String = "" { didSet { recalculate() } }

    // FOB / EXW values can use different currencies.
    public var costText: String = "" { didSet { recalculate() } }
    public var costCurrency: Currency = .omr {
        didSet {
            if oldValue != costCurrency { costExchangeRateText = suggestedRateText(for: costCurrency) }
            recalculate()
        }
    }
    public var costExchangeRateText: String = "" { didSet { recalculate() } }

    public var freightText: String = "" { didSet { recalculate() } }
    public var freightCurrency: Currency = .omr {
        didSet {
            if oldValue != freightCurrency { freightExchangeRateText = suggestedRateText(for: freightCurrency) }
            recalculate()
        }
    }
    public var freightExchangeRateText: String = "" { didSet { recalculate() } }

    public var hsQuery: String = "" {
        didSet {
            updateSuggestions()
            recalculate()
        }
    }
    public var selectedHSItem: HSCodeItem? { didSet { recalculate() } }
    public private(set) var suggestions: [HSCodeItem] = []
    public private(set) var result: DutyCalculationResult?

    private let searchService: HSSearchService

    public init(
        prefilledHSItem: HSCodeItem? = nil,
        searchService: HSSearchService = .shared
    ) {
        self.searchService = searchService
        if let prefilledHSItem {
            self.selectedHSItem = prefilledHSItem
            self.hsQuery = prefilledHSItem.normalizedCode
            self.lookupMode = .hsCode
        }
        updateSuggestions()
        recalculate()
    }

    public var parsedDutyRate: Decimal? {
        if lookupMode == .quickEstimate {
            return DutyCalculatorService.Configuration.quickEstimateDutyRate
        }
        return DutyCalculatorService.parsePercentage(selectedHSItem?.dutyRate)
    }

    public var dutyRateDisplay: String {
        let rate = parsedDutyRate ?? DutyCalculatorService.Configuration.quickEstimateDutyRate
        let value = DecimalMath.multiply(rate, by: Decimal(100))
        return "\(value.plainDecimalString(fractionDigits: value == DecimalMath.round(value, scale: 0) ? 0 : 2))%"
    }

    public var insurancePreviewOMR: Decimal? {
        switch deliveryTerm {
        case .cif:
            return nil
        case .cfr:
            guard let cfrOMR = DutyCalculatorService.convertToOMR(
                amount: parseDecimal(cfrText),
                currency: cfrCurrency,
                omrPerCurrencyUnit: exchangeRate(for: cfrCurrency, text: cfrExchangeRateText)
            ) else { return nil }
            return DecimalMath.round(
                DecimalMath.multiply(cfrOMR, by: DutyCalculatorService.Configuration.insuranceRate),
                scale: 3
            )
        case .fob, .exw:
            guard let costOMR = DutyCalculatorService.convertToOMR(
                amount: parseDecimal(costText),
                currency: costCurrency,
                omrPerCurrencyUnit: exchangeRate(for: costCurrency, text: costExchangeRateText)
            ), let freightOMR = DutyCalculatorService.convertToOMR(
                amount: parseDecimal(freightText),
                currency: freightCurrency,
                omrPerCurrencyUnit: exchangeRate(for: freightCurrency, text: freightExchangeRateText)
            ) else { return nil }

            return DecimalMath.round(
                DecimalMath.multiply(
                    DecimalMath.add(costOMR, and: freightOMR),
                    by: DutyCalculatorService.Configuration.insuranceRate
                ),
                scale: 3
            )
        }
    }

    public var bayanDocumentationPreviewOMR: Decimal {
        importerType.bayanDocumentationFeeOMR
    }

    public func selectHSItem(_ item: HSCodeItem) {
        HapticFeedback.selection()
        selectedHSItem = item
        hsQuery = item.normalizedCode
        suggestions = []
    }

    public func clearHSSelection() {
        selectedHSItem = nil
        hsQuery = ""
        suggestions = []
    }

    public func reset() {
        deliveryTerm = .cif
        importerType = .company
        documentStatus = .original
        lookupMode = .hsCode

        cifText = ""
        cifCurrency = .omr
        cifExchangeRateText = ""
        cfrText = ""
        cfrCurrency = .omr
        cfrExchangeRateText = ""
        costText = ""
        costCurrency = .omr
        costExchangeRateText = ""
        freightText = ""
        freightCurrency = .omr
        freightExchangeRateText = ""

        selectedHSItem = nil
        hsQuery = ""
        suggestions = []
        result = nil
    }

    private func updateSuggestions() {
        guard lookupMode != .quickEstimate else {
            suggestions = []
            return
        }
        let trimmed = hsQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            suggestions = []
            return
        }

        let matches = searchService.searchResultSet(query: trimmed, limit: 8).items
        suggestions = matches

        let normalized = HSNormalizer.normalize(trimmed)
        if !normalized.isEmpty,
           let exact = matches.first(where: { $0.normalizedCode == normalized }) {
            selectedHSItem = exact
        } else if selectedHSItem?.normalizedCode != normalized {
            selectedHSItem = nil
        }
    }

    private func recalculate() {
        let dutyRate: Decimal
        let isEstimate: Bool
        let hsCode: String?

        switch lookupMode {
        case .quickEstimate:
            dutyRate = DutyCalculatorService.Configuration.quickEstimateDutyRate
            isEstimate = true
            hsCode = nil
        case .hsCode, .description:
            guard let item = selectedHSItem,
                  let parsed = DutyCalculatorService.parsePercentage(item.dutyRate) else {
                result = nil
                return
            }
            dutyRate = parsed
            isEstimate = false
            hsCode = item.normalizedCode
        }

        result = DutyCalculatorService.calculate(
            deliveryTerm: deliveryTerm,
            cifValue: parseDecimal(cifText),
            cifCurrency: cifCurrency,
            cifRateToOMR: exchangeRate(for: cifCurrency, text: cifExchangeRateText),
            cfrValue: parseDecimal(cfrText),
            cfrCurrency: cfrCurrency,
            cfrRateToOMR: exchangeRate(for: cfrCurrency, text: cfrExchangeRateText),
            costValue: parseDecimal(costText),
            costCurrency: costCurrency,
            costRateToOMR: exchangeRate(for: costCurrency, text: costExchangeRateText),
            freightValue: parseDecimal(freightText),
            freightCurrency: freightCurrency,
            freightRateToOMR: exchangeRate(for: freightCurrency, text: freightExchangeRateText),
            dutyRate: dutyRate,
            importerType: importerType,
            documentStatus: documentStatus,
            hsCode: hsCode,
            isEstimate: isEstimate
        )
    }

    private func exchangeRate(for currency: Currency, text: String) -> Decimal? {
        if currency == .omr { return Decimal(1) }
        guard let value = parseDecimal(text), value > .zero else { return nil }
        return value
    }

    private func suggestedRateText(for currency: Currency) -> String {
        currency == .omr ? "" : (currency.suggestedOMRPerUnitText ?? "")
    }

    private func parseDecimal(_ text: String) -> Decimal? {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Accept Arabic/Persian number-pad digits and separators as well as Latin digits.
        let replacements: [(String, String)] = [
            ("٠", "0"), ("١", "1"), ("٢", "2"), ("٣", "3"), ("٤", "4"),
            ("٥", "5"), ("٦", "6"), ("٧", "7"), ("٨", "8"), ("٩", "9"),
            ("۰", "0"), ("۱", "1"), ("۲", "2"), ("۳", "3"), ("۴", "4"),
            ("۵", "5"), ("۶", "6"), ("۷", "7"), ("۸", "8"), ("۹", "9"),
            ("٫", "."), ("٬", "")
        ]
        for (source, target) in replacements {
            cleaned = cleaned.replacingOccurrences(of: source, with: target)
        }

        // A single comma is accepted as a decimal separator. If a dot is already present,
        // commas are treated as grouping separators instead.
        if cleaned.contains(".") {
            cleaned = cleaned.replacingOccurrences(of: ",", with: "")
        } else {
            cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
        }

        guard !cleaned.isEmpty, let value = Decimal(string: cleaned), value >= .zero else { return nil }
        return value
    }
}
