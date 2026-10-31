import Foundation

/// Supported declaration currencies in Customs Toolkit.
public enum Currency: String, CaseIterable, Identifiable, Codable {
    case omr = "OMR"
    case usd = "USD"
    case aed = "AED"
    case eur = "EUR"
    case gbp = "GBP"
    
    public var id: String { rawValue }
    
    public var code: String { rawValue }
    
    public var nameEn: String {
        switch self {
        case .omr: return "Omani Rial"
        case .usd: return "US Dollar"
        case .aed: return "UAE Dirham"
        case .eur: return "Euro"
        case .gbp: return "British Pound"
        }
    }
    
    public var nameAr: String {
        switch self {
        case .omr: return "ريال عُماني"
        case .usd: return "دولار أمريكي"
        case .aed: return "درهم إماراتي"
        case .eur: return "يورو"
        case .gbp: return "جنيه إسترليني"
        }
    }
    
    public var fractionDigits: Int {
        switch self {
        case .omr: return 3
        default: return 2
        }
    }

    /// Safe convenience defaults used only to prefill the editable customs-rate field.
    /// USD and AED are pegged currencies in normal Oman operations; EUR/GBP remain manual
    /// because their customs rates can change. The operator can always edit the value.
    public var suggestedOMRPerUnitText: String? {
        switch self {
        case .omr: return "1"
        case .usd: return "0.385"
        case .aed: return "0.1048"
        case .eur, .gbp: return nil
        }
    }
}
