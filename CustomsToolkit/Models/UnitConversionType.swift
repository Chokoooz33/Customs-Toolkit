import Foundation

/// Logical conversion families presented to the user.
public enum UnitConversionPair: String, CaseIterable, Identifiable {
    case caratGram = "carat_gram"
    case gramKilogram = "gram_kilogram"
    case squareFootSquareMeter = "square_foot_square_meter"
    case poundKilogram = "pound_kilogram"
    case gramLiter = "gram_liter"

    public var id: String { rawValue }

    public var defaultDirection: UnitConversionDirection {
        switch self {
        case .caratGram: return .caratToGram
        case .gramKilogram: return .gramToKilogram
        case .squareFootSquareMeter: return .squareFootToSquareMeter
        case .poundKilogram: return .poundToKilogram
        case .gramLiter: return .gramToLiter
        }
    }
}

/// Conversion direction for the unit conversion tool.
public enum UnitConversionDirection: String, CaseIterable, Identifiable {
    case caratToGram = "carat_to_gram"
    case gramToCarat = "gram_to_carat"
    case gramToKilogram = "gram_to_kilogram"
    case kilogramToGram = "kilogram_to_gram"
    case squareFootToSquareMeter = "square_foot_to_square_meter"
    case squareMeterToSquareFoot = "square_meter_to_square_foot"
    case poundToKilogram = "pound_to_kilogram"
    case kilogramToPound = "kilogram_to_pound"
    case gramToLiter = "gram_to_liter"
    case literToGram = "liter_to_gram"

    public var id: String { rawValue }

    public var pair: UnitConversionPair {
        switch self {
        case .caratToGram, .gramToCarat: return .caratGram
        case .gramToKilogram, .kilogramToGram: return .gramKilogram
        case .squareFootToSquareMeter, .squareMeterToSquareFoot: return .squareFootSquareMeter
        case .poundToKilogram, .kilogramToPound: return .poundKilogram
        case .gramToLiter, .literToGram: return .gramLiter
        }
    }

    public var swapped: UnitConversionDirection {
        switch self {
        case .caratToGram: return .gramToCarat
        case .gramToCarat: return .caratToGram
        case .gramToKilogram: return .kilogramToGram
        case .kilogramToGram: return .gramToKilogram
        case .squareFootToSquareMeter: return .squareMeterToSquareFoot
        case .squareMeterToSquareFoot: return .squareFootToSquareMeter
        case .poundToKilogram: return .kilogramToPound
        case .kilogramToPound: return .poundToKilogram
        case .gramToLiter: return .literToGram
        case .literToGram: return .gramToLiter
        }
    }

    public var sourceUnit: String {
        switch self {
        case .caratToGram: return "ct"
        case .gramToCarat, .gramToKilogram, .gramToLiter: return "g"
        case .kilogramToGram, .kilogramToPound: return "kg"
        case .squareFootToSquareMeter: return "ft²"
        case .squareMeterToSquareFoot: return "m²"
        case .poundToKilogram: return "lb"
        case .literToGram: return "L"
        }
    }

    public var targetUnit: String {
        swapped.sourceUnit
    }

    public var requiresDensity: Bool {
        pair == .gramLiter
    }
}
