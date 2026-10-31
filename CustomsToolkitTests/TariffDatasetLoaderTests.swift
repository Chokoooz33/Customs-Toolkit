import XCTest
@testable import CustomsToolkit

final class TariffDatasetLoaderTests: XCTestCase {
    
    private let loader = TariffDatasetLoader()
    
    func testMissingResourceReturnsError() {
        let result = loader.loadBundledDataset(resourceName: "non_existent_dataset_file")
        switch result {
        case .failure(let error):
            if case .resourceNotFound = error {
                // Expected
            } else {
                XCTFail("Expected resourceNotFound error, got \(error)")
            }
        case .success:
            XCTFail("Missing resource should not succeed")
        }
    }
    
    func testValidDatasetDecodingAndReport() {
        let validJSON = """
        {
            "metadata": {
                "country": "Oman",
                "year": 2026,
                "source": "Official Oman Customs Tariff 2026",
                "recordCount": 2,
                "datasetVersion": "2026.1"
            },
            "records": [
                {
                    "id": "1",
                    "code": "0101 21 10 00 01",
                    "normalizedCode": "010121100001",
                    "descriptionArabic": "خيول حية أصيلة للتكاثر",
                    "descriptionEnglish": "Live pure-bred breeding horses",
                    "dutyRate": "0%",
                    "status": "normal",
                    "datasetYear": 2026
                },
                {
                    "id": "2",
                    "code": "3303 00 10",
                    "normalizedCode": "33030010",
                    "descriptionArabic": "عطور",
                    "descriptionEnglish": "Perfumes",
                    "dutyRate": "5%",
                    "status": "restricted",
                    "datasetYear": 2026
                }
            ]
        }
        """
        
        let data = validJSON.data(using: .utf8)!
        let result = loader.decodeAndValidate(jsonData: data)
        
        switch result {
        case .success((let metadata, let records, let report)):
            XCTAssertEqual(metadata.country, "Oman")
            XCTAssertEqual(metadata.year, 2026)
            XCTAssertEqual(records.count, 2)
            XCTAssertTrue(report.isValid)
            XCTAssertEqual(report.validRecords, 2)
            XCTAssertEqual(report.invalidRecords, 0)
            XCTAssertEqual(report.uniqueCodesCount, 2)
            XCTAssertTrue(report.duplicateCodes.isEmpty)
            XCTAssertEqual(report.restrictedRecordsCount, 1)
        case .failure(let error):
            XCTFail("Valid dataset should succeed: \(error)")
        }
    }
    
    func testInvalidJSONReturnsDecodingError() {
        let invalidJSON = "{ broken json"
        let data = invalidJSON.data(using: .utf8)!
        let result = loader.decodeAndValidate(jsonData: data)
        
        switch result {
        case .failure(let error):
            if case .decodingFailed = error {
                // Expected
            } else {
                XCTFail("Expected decodingFailed, got \(error)")
            }
        case .success:
            XCTFail("Invalid JSON should fail")
        }
    }
    
    func testDuplicateCodesDetectionInReport() {
        let duplicateItems = [
            HSCodeItem(
                code: "0101 21 10 00 01",
                normalizedCode: "010121100001",
                descriptionEnglish: "Horses 1",
                datasetYear: 2026
            ),
            HSCodeItem(
                code: "010121100001",
                normalizedCode: "010121100001",
                descriptionEnglish: "Horses duplicate",
                datasetYear: 2026
            )
        ]
        
        let report = loader.validateDataset(duplicateItems, expectedYear: 2026)
        XCTAssertTrue(report.isValid)
        XCTAssertEqual(report.duplicateCodes, ["010121100001"])
        XCTAssertEqual(report.validRecords, 2)
    }
    
    func testYearMismatchDetectionInReport() {
        let items = [
            HSCodeItem(
                code: "010121100001",
                normalizedCode: "010121100001",
                descriptionEnglish: "Horses",
                datasetYear: 2024 // Mismatched year
            )
        ]
        
        let report = loader.validateDataset(items, expectedYear: 2026)
        XCTAssertFalse(report.isValid)
        XCTAssertEqual(report.invalidRecords, 1)
    }
    
    func testEmptyDatasetValidation() {
        let report = loader.validateDataset([], expectedYear: 2026)
        XCTAssertFalse(report.isValid)
        XCTAssertEqual(report.totalRecords, 0)
    }
    func testBundledProductionTariffLoadsWithExpectedStatistics() {
        let result = loader.loadBundledDataset()

        switch result {
        case .success((let metadata, let records, let report)):
            XCTAssertEqual(metadata.country, "Oman")
            XCTAssertEqual(metadata.year, 2026)
            XCTAssertEqual(metadata.datasetVersion, "2026.2-hierarchy-audit")
            XCTAssertEqual(metadata.recordCount, 14_365)
            XCTAssertEqual(records.count, 14_365)
            XCTAssertEqual(report.uniqueCodesCount, 14_313)
            XCTAssertEqual(report.duplicateCodes.count, 6)
            XCTAssertEqual(report.prohibitedRecordsCount, 94)
            XCTAssertEqual(report.missingArabicDescriptionsCount, 7)
            XCTAssertEqual(report.missingEnglishDescriptionsCount, 2)
            XCTAssertEqual(report.missingDutyValuesCount, 145)
            XCTAssertTrue(report.isValid)

            // V4.3.2 hierarchy audit: every production row must have official chapter + heading context.
            XCTAssertTrue(records.allSatisfy { !($0.chapterDescriptionEnglish ?? "").isEmpty })
            XCTAssertTrue(records.allSatisfy { !($0.headingDescriptionEnglish ?? "").isEmpty })

            let freon = records.first { $0.normalizedCode == "731100200000" }
            XCTAssertEqual(freon?.chapterDescriptionEnglish, "Articles of iron or steel")
            XCTAssertEqual(freon?.headingDescriptionEnglish, "Containers for compressed or liquefied gas, of iron or steel.")
            XCTAssertNil(freon?.subheadingDescriptionEnglish) // 73.11 has no separate official 7311.00 parent wording.

            let other8537 = records.first { $0.normalizedCode == "853710009999" }
            XCTAssertEqual(other8537?.subheadingDescriptionEnglish, "For a voltage not exceeding 1,000 V")
        case .failure(let error):
            XCTFail("Bundled production tariff must load successfully: \(error)")
        }
    }

}
