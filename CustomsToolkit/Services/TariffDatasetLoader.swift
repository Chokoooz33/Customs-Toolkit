import Foundation

/// Container structure for the raw bundled tariff dataset file format.
public struct BundledTariffDataset: Codable {
    public let metadata: TariffDatasetMetadata
    public let records: [HSCodeItem]
    
    public init(metadata: TariffDatasetMetadata, records: [HSCodeItem]) {
        self.metadata = metadata
        self.records = records
    }
}

public enum TariffLoaderError: Error, LocalizedError, Equatable {
    case resourceNotFound(resourceName: String)
    case invalidData
    case decodingFailed(reason: String)
    case invalidMetadata(reason: String)
    case validationFailed(reason: String)
    
    public var errorDescription: String? {
        switch self {
        case .resourceNotFound(let name):
            return "Tariff resource file '\(name).json' was not found in the application bundle."
        case .invalidData:
            return "The tariff dataset data could not be read."
        case .decodingFailed(let reason):
            return "Failed to decode tariff dataset JSON: \(reason)"
        case .invalidMetadata(let reason):
            return "Invalid tariff metadata: \(reason)"
        case .validationFailed(let reason):
            return "Tariff dataset validation failed: \(reason)"
        }
    }
}

/// Service dedicated to locating, decoding, and validating structured Oman Customs tariff datasets.
public final class TariffDatasetLoader {
    
    public static let shared = TariffDatasetLoader()
    
    public init() {}
    
    /// Attempts to load the bundled production tariff dataset.
    public func loadBundledDataset(
        resourceName: String = AppConfig.tariffDatasetResourceName,
        bundle: Bundle = .main
    ) -> Result<(metadata: TariffDatasetMetadata, items: [HSCodeItem], report: TariffValidationReport), TariffLoaderError> {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            return .failure(.resourceNotFound(resourceName: resourceName))
        }
        
        do {
            let data = try Data(contentsOf: url)
            return decodeAndValidate(jsonData: data)
        } catch {
            return .failure(.decodingFailed(reason: error.localizedDescription))
        }
    }
    
    /// Decodes and validates raw JSON data representing a structured tariff dataset.
    public func decodeAndValidate(
        jsonData: Data
    ) -> Result<(metadata: TariffDatasetMetadata, items: [HSCodeItem], report: TariffValidationReport), TariffLoaderError> {
        let decoder = JSONDecoder()
        
        let bundled: BundledTariffDataset
        do {
            bundled = try decoder.decode(BundledTariffDataset.self, from: jsonData)
        } catch {
            return .failure(.decodingFailed(reason: error.localizedDescription))
        }
        
        guard bundled.metadata.recordCount == bundled.records.count else {
            return .failure(.invalidMetadata(
                reason: "Metadata recordCount (\(bundled.metadata.recordCount)) does not match decoded records (\(bundled.records.count))"
            ))
        }

        let report = validateDataset(bundled.records, expectedYear: bundled.metadata.year)
        
        guard report.isValid else {
            return .failure(.validationFailed(reason: "Dataset contains invalid records"))
        }
        
        return .success((bundled.metadata, bundled.records, report))
    }
    
    /// Validates tariff records and generates a comprehensive validation report.
    public func validateDataset(_ items: [HSCodeItem], expectedYear: Int = AppConfig.tariffYear) -> TariffValidationReport {
        var validCount = 0
        var invalidCount = 0
        var seenCodes = Set<String>()
        var duplicateCodes = Set<String>()
        var missingArCount = 0
        var missingEnCount = 0
        var missingDutyCount = 0
        var prohibitedCount = 0
        var restrictedCount = 0
        var unknownStatusCount = 0
        var pageRefCount = 0
        
        for item in items {
            let normalized = item.normalizedCode
            
            // 1. Validate Code
            if normalized.isEmpty || !HSNormalizer.isValidQuery(normalized) {
                invalidCount += 1
                continue
            }
            
            // 2. Duplicate Detection
            if seenCodes.contains(normalized) {
                duplicateCodes.insert(normalized)
            } else {
                seenCodes.insert(normalized)
            }
            
            // 3. Descriptions check
            if item.descriptionArabic?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                missingArCount += 1
            }
            if item.descriptionEnglish?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                missingEnCount += 1
            }
            
            // 4. Duty value check
            if item.dutyRate?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                missingDutyCount += 1
            }
            
            // 5. Status check
            switch item.status {
            case .prohibited:
                prohibitedCount += 1
            case .restricted:
                restrictedCount += 1
            case .unknown:
                unknownStatusCount += 1
            case .normal:
                break
            }
            
            // 6. Page reference
            if item.sourcePage != nil {
                pageRefCount += 1
            }
            
            // 7. Year check
            if item.datasetYear != expectedYear {
                invalidCount += 1
                continue
            }
            
            validCount += 1
        }
        
        // Duplicate normalized tariff codes are preserved intentionally: the official
        // Oman tariff can list multiple distinct descriptions under the same local code.
        // They are reported for audit visibility, but are not treated as invalid.
        let isValid = (invalidCount == 0) && (validCount > 0)
        
        return TariffValidationReport(
            totalRecords: items.count,
            validRecords: validCount,
            invalidRecords: invalidCount,
            uniqueCodesCount: seenCodes.count,
            duplicateCodes: Array(duplicateCodes).sorted(),
            missingArabicDescriptionsCount: missingArCount,
            missingEnglishDescriptionsCount: missingEnCount,
            missingDutyValuesCount: missingDutyCount,
            prohibitedRecordsCount: prohibitedCount,
            restrictedRecordsCount: restrictedCount,
            unknownStatusRecordsCount: unknownStatusCount,
            recordsWithPageReferencesCount: pageRefCount,
            datasetYear: expectedYear,
            isValid: isValid
        )
    }
}
