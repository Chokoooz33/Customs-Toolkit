import Foundation

public extension Decimal {
    
    /// Formats decimal as standard OMR currency (3 decimal places, e.g. "6,000.000 OMR").
    /// Includes Unicode Left-To-Right mark (\u{200E}) to guarantee technical number order in Arabic RTL.
    func formattedOMR(includeSymbol: Bool = true) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 3
        formatter.maximumFractionDigits = 3
        formatter.groupingSeparator = ","
        formatter.decimalSeparator = "."
        
        let formattedNumber = formatter.string(from: self as NSDecimalNumber) ?? "\(self)"
        
        if includeSymbol {
            // \u{200E} ensures LTR embedding for technical values in RTL context
            return "\u{200E}\(formattedNumber) OMR"
        } else {
            return "\u{200E}\(formattedNumber)"
        }
    }
    
    /// Formats decimal for general currency with specified code and fraction digits.
    func formattedCurrency(code: String, fractionDigits: Int = 3) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        formatter.groupingSeparator = ","
        formatter.decimalSeparator = "."
        
        let formattedNumber = formatter.string(from: self as NSDecimalNumber) ?? "\(self)"
        return "\u{200E}\(formattedNumber) \(code)"
    }
    
    /// Formats decimal with unit (e.g. Carats or Grams), trimming trailing zeroes cleanly.
    func formattedUnit(unit: String, maxFractionDigits: Int = 4) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maxFractionDigits
        formatter.groupingSeparator = ","
        formatter.decimalSeparator = "."
        
        let formattedNumber = formatter.string(from: self as NSDecimalNumber) ?? "\(self)"
        return "\u{200E}\(formattedNumber) \(unit)"
    }
    
    /// Clean decimal string without unit for copy/paste or text fields.
    func plainDecimalString(fractionDigits: Int = 3) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        formatter.usesGroupingSeparator = false
        formatter.decimalSeparator = "."
        return formatter.string(from: self as NSDecimalNumber) ?? "\(self)"
    }
}
