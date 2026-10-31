import Foundation

public enum DeliveryTerm: String, CaseIterable, Identifiable, Codable {
    case cif = "CIF"
    case cfr = "CFR"
    case fob = "FOB"
    case exw = "EXW"

    public var id: String { rawValue }
}

public enum DutyLookupMode: String, CaseIterable, Identifiable, Codable {
    case hsCode = "hs_code"
    case description = "description"
    case quickEstimate = "quick_estimate"

    public var id: String { rawValue }
}

public enum ImporterType: String, CaseIterable, Identifiable, Codable {
    case company = "company"
    case personal = "personal"

    public var id: String { rawValue }

    public var bayanDocumentationFeeOMR: Decimal {
        switch self {
        case .company: return Decimal(15)
        case .personal: return Decimal(5)
        }
    }
}

public enum DocumentStatus: String, CaseIterable, Identifiable, Codable {
    case original = "original"
    case notOriginal = "not_original"

    public var id: String { rawValue }
}

public struct DutyCalculationResult: Equatable {
    public let deliveryTerm: DeliveryTerm
    public let importerType: ImporterType
    public let documentStatus: DocumentStatus

    /// Cost/invoice and freight after conversion to OMR. For direct CIF/CFR flows,
    /// only the applicable source field is populated and the other can be zero.
    public let costOMR: Decimal
    public let freightOMR: Decimal
    public let insuranceOMR: Decimal
    public let cifOMR: Decimal

    public let dutyRate: Decimal
    public let dutyOMR: Decimal
    public let vatRate: Decimal
    public let vatBaseOMR: Decimal
    public let vatOMR: Decimal
    public let totalTaxesOMR: Decimal

    /// 2% of CIF only when documents are not original AND CIF > 1,000 OMR.
    public let documentationGuaranteeOMR: Decimal

    /// Fixed Bayan documentation fee: Company = 15 OMR, Personal = 5 OMR.
    public let bayanDocumentationOMR: Decimal

    /// Total amount the operator needs to communicate:
    /// Duty + VAT + Documentation Guarantee (when applicable) + Bayan Documentation.
    public let totalPayableOMR: Decimal

    public let hsCode: String?
    public let isEstimate: Bool

    public var documentationGuaranteeApplied: Bool {
        documentationGuaranteeOMR > .zero
    }

    public init(
        deliveryTerm: DeliveryTerm,
        importerType: ImporterType,
        documentStatus: DocumentStatus,
        costOMR: Decimal,
        freightOMR: Decimal,
        insuranceOMR: Decimal,
        cifOMR: Decimal,
        dutyRate: Decimal,
        dutyOMR: Decimal,
        vatRate: Decimal,
        vatBaseOMR: Decimal,
        vatOMR: Decimal,
        totalTaxesOMR: Decimal,
        documentationGuaranteeOMR: Decimal,
        bayanDocumentationOMR: Decimal,
        totalPayableOMR: Decimal,
        hsCode: String?,
        isEstimate: Bool
    ) {
        self.deliveryTerm = deliveryTerm
        self.importerType = importerType
        self.documentStatus = documentStatus
        self.costOMR = costOMR
        self.freightOMR = freightOMR
        self.insuranceOMR = insuranceOMR
        self.cifOMR = cifOMR
        self.dutyRate = dutyRate
        self.dutyOMR = dutyOMR
        self.vatRate = vatRate
        self.vatBaseOMR = vatBaseOMR
        self.vatOMR = vatOMR
        self.totalTaxesOMR = totalTaxesOMR
        self.documentationGuaranteeOMR = documentationGuaranteeOMR
        self.bayanDocumentationOMR = bayanDocumentationOMR
        self.totalPayableOMR = totalPayableOMR
        self.hsCode = hsCode
        self.isEstimate = isEstimate
    }
}
