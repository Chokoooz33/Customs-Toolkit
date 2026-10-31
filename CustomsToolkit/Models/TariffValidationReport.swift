import Foundation

/// Comprehensive validation report for an imported or decoded Oman tariff dataset.
public struct TariffValidationReport: Codable, Equatable {
    public let totalRecords: Int
    public let validRecords: Int
    public let invalidRecords: Int
    public let uniqueCodesCount: Int
    public let duplicateCodes: [String]
    public let missingArabicDescriptionsCount: Int
    public let missingEnglishDescriptionsCount: Int
    public let missingDutyValuesCount: Int
    public let prohibitedRecordsCount: Int
    public let restrictedRecordsCount: Int
    public let unknownStatusRecordsCount: Int
    public let recordsWithPageReferencesCount: Int
    public let datasetYear: Int
    public let isValid: Bool
    
    public init(
        totalRecords: Int,
        validRecords: Int,
        invalidRecords: Int,
        uniqueCodesCount: Int,
        duplicateCodes: [String],
        missingArabicDescriptionsCount: Int,
        missingEnglishDescriptionsCount: Int,
        missingDutyValuesCount: Int,
        prohibitedRecordsCount: Int,
        restrictedRecordsCount: Int,
        unknownStatusRecordsCount: Int,
        recordsWithPageReferencesCount: Int,
        datasetYear: Int,
        isValid: Bool
    ) {
        self.totalRecords = totalRecords
        self.validRecords = validRecords
        self.invalidRecords = invalidRecords
        self.uniqueCodesCount = uniqueCodesCount
        self.duplicateCodes = duplicateCodes
        self.missingArabicDescriptionsCount = missingArabicDescriptionsCount
        self.missingEnglishDescriptionsCount = missingEnglishDescriptionsCount
        self.missingDutyValuesCount = missingDutyValuesCount
        self.prohibitedRecordsCount = prohibitedRecordsCount
        self.restrictedRecordsCount = restrictedRecordsCount
        self.unknownStatusRecordsCount = unknownStatusRecordsCount
        self.recordsWithPageReferencesCount = recordsWithPageReferencesCount
        self.datasetYear = datasetYear
        self.isValid = isValid
    }
}
