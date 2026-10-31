import XCTest
@testable import CustomsToolkit

final class GoldPriceConfigTests: XCTestCase {
    
    func testGoldPriceURLConfiguration() {
        XCTAssertEqual(AppConfig.trustedGoldPriceURL, "https://www.gold-price-today.com/oman/")
        XCTAssertNotNil(URL(string: AppConfig.trustedGoldPriceURL))
        XCTAssertTrue(AppConfig.trustedGoldPriceURL.starts(with: "https://"))
    }
}
