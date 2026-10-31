import XCTest
@testable import CustomsToolkit

final class CurrencyConversionTests: XCTestCase {
    
    func testMultiplyConvention() {
        // OMR Amount: 5,902.200 OMR
        // Rate: 2.6008 (USD/OMR)
        // Expected: 5902.200 * 2.6008 = 15350.44176
        let omr = Decimal(string: "5902.200")!
        let rate = Decimal(string: "2.6008")!
        
        let result = CurrencyConversionService.convert(
            omrAmount: omr,
            exchangeRate: rate,
            convention: .multiply
        )
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result, Decimal(string: "15350.44176"))
    }
    
    func testDivideConvention() {
        // OMR Amount: 1,000.000 OMR
        // Rate: 0.5 (e.g. 1 Target = 0.5 OMR)
        // Expected: 1000 / 0.5 = 2000
        let omr = Decimal(string: "1000.000")!
        let rate = Decimal(string: "0.5")!
        
        let result = CurrencyConversionService.convert(
            omrAmount: omr,
            exchangeRate: rate,
            convention: .divide
        )
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result, Decimal(string: "2000"))
    }
    
    func testZeroAndNegativeExchangeRates() {
        let omr = Decimal(string: "500.000")!
        
        // Zero rate should return nil to avoid division by zero or invalid conversions
        let zeroResult = CurrencyConversionService.convert(
            omrAmount: omr,
            exchangeRate: Decimal(0),
            convention: .divide
        )
        XCTAssertNil(zeroResult)
        
        // Negative rate should return nil
        let negResult = CurrencyConversionService.convert(
            omrAmount: omr,
            exchangeRate: Decimal(-1),
            convention: .multiply
        )
        XCTAssertNil(negResult)
    }
    
    func testExchangeRateStringParser() {
        // Valid dot format
        XCTAssertEqual(CurrencyConversionService.parseExchangeRate("2.6008"), Decimal(string: "2.6008"))
        
        // Valid comma format
        XCTAssertEqual(CurrencyConversionService.parseExchangeRate("2,6008"), Decimal(string: "2.6008"))
        
        // Invalid input
        XCTAssertNil(CurrencyConversionService.parseExchangeRate("abc"))
        XCTAssertNil(CurrencyConversionService.parseExchangeRate("-1.5"))
        XCTAssertNil(CurrencyConversionService.parseExchangeRate("0"))
    }
}
