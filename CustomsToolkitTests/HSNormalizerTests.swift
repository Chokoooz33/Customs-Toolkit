import XCTest
@testable import CustomsToolkit

final class HSNormalizerTests: XCTestCase {
    
    func testNormalizationWithSpaces() {
        // "12 34 56 78" -> "12345678"
        XCTAssertEqual(HSNormalizer.normalize("12 34 56 78"), "12345678")
        XCTAssertEqual(HSNormalizer.normalize(" 33 03 00 10 "), "33030010")
        XCTAssertEqual(HSNormalizer.normalize("33 03"), "3303")
        
        // Long Oman local code with spaces: "01 01 21 10 00 01" -> "010121100001"
        XCTAssertEqual(HSNormalizer.normalize("01 01 21 10 00 01"), "010121100001")
    }
    
    func testNormalizationWithPunctuation() {
        // "33.03.00.10" -> "33030010"
        XCTAssertEqual(HSNormalizer.normalize("33.03.00.10"), "33030010")
        // "3303-00-10" -> "33030010"
        XCTAssertEqual(HSNormalizer.normalize("3303-00-10"), "33030010")
        // "3303/00/10" -> "33030010"
        XCTAssertEqual(HSNormalizer.normalize("3303/00/10"), "33030010")
        
        // Long Oman local code with dots and dashes:
        // "01.01.21.10.00.01" -> "010121100001"
        XCTAssertEqual(HSNormalizer.normalize("01.01.21.10.00.01"), "010121100001")
        // "01-01-21-10-00-01" -> "010121100001"
        XCTAssertEqual(HSNormalizer.normalize("01-01-21-10-00-01"), "010121100001")
    }
    
    func testArabicIndicDigitNormalization() {
        // "٣٣٠٣٠٠١٠" -> "33030010"
        XCTAssertEqual(HSNormalizer.normalize("٣٣٠٣٠٠١٠"), "33030010")
        XCTAssertEqual(HSNormalizer.normalize("٣٣ ٠٣"), "3303")
        
        // Long Oman local code in Arabic-Indic digits: "٠١٠١٢١١٠٠٠٠١" -> "010121100001"
        XCTAssertEqual(HSNormalizer.normalize("٠١٠١٢١١٠٠٠٠١"), "010121100001")
        XCTAssertEqual(HSNormalizer.normalize("٠١ ٠١ ٢١ ١٠ ٠٠ ٠١"), "010121100001")
    }
    
    func testDisplayFormatting() {
        // 12 digits (Oman full local code)
        XCTAssertEqual(HSNormalizer.formatForDisplay("010121100001"), "0101 21 10 00 01")
        // 10 digits
        XCTAssertEqual(HSNormalizer.formatForDisplay("0101211000"), "0101 21 10 00")
        // 8 digits
        XCTAssertEqual(HSNormalizer.formatForDisplay("33030010"), "3303 00 10")
        // 6 digits
        XCTAssertEqual(HSNormalizer.formatForDisplay("330300"), "3303 00")
        // 4 digits
        XCTAssertEqual(HSNormalizer.formatForDisplay("3303"), "3303")
        // 2 digits
        XCTAssertEqual(HSNormalizer.formatForDisplay("01"), "01")
    }
    
    func testQueryValidation() {
        XCTAssertTrue(HSNormalizer.isValidQuery("01"))
        XCTAssertTrue(HSNormalizer.isValidQuery("0101"))
        XCTAssertTrue(HSNormalizer.isValidQuery("010121"))
        XCTAssertTrue(HSNormalizer.isValidQuery("01012110"))
        XCTAssertTrue(HSNormalizer.isValidQuery("0101211000"))
        XCTAssertTrue(HSNormalizer.isValidQuery("010121100001"))
        XCTAssertTrue(HSNormalizer.isValidQuery(" 01 01 21 10 00 01 "))
        XCTAssertFalse(HSNormalizer.isValidQuery(""))
        XCTAssertFalse(HSNormalizer.isValidQuery("   "))
    }
    
    func testArabicTextSearchNormalization() {
        // Tashkeel removal and Alef unification
        let normalized1 = HSNormalizer.normalizeArabicForSearch("عُطُورٌ")
        XCTAssertEqual(normalized1, "عطور")
        
        let normalized2 = HSNormalizer.normalizeArabicForSearch("أحصنة وخيول أصلية")
        XCTAssertEqual(normalized2, "احصنه وخيول اصليه")
    }
}
