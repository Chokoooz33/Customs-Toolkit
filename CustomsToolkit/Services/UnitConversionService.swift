import Foundation

/// Domain service responsible for precision unit conversions in customs declarations.
public enum UnitConversionService {

    private static let gramsPerCarat = Decimal(string: "0.2")!
    private static let caratsPerGram = Decimal(string: "5.0")!
    private static let gramsPerKilogram = Decimal(string: "1000")!
    private static let squareMetersPerSquareFoot = Decimal(string: "0.09290304")!
    private static let squareFeetPerSquareMeter = Decimal(string: "10.7639104167097")!
    private static let kilogramsPerPound = Decimal(string: "0.45359237")!
    private static let poundsPerKilogram = Decimal(string: "2.20462262184878")!
    private static let millilitersPerLiter = Decimal(string: "1000")!

    /// Converts a value using an exact conversion direction.
    /// `densityGramsPerMilliliter` is required only for Gram ↔ Liter because mass-to-volume
    /// conversion depends on the material density.
    public static func convert(
        value: Decimal,
        direction: UnitConversionDirection,
        densityGramsPerMilliliter: Decimal? = nil
    ) -> Decimal? {
        guard value >= .zero else { return nil }

        switch direction {
        case .caratToGram:
            return DecimalMath.multiply(value, by: gramsPerCarat)
        case .gramToCarat:
            return DecimalMath.multiply(value, by: caratsPerGram)
        case .gramToKilogram:
            return DecimalMath.divide(value, by: gramsPerKilogram)
        case .kilogramToGram:
            return DecimalMath.multiply(value, by: gramsPerKilogram)
        case .squareFootToSquareMeter:
            return DecimalMath.multiply(value, by: squareMetersPerSquareFoot)
        case .squareMeterToSquareFoot:
            return DecimalMath.multiply(value, by: squareFeetPerSquareMeter)
        case .poundToKilogram:
            return DecimalMath.multiply(value, by: kilogramsPerPound)
        case .kilogramToPound:
            return DecimalMath.multiply(value, by: poundsPerKilogram)
        case .gramToLiter:
            guard let density = densityGramsPerMilliliter, density > .zero else { return nil }
            let gramsPerLiter = DecimalMath.multiply(density, by: millilitersPerLiter)
            return DecimalMath.divide(value, by: gramsPerLiter)
        case .literToGram:
            guard let density = densityGramsPerMilliliter, density > .zero else { return nil }
            let gramsPerLiter = DecimalMath.multiply(density, by: millilitersPerLiter)
            return DecimalMath.multiply(value, by: gramsPerLiter)
        }
    }

    public static func parseDecimal(_ text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed
            .replacingOccurrences(of: "٬", with: "")
            .replacingOccurrences(of: "٫", with: ".")
            .replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalized)
    }

    /// String-based conversion convenience with validation.
    public static func convert(
        textInput: String,
        direction: UnitConversionDirection,
        densityInput: String = ""
    ) -> (result: Decimal?, formattedResult: String, isValid: Bool, isDensityValid: Bool) {
        let trimmed = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return (nil, "", true, true)
        }

        guard let decimalValue = parseDecimal(trimmed), decimalValue >= .zero else {
            return (nil, "", false, true)
        }

        var density: Decimal?
        var densityValid = true
        if direction.requiresDensity {
            density = parseDecimal(densityInput)
            densityValid = density.map { $0 > .zero } ?? false
            guard densityValid else {
                return (nil, "", true, false)
            }
        }

        guard let result = convert(
            value: decimalValue,
            direction: direction,
            densityGramsPerMilliliter: density
        ) else {
            return (nil, "", false, densityValid)
        }

        let formatted = result.formattedUnit(unit: direction.targetUnit, maxFractionDigits: 6)
        return (result, formatted, true, densityValid)
    }
}
