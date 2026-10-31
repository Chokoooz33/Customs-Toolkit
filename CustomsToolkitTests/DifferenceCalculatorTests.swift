import XCTest
@testable import CustomsToolkit

final class DifferenceCalculatorTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Reset configuration to confirmed business values
        DifferenceCalculatorService.Configuration.vatRate = Decimal(string: "0.05")!
        DifferenceCalculatorService.Configuration.dutyAndVatAdjustment = Decimal(string: "97.566")!
        DifferenceCalculatorService.Configuration.vatOnlyAdjustment = Decimal(string: "200.000")!
    }
    
    func testTaxDifferenceModeWithDutyAndVat() {
        // Workflow example from specification:
        // Entered 5% Amount: 300 OMR
        // Base Amount = 300 ÷ 0.05 = 6,000.000 OMR
        // Condition: Duty + VAT (Adjustment = 97.566 OMR)
        // Adjusted Amount = 6,000.000 - 97.566 = 5,902.434 OMR
        
        let result = DifferenceCalculatorService.calculate(
            mode: .taxDifference,
            enteredAmount: Decimal(300),
            condition: .dutyAndVat,
            targetCurrency: .omr,
            exchangeRate: nil,
            rateConvention: .multiply
        )
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.enteredAmount, Decimal(300))
        XCTAssertEqual(result?.calculatedOriginalAmount, Decimal(6000))
        XCTAssertEqual(result?.adjustmentAmount, Decimal(string: "97.566"))
        XCTAssertEqual(result?.adjustedOMRAmount, Decimal(string: "5902.434"))
        XCTAssertEqual(result?.finalDeclarationValue, Decimal(string: "5902.434"))
        XCTAssertEqual(result?.targetCurrencyCode, "OMR")
    }
    
    func testTaxDifferenceModeWithVatOnly() {
        // Entered 5% Amount: 300 OMR
        // Base Amount = 6,000.000 OMR
        // Condition: VAT Only (Adjustment = 200.000 OMR)
        // Adjusted Amount = 5,800.000 OMR
        
        let result = DifferenceCalculatorService.calculate(
            mode: .taxDifference,
            enteredAmount: Decimal(300),
            condition: .vatOnly,
            targetCurrency: .omr,
            exchangeRate: nil,
            rateConvention: .multiply
        )
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.calculatedOriginalAmount, Decimal(6000))
        XCTAssertEqual(result?.adjustmentAmount, Decimal(string: "200.000"))
        XCTAssertEqual(result?.adjustedOMRAmount, Decimal(string: "5800.000"))
    }
    
    func testOriginalAmountMode() {
        // Direct Original Amount: 6,000 OMR
        // Condition: Duty + VAT (Adjustment: 97.566 OMR)
        // Adjusted Amount: 5,902.434 OMR
        
        let result = DifferenceCalculatorService.calculate(
            mode: .originalAmount,
            enteredAmount: Decimal(6000),
            condition: .dutyAndVat,
            targetCurrency: .omr,
            exchangeRate: nil,
            rateConvention: .multiply
        )
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.enteredAmount, Decimal(6000))
        XCTAssertEqual(result?.calculatedOriginalAmount, Decimal(6000))
        XCTAssertEqual(result?.adjustedOMRAmount, Decimal(string: "5902.434"))
    }
    
    func testFinancialDecimalPrecision() {
        // Test precision with fractional values:
        // Entered: 12.345 OMR -> Base: 12.345 / 0.05 = 246.900 OMR
        // Adjusted: 246.900 - 97.566 = 149.334 OMR
        let result = DifferenceCalculatorService.calculate(
            mode: .taxDifference,
            enteredAmount: Decimal(string: "12.345")!,
            condition: .dutyAndVat,
            targetCurrency: .omr,
            exchangeRate: nil,
            rateConvention: .multiply
        )
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.calculatedOriginalAmount, Decimal(string: "246.900"))
        XCTAssertEqual(result?.adjustedOMRAmount, Decimal(string: "149.334"))
    }
    
    func testConfirmedAdjustmentBusinessRules() {
        XCTAssertEqual(DifferenceCalculatorService.Configuration.dutyAndVatAdjustment, Decimal(string: "97.566"))
        XCTAssertEqual(DifferenceCalculatorService.Configuration.vatOnlyAdjustment, Decimal(string: "200.000"))

        // Excel workbook example: 2,674.897 - 97.566 = 2,577.331 OMR.
        let excelAdjusted = DecimalMath.subtract(Decimal(string: "2674.897")!, minus: DifferenceCalculatorService.Configuration.dutyAndVatAdjustment)
        XCTAssertEqual(excelAdjusted, Decimal(string: "2577.331"))
    }

    func testNegativeAmountHandling() {
        let result = DifferenceCalculatorService.calculate(
            mode: .taxDifference,
            enteredAmount: Decimal(-100),
            condition: .dutyAndVat,
            targetCurrency: .omr,
            exchangeRate: nil,
            rateConvention: .multiply
        )
        XCTAssertNil(result)
    }
}
