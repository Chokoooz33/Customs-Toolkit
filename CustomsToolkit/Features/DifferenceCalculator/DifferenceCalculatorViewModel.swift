import SwiftUI

@Observable
public final class DifferenceCalculatorViewModel {
    
    // Inputs
    public var mode: DifferenceCalculatorMode = .taxDifference {
        didSet { recalculate() }
    }
    
    public var inputAmountText: String = "" {
        didSet { recalculate() }
    }
    
    public var selectedCondition: CustomsCondition = .dutyAndVat {
        didSet { recalculate() }
    }
    
    public var targetCurrency: Currency = .omr {
        didSet { recalculate() }
    }
    
    public var exchangeRateText: String = "" {
        didSet { recalculate() }
    }
    
    public var rateConvention: ExchangeRateConvention = .multiply {
        didSet { recalculate() }
    }
    
    // Calculation State
    public var calculationResult: DifferenceCalculationResult?
    public var isInputAmountValid: Bool = true
    public var isExchangeRateValid: Bool = true
    
    public init() {}
    
    public func recalculate() {
        let trimmedAmount = inputAmountText.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        
        guard !trimmedAmount.isEmpty else {
            calculationResult = nil
            isInputAmountValid = true
            return
        }
        
        guard let enteredDecimal = Decimal(string: trimmedAmount), enteredDecimal >= .zero else {
            calculationResult = nil
            isInputAmountValid = false
            return
        }
        isInputAmountValid = true
        
        // Exchange Rate Validation if non-OMR
        var rateDecimal: Decimal? = nil
        if targetCurrency != .omr {
            let trimmedRate = exchangeRateText.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: ",", with: ".")
            if trimmedRate.isEmpty {
                calculationResult = nil
                isExchangeRateValid = true
                return
            }
            guard let parsedRate = Decimal(string: trimmedRate), parsedRate > .zero else {
                calculationResult = nil
                isExchangeRateValid = false
                return
            }
            isExchangeRateValid = true
            rateDecimal = parsedRate
        } else {
            isExchangeRateValid = true
        }
        
        self.calculationResult = DifferenceCalculatorService.calculate(
            mode: mode,
            enteredAmount: enteredDecimal,
            condition: selectedCondition,
            targetCurrency: targetCurrency,
            exchangeRate: rateDecimal,
            rateConvention: rateConvention
        )
    }
    
    public func reset() {
        HapticFeedback.impact(style: .light)
        inputAmountText = ""
        exchangeRateText = ""
        calculationResult = nil
        isInputAmountValid = true
        isExchangeRateValid = true
    }
    
    public func copyFinalResult() {
        guard let result = calculationResult else { return }
        let fractionDigits = targetCurrency == .omr ? 3 : 2
        let textToCopy = result.finalDeclarationValue.plainDecimalString(fractionDigits: fractionDigits)
        ClipboardService.copy(textToCopy)
        HapticFeedback.success()
    }
}
