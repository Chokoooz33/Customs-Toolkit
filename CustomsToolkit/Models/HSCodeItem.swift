import Foundation

/// Official customs status of a tariff item.
public enum TariffStatus: String, Codable, CaseIterable, Identifiable {
    case normal = "normal"
    case restricted = "restricted"
    case prohibited = "prohibited"
    case unknown = "unknown"
    
    public var id: String { rawValue }
}

/// Metadata describing the installed Oman customs tariff dataset.
public struct TariffDatasetMetadata: Codable, Equatable {
    public let country: String
    public let year: Int
    public let source: String
    public let recordCount: Int
    public let importedAt: Date?
    public let datasetVersion: String
    
    public init(
        country: String = AppConfig.tariffCountry,
        year: Int = AppConfig.tariffYear,
        source: String = AppConfig.omanCustomsTariffSource,
        recordCount: Int = 0,
        importedAt: Date? = Date(),
        datasetVersion: String = "2026.1"
    ) {
        self.country = country
        self.year = year
        self.source = source
        self.recordCount = recordCount
        self.importedAt = importedAt
        self.datasetVersion = datasetVersion
    }
}

/// Represents a standardized HS Code entry in the Oman Customs tariff dataset.
/// Fully supports international prefixes and long Oman local tariff codes (e.g. 12 digits: `010121100001`).
public struct HSCodeItem: Identifiable, Codable, Hashable {
    public let id: String
    
    /// Raw or display code as present in the source (e.g. "0101 21 10 00 01").
    public let code: String
    
    /// Normalized digit-only code for indexing and fast lookup (e.g. "010121100001").
    public let normalizedCode: String
    
    public let descriptionArabic: String?
    public let descriptionEnglish: String?
    
    public let heading: String?
    public let dutyRate: String?
    public let procedure: String?
    
    // Trade agreement indicators
    public let indIndicator: String?
    public let eftaIndicator: String?
    public let sgIndicator: String?
    public let usaIndicator: String?
    
    public let status: TariffStatus
    public let chapter: String?

    // Official classification hierarchy context extracted from the Oman Customs Tariff 2026.
    // These fields are source-derived only; nil means the source hierarchy level was not safely resolved.
    public let chapterDescriptionArabic: String?
    public let chapterDescriptionEnglish: String?
    public let headingDescriptionArabic: String?
    public let headingDescriptionEnglish: String?
    public let subheadingDescriptionArabic: String?
    public let subheadingDescriptionEnglish: String?

    public let sourcePage: Int?
    public let datasetYear: Int
    
    public init(
        id: String = UUID().uuidString,
        code: String,
        normalizedCode: String? = nil,
        descriptionArabic: String? = nil,
        descriptionEnglish: String? = nil,
        heading: String? = nil,
        dutyRate: String? = nil,
        procedure: String? = nil,
        indIndicator: String? = nil,
        eftaIndicator: String? = nil,
        sgIndicator: String? = nil,
        usaIndicator: String? = nil,
        status: TariffStatus = .unknown,
        chapter: String? = nil,
        chapterDescriptionArabic: String? = nil,
        chapterDescriptionEnglish: String? = nil,
        headingDescriptionArabic: String? = nil,
        headingDescriptionEnglish: String? = nil,
        subheadingDescriptionArabic: String? = nil,
        subheadingDescriptionEnglish: String? = nil,
        sourcePage: Int? = nil,
        datasetYear: Int = AppConfig.tariffYear
    ) {
        self.id = id
        self.code = code
        self.normalizedCode = normalizedCode ?? HSNormalizer.normalize(code)
        self.descriptionArabic = descriptionArabic
        self.descriptionEnglish = descriptionEnglish
        self.heading = heading
        self.dutyRate = dutyRate
        self.procedure = procedure
        self.indIndicator = indIndicator
        self.eftaIndicator = eftaIndicator
        self.sgIndicator = sgIndicator
        self.usaIndicator = usaIndicator
        self.status = status
        self.chapter = chapter
        self.chapterDescriptionArabic = chapterDescriptionArabic
        self.chapterDescriptionEnglish = chapterDescriptionEnglish
        self.headingDescriptionArabic = headingDescriptionArabic
        self.headingDescriptionEnglish = headingDescriptionEnglish
        self.subheadingDescriptionArabic = subheadingDescriptionArabic
        self.subheadingDescriptionEnglish = subheadingDescriptionEnglish
        self.sourcePage = sourcePage
        self.datasetYear = datasetYear
    }
    
    // MARK: - Compatibility helpers
    public var formattedCode: String {
        return HSNormalizer.formatForDisplay(normalizedCode)
    }
    
    public var descriptionAr: String {
        return descriptionArabic ?? ""
    }
    
    public var descriptionEn: String {
        return descriptionEnglish ?? ""
    }
}
