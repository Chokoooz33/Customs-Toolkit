import XCTest
@testable import CustomsToolkit

final class GoldPriceServiceTests: XCTestCase {
    func testParsesApprovedOmanGoldPriceText() throws {
        let sample = """
        متوسط أسعار الذهب اليوم بأسواق الذهب في عمان
        العيار سعر البيع
        عيار 24 57.000 ريال
        عيار 22 52.250 ريال
        عيار 21 49.875 ريال
        عيار 18 42.750 ريال
        تم تحديث أسعار الذهب في عمان، السبت، 22 أغسطس، 12:34 مساءً
        الأسعار بالأيام السابقة
        """

        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = try GoldPriceService.parsePlainText(sample, fetchedAt: date)

        XCTAssertEqual(snapshot.price24, Decimal(string: "57.000"))
        XCTAssertEqual(snapshot.price22, Decimal(string: "52.250"))
        XCTAssertEqual(snapshot.price21, Decimal(string: "49.875"))
        XCTAssertEqual(snapshot.price18, Decimal(string: "42.750"))
        XCTAssertEqual(snapshot.fetchedAt, date)
        XCTAssertTrue(snapshot.sourceUpdatedText?.contains("22 أغسطس") == true)
    }

    func testMissingKaratFailsInsteadOfInventingPrice() {
        let incomplete = "عيار 24 57.000 ريال عيار 22 52.250 ريال"
        XCTAssertThrowsError(try GoldPriceService.parsePlainText(incomplete))
    }
}
