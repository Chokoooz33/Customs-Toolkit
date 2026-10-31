import Foundation

/// Calculation workflow mode selected by the customs clearance professional.
public enum DifferenceCalculatorMode: String, CaseIterable, Identifiable, Codable {
    case taxDifference = "tax_difference"
    case originalAmount = "original_amount"
    
    public var id: String { rawValue }
}

/// Condition specifying the internal customs adjustment rule.
public enum CustomsCondition: String, CaseIterable, Identifiable, Codable {
    case dutyAndVat = "duty_and_vat"
    case vatOnly = "vat_only"
    
    public var id: String { rawValue }
}

/// Exchange rate mathematical convention.
/// MARK: - PENDING_VERIFICATION (Do not assume multiply/divide until company examples are verified).
public enum ExchangeRateConvention: String, CaseIterable, Identifiable, Codable {
    case multiply = "multiply" // Target = OMR × Rate
    case divide = "divide"     // Target = OMR ÷ Rate
    
    public var id: String { rawValue }
    
    public static let verificationStatus = "PENDING_VERIFICATION"
}

/// Structured result of a Duty & VAT difference calculation.
public struct DifferenceCalculationResult: Codable, Equatable {
    public let mode: DifferenceCalculatorMode
    public let enteredAmount: Decimal
    public let calculatedOriginalAmount: Decimal
    public let condition: CustomsCondition
    public let adjustmentAmount: Decimal
    public let adjustedOMRAmount: Decimal
    public let targetCurrencyCode: String
    public let exchangeRate: Decimal
    public let rateConvention: ExchangeRateConvention
    public let finalDeclarationValue: Decimal
    public let timestamp: Date
    
    public init(
        mode: DifferenceCalculatorMode,
        enteredAmount: Decimal,
        calculatedOriginalAmount: Decimal,
        condition: CustomsCondition,
        adjustmentAmount: Decimal,
        adjustedOMRAmount: Decimal,
        targetCurrencyCode: String,
        exchangeRate: Decimal,
        rateConvention: ExchangeRateConvention,
        finalDeclarationValue: Decimal,
        timestamp: Date = Date()
    ) {
        self.mode = mode
        self.enteredAmount = enteredAmount
        self.calculatedOriginalAmount = calculatedOriginalAmount
        self.condition = condition
        self.adjustmentAmount = adjustmentAmount
        self.adjustedOMRAmount = adjustedOMRAmount
        self.targetCurrencyCode = targetCurrencyCode
        self.exchangeRate = exchangeRate
        self.rateConvention = rateConvention
        self.finalDeclarationValue = finalDeclarationValue
        self.timestamp = timestamp
    }
}
