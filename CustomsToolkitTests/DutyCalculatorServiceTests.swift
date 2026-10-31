import XCTest
@testable import CustomsToolkit

final class DutyCalculatorServiceTests: XCTestCase {
    func testCIFCompanyOriginalDocuments() throws {
        let result = try XCTUnwrap(DutyCalculatorService.calculate(
            deliveryTerm: .cif,
            cifValue: Decimal(string: "1000")!,
            dutyRate: Decimal(string: "0.05")!,
            importerType: .company,
            documentStatus: .original
        ))

        XCTAssertEqual(result.cifOMR, Decimal(string: "1000.000")!)
        XCTAssertEqual(result.dutyOMR, Decimal(string: "50.000")!)
        XCTAssertEqual(result.vatBaseOMR, Decimal(string: "1050.000")!)
        XCTAssertEqual(result.vatOMR, Decimal(string: "52.500")!)
        XCTAssertEqual(result.totalTaxesOMR, Decimal(string: "102.500")!)
        XCTAssertEqual(result.documentationGuaranteeOMR, .zero)
        XCTAssertEqual(result.bayanDocumentationOMR, Decimal(string: "15.000")!)
        XCTAssertEqual(result.totalPayableOMR, Decimal(string: "117.500")!)
    }

    func testUserConfirmedExampleCIF2000CompanyNotOriginalTotals260() throws {
        let result = try XCTUnwrap(DutyCalculatorService.calculate(
            deliveryTerm: .cif,
            cifValue: Decimal(string: "2000")!,
            dutyRate: Decimal(string: "0.05")!,
            importerType: .company,
            documentStatus: .notOriginal
        ))

        XCTAssertEqual(result.dutyOMR, Decimal(string: "100.000")!)
        XCTAssertEqual(result.vatOMR, Decimal(string: "105.000")!)
        XCTAssertEqual(result.totalTaxesOMR, Decimal(string: "205.000")!)
        XCTAssertEqual(result.documentationGuaranteeOMR, Decimal(string: "40.000")!)
        XCTAssertEqual(result.bayanDocumentationOMR, Decimal(string: "15.000")!)
        XCTAssertEqual(result.totalPayableOMR, Decimal(string: "260.000")!)
    }

    func testPersonalBayanDocumentationIsFiveOMR() throws {
        let result = try XCTUnwrap(DutyCalculatorService.calculate(
            deliveryTerm: .cif,
            cifValue: Decimal(string: "2000")!,
            dutyRate: Decimal(string: "0.05")!,
            importerType: .personal,
            documentStatus: .notOriginal
        ))

        XCTAssertEqual(result.bayanDocumentationOMR, Decimal(string: "5.000")!)
        XCTAssertEqual(result.totalPayableOMR, Decimal(string: "250.000")!)
    }

    func testGuaranteeDoesNotApplyAtExactly1000OMR() throws {
        let result = try XCTUnwrap(DutyCalculatorService.calculate(
            deliveryTerm: .cif,
            cifValue: Decimal(string: "1000")!,
            dutyRate: Decimal(string: "0.05")!,
            importerType: .company,
            documentStatus: .notOriginal
        ))

        XCTAssertEqual(result.documentationGuaranteeOMR, .zero)
    }

    func testFOBSupportsDifferentCostAndFreightCurrencies() throws {
        let result = try XCTUnwrap(DutyCalculatorService.calculate(
            deliveryTerm: .fob,
            costValue: Decimal(string: "1000")!,
            costCurrency: .usd,
            costRateToOMR: Decimal(string: "0.385")!,
            freightValue: Decimal(string: "100")!,
            freightCurrency: .omr,
            dutyRate: Decimal(string: "0.05")!,
            importerType: .company,
            documentStatus: .original
        ))

        // Cost = 385 OMR, Freight = 100 OMR, Insurance = 4.85 OMR, CIF = 489.85 OMR.
        XCTAssertEqual(result.costOMR, Decimal(string: "385.000")!)
        XCTAssertEqual(result.freightOMR, Decimal(string: "100.000")!)
        XCTAssertEqual(result.insuranceOMR, Decimal(string: "4.850")!)
        XCTAssertEqual(result.cifOMR, Decimal(string: "489.850")!)
    }

    func testCFRAutomaticInsuranceOnePercent() throws {
        let result = try XCTUnwrap(DutyCalculatorService.calculate(
            deliveryTerm: .cfr,
            cfrValue: Decimal(string: "1000")!,
            dutyRate: Decimal(string: "0.05")!,
            importerType: .company,
            documentStatus: .original
        ))

        XCTAssertEqual(result.insuranceOMR, Decimal(string: "10.000")!)
        XCTAssertEqual(result.cifOMR, Decimal(string: "1010.000")!)
    }

    func testZeroDutyHSStillCalculatesStandardVATAndBayanDocumentation() throws {
        let result = try XCTUnwrap(DutyCalculatorService.calculate(
            deliveryTerm: .cif,
            cifValue: Decimal(string: "500")!,
            dutyRate: .zero,
            importerType: .company,
            documentStatus: .original
        ))

        XCTAssertEqual(result.dutyOMR, .zero)
        XCTAssertEqual(result.vatOMR, Decimal(string: "25.000")!)
        XCTAssertEqual(result.totalPayableOMR, Decimal(string: "40.000")!)
    }

    func testForeignCIFCurrencyConvertedToOMR() throws {
        let result = try XCTUnwrap(DutyCalculatorService.calculate(
            deliveryTerm: .cif,
            cifValue: Decimal(string: "1000")!,
            cifCurrency: .usd,
            cifRateToOMR: Decimal(string: "0.385")!,
            dutyRate: Decimal(string: "0.05")!
        ))

        XCTAssertEqual(result.cifOMR, Decimal(string: "385.000")!)
    }

    func testDutyPercentageParser() {
        XCTAssertEqual(DutyCalculatorService.parsePercentage("5%"), Decimal(string: "0.05")!)
        XCTAssertEqual(DutyCalculatorService.parsePercentage("100%"), Decimal(string: "1")!)
        XCTAssertNil(DutyCalculatorService.parsePercentage(nil))
    }
}
