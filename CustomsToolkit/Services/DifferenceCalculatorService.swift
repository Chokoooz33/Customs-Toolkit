import Foundation

/// Core calculation engine for the Duty & VAT Difference customs workflow.
/// Implements Decimal-safe financial arithmetic to avoid floating-point inaccuracies.
public enum DifferenceCalculatorService {
    
    // MARK: - Centralized Business Configuration
    public struct Configuration {
        /// Standard VAT rate in Oman (5% = 0.05).
        public static var vatRate: Decimal = AppConfig.Calculator.defaultVatRate
        
        /// Fixed adjustment for the "Duty + VAT" condition, verified from the company Excel workbook.
        public static var dutyAndVatAdjustment: Decimal = AppConfig.Calculator.dutyAndVatAdjustment
        
        /// Fixed adjustment for the "VAT Only" condition, supplied as the confirmed business rule.
        public static var vatOnlyAdjustment: Decimal = AppConfig.Calculator.vatOnlyAdjustment
    }
    
    // MARK: - Calculation Methods
    
    /// Calculates the full customs difference workflow result.
    ///
    /// - Parameters:
    ///   - mode: Workflow mode (.taxDifference or .originalAmount).
    ///   - enteredAmount: Input amount entered by the customs professional.
    ///   - condition: Selected condition (.dutyAndVat or .vatOnly).
    ///   - targetCurrency: Selected declaration currency.
    ///   - exchangeRate: User-entered customs exchange rate (defaults to 1.0 if OMR).
    ///   - rateConvention: Mathematical convention for currency conversion.
    /// - Returns: Complete `DifferenceCalculationResult` or nil if inputs are invalid.
    public static func calculate(
        mode: DifferenceCalculatorMode,
        enteredAmount: Decimal,
        condition: CustomsCondition,
        targetCurrency: Currency,
        exchangeRate: Decimal?,
        rateConvention: ExchangeRateConvention = .multiply
    ) -> DifferenceCalculationResult? {
        guard enteredAmount >= .zero else { return nil }
        
        // 1. Determine Original 5% Base Amount
        let calculatedOriginalAmount: Decimal
        switch mode {
        case .taxDifference:
            // Formula: Original Amount = Entered Amount ÷ 0.05
            guard let original = DecimalMath.divide(enteredAmount, by: Configuration.vatRate) else {
                return nil
            }
            calculatedOriginalAmount = original
            
        case .originalAmount:
            calculatedOriginalAmount = enteredAmount
        }
        
        // 2. Determine Adjustment Amount based on Condition
        let adjustment: Decimal
        switch condition {
        case .dutyAndVat:
            adjustment = Configuration.dutyAndVatAdjustment
        case .vatOnly:
            adjustment = Configuration.vatOnlyAdjustment
        }
        
        // 3. Calculate Adjusted OMR Amount (Original Amount - Adjustment)
        let adjustedOMRAmount = DecimalMath.subtract(calculatedOriginalAmount, minus: adjustment)
        
        // 4. Currency Conversion
        let finalRate = (targetCurrency == .omr) ? Decimal(1) : (exchangeRate ?? Decimal(1))
        guard finalRate > .zero else { return nil }
        
        let finalDeclarationValue: Decimal
        if targetCurrency == .omr {
            finalDeclarationValue = adjustedOMRAmount
        } else {
            guard let converted = CurrencyConversionService.convert(
                omrAmount: adjustedOMRAmount,
                exchangeRate: finalRate,
                convention: rateConvention
            ) else {
                return nil
            }
            finalDeclarationValue = converted
        }
        
        return DifferenceCalculationResult(
            mode: mode,
            enteredAmount: enteredAmount,
            calculatedOriginalAmount: calculatedOriginalAmount,
            condition: condition,
            adjustmentAmount: adjustment,
            adjustedOMRAmount: adjustedOMRAmount,
            targetCurrencyCode: targetCurrency.code,
            exchangeRate: finalRate,
            rateConvention: rateConvention,
            finalDeclarationValue: finalDeclarationValue
        )
    }
}
