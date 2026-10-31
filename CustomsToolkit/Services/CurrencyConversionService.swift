import Foundation

/// Domain service handling customs declaration currency conversions.
/// 
/// MARK: - PENDING_VERIFICATION Notice:
/// The exact multiplication/division exchange rate convention used by Oman customs declarations
/// will be verified with real company declaration examples before production deployment.
/// This service isolates and provides both conventions explicitly.
public enum CurrencyConversionService {
    
    /// Converts an OMR base amount into the target currency using the specified exchange rate and convention.
    ///
    /// - Parameters:
    ///   - omrAmount: The net adjusted base amount in OMR.
    ///   - exchangeRate: The user-entered exchange rate. Must be positive and non-zero.
    ///   - convention: The mathematical convention (.multiply: OMR * Rate, .divide: OMR / Rate).
    /// - Returns: The calculated declaration amount, or nil if invalid rate.
    public static func convert(
        omrAmount: Decimal,
        exchangeRate: Decimal,
        convention: ExchangeRateConvention
    ) -> Decimal? {
        guard exchangeRate > .zero else { return nil }
        
        switch convention {
        case .multiply:
            // Target Currency Value = OMR Amount × Exchange Rate
            return DecimalMath.multiply(omrAmount, by: exchangeRate)
            
        case .divide:
            // Target Currency Value = OMR Amount ÷ Exchange Rate
            return DecimalMath.divide(omrAmount, by: exchangeRate)
        }
    }
    
    /// Converts textual input to Decimal exchange rate with validation.
    public static func parseExchangeRate(_ text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let decimal = Decimal(string: trimmed), decimal > .zero else {
            return nil
        }
        return decimal
    }
}
