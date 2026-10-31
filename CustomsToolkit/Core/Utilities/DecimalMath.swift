import Foundation

/// Safe Decimal mathematical operations for financial calculations.
/// Ensures no binary floating point inaccuracy occurs in customs & tax workflows.
public enum DecimalMath {
    
    /// Divides two Decimals with specified scale and rounding mode.
    public static func divide(
        _ numerator: Decimal,
        by denominator: Decimal,
        scale: Int = 10,
        roundingMode: NSDecimalNumber.RoundingMode = .plain
    ) -> Decimal? {
        guard denominator != .zero else { return nil }
        
        var result = Decimal()
        var num = numerator
        var den = denominator
        let error = NSDecimalDivide(&result, &num, &den, roundingMode)
        
        guard error == .noError else { return nil }
        return result
    }
    
    /// Multiplies two Decimals.
    public static func multiply(
        _ a: Decimal,
        by b: Decimal,
        roundingMode: NSDecimalNumber.RoundingMode = .plain
    ) -> Decimal {
        var result = Decimal()
        var valA = a
        var valB = b
        NSDecimalMultiply(&result, &valA, &valB, roundingMode)
        return result
    }
    
    /// Subtracts `b` from `a`.
    public static func subtract(
        _ a: Decimal,
        minus b: Decimal,
        roundingMode: NSDecimalNumber.RoundingMode = .plain
    ) -> Decimal {
        var result = Decimal()
        var valA = a
        var valB = b
        NSDecimalSubtract(&result, &valA, &valB, roundingMode)
        return result
    }
    
    /// Adds `a` and `b`.
    public static func add(
        _ a: Decimal,
        and b: Decimal,
        roundingMode: NSDecimalNumber.RoundingMode = .plain
    ) -> Decimal {
        var result = Decimal()
        var valA = a
        var valB = b
        NSDecimalAdd(&result, &valA, &valB, roundingMode)
        return result
    }
    
    /// Rounds a Decimal to the specified decimal places.
    public static func round(
        _ value: Decimal,
        scale: Int,
        roundingMode: NSDecimalNumber.RoundingMode = .plain
    ) -> Decimal {
        var result = Decimal()
        var val = value
        NSDecimalRound(&result, &val, scale, roundingMode)
        return result
    }
}
