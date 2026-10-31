import XCTest
@testable import CustomsToolkit

final class HSCodeCandidateExtractorTests: XCTestCase {
    func testExtractsSpacedOmanLocalCode() {
        let text = "HS CODE: 01 01 21 10 00 01\nDescription: Horses"
        XCTAssertTrue(HSCodeCandidateExtractor.candidates(from: text).contains("010121100001"))
    }

    func testExtractsArabicIndicCode() {
        let text = "رمز HS ٣٣ ٠٣ ٠٠ ١٠ ٠٠ ٠٠"
        XCTAssertTrue(HSCodeCandidateExtractor.candidates(from: text).contains("330300100000"))
    }

    func testDoesNotDuplicateCandidate() {
        let text = "3303.00.10 and again 3303-00-10"
        let candidates = HSCodeCandidateExtractor.candidates(from: text)
        XCTAssertEqual(candidates.filter { $0 == "33030010" }.count, 1)
    }
}
