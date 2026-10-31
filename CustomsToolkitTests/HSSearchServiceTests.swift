import XCTest
@testable import CustomsToolkit

final class HSSearchServiceTests: XCTestCase {
    
    func testDefaultProductionStatusIsPendingInstallation() {
        let service = HSSearchService()
        switch service.status {
        case .notInstalled(let reason):
            XCTAssertTrue(reason.contains("not installed"))
        case .ready:
            XCTFail("Production service must not contain preloaded fake records")
        }
        XCTAssertTrue(service.search(query: "0101").isEmpty)
    }
    
    func testPrefixAndExactSearchWithLongOmanFixtures() {
        // Isolated test fixtures for search algorithm verification only
        let testFixtures = [
            HSCodeItem(
                code: "0101 21 10 00 01",
                normalizedCode: "010121100001",
                descriptionArabic: "خيول حية أصيلة للتكاثر",
                descriptionEnglish: "Live pure-bred breeding horses",
                dutyRate: "0%",
                status: .normal,
                chapter: "01",
                sourcePage: 15,
                datasetYear: 2026
            ),
            HSCodeItem(
                code: "0101 21 10 00 99",
                normalizedCode: "010121100099",
                descriptionArabic: "خيول حية أخرى",
                descriptionEnglish: "Other live horses",
                dutyRate: "5%",
                status: .normal,
                chapter: "01",
                sourcePage: 15,
                datasetYear: 2026
            ),
            HSCodeItem(
                code: "3303 00 10",
                normalizedCode: "33030010",
                descriptionArabic: "عطور سائلة",
                descriptionEnglish: "Perfumes (liquid)",
                dutyRate: "5%",
                status: .restricted,
                chapter: "33",
                sourcePage: 142,
                datasetYear: 2026
            )
        ]
        
        let service = HSSearchService(initialDataset: testFixtures)
        
        // 1. Partial 2-digit prefix search: "01" -> matches 2 horse items
        let results2 = service.search(query: "01")
        XCTAssertEqual(results2.count, 2)
        
        // 2. Partial 4-digit prefix search: "0101" -> matches 2 horse items
        let results4 = service.search(query: "0101")
        XCTAssertEqual(results4.count, 2)
        
        // 3. Partial 6-digit prefix search: "010121"
        let results6 = service.search(query: "010121")
        XCTAssertEqual(results6.count, 2)
        
        // 4. Partial 8-digit prefix search: "01012110"
        let results8 = service.search(query: "01012110")
        XCTAssertEqual(results8.count, 2)
        
        // 5. Partial 10-digit prefix search: "0101211000"
        let results10 = service.search(query: "0101211000")
        XCTAssertEqual(results10.count, 2)
        
        // 6. Full 12-digit exact search: "010121100001"
        let results12 = service.search(query: "010121100001")
        XCTAssertEqual(results12.count, 1)
        XCTAssertEqual(results12.first?.normalizedCode, "010121100001")
        XCTAssertEqual(results12.first?.sourcePage, 15)
        
        // 7. Full 12-digit search with spaces: "01 01 21 10 00 01"
        let results12Spaced = service.search(query: "01 01 21 10 00 01")
        XCTAssertEqual(results12Spaced.count, 1)
        XCTAssertEqual(results12Spaced.first?.normalizedCode, "010121100001")
    }
    
    func testExactMatchRankingPriority() {
        let testFixtures = [
            HSCodeItem(
                code: "3303",
                normalizedCode: "3303",
                descriptionArabic: "عطور ومياه تواليت (بند)",
                descriptionEnglish: "Perfumes and toilet waters",
                datasetYear: 2026
            ),
            HSCodeItem(
                code: "3303 00 10",
                normalizedCode: "33030010",
                descriptionArabic: "عطور",
                descriptionEnglish: "Perfumes",
                datasetYear: 2026
            )
        ]
        
        let service = HSSearchService(initialDataset: testFixtures)
        
        // Searching for "3303" must return the exact match first
        let results = service.search(query: "3303")
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results.first?.normalizedCode, "3303")
    }
    
    func testLanguageDescriptionSearchWithFixtures() {
        let testFixtures = [
            HSCodeItem(
                code: "010121100001",
                descriptionArabic: "خيول حية للتكاثر",
                descriptionEnglish: "Live breeding horses",
                datasetYear: 2026
            ),
            HSCodeItem(
                code: "33030010",
                descriptionArabic: "عطور سائلة فاخرة",
                descriptionEnglish: "Luxury liquid perfumes",
                datasetYear: 2026
            )
        ]
        
        let service = HSSearchService(initialDataset: testFixtures)
        
        // English description search
        let enResults = service.search(query: "horses")
        XCTAssertEqual(enResults.count, 1)
        XCTAssertEqual(enResults.first?.normalizedCode, "010121100001")
        
        // Arabic description search
        let arResults = service.search(query: "عطور")
        XCTAssertEqual(arResults.count, 1)
        XCTAssertEqual(arResults.first?.normalizedCode, "33030010")
    }
    func testSearchResultSetPreservesTotalCountWhileLimitingVisibleResults() {
        let fixtures = (0..<220).map { index in
            let suffix = String(format: "%04d", index)
            return HSCodeItem(
                code: "33030010\(suffix)",
                normalizedCode: "33030010\(suffix)",
                descriptionArabic: "عطر اختبار \(index)",
                descriptionEnglish: "Test perfume \(index)",
                dutyRate: "5%",
                datasetYear: 2026
            )
        }

        let service = HSSearchService(initialDataset: fixtures)
        let resultSet = service.searchResultSet(query: "3303", limit: 160)

        XCTAssertEqual(resultSet.totalMatches, 220)
        XCTAssertEqual(resultSet.items.count, 160)
        XCTAssertTrue(resultSet.isTruncated)
    }

}
