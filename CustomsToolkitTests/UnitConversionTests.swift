import XCTest
@testable import CustomsToolkit

final class UnitConversionTests: XCTestCase {

    func testCaratToGramConversion() {
        XCTAssertEqual(UnitConversionService.convert(value: Decimal(1), direction: .caratToGram), Decimal(string: "0.2"))
        XCTAssertEqual(UnitConversionService.convert(value: Decimal(5), direction: .caratToGram), Decimal(string: "1.0"))
        XCTAssertEqual(UnitConversionService.convert(value: Decimal(string: "0.5")!, direction: .caratToGram), Decimal(string: "0.1"))
    }

    func testGramToCaratConversion() {
        XCTAssertEqual(UnitConversionService.convert(value: Decimal(1), direction: .gramToCarat), Decimal(string: "5.0"))
        XCTAssertEqual(UnitConversionService.convert(value: Decimal(string: "0.2")!, direction: .gramToCarat), Decimal(string: "1.0"))
    }

    func testGramKilogramConversionBothDirections() {
        XCTAssertEqual(UnitConversionService.convert(value: Decimal(1000), direction: .gramToKilogram), Decimal(1))
        XCTAssertEqual(UnitConversionService.convert(value: Decimal(string: "2.5")!, direction: .kilogramToGram), Decimal(2500))
    }

    func testSquareFootSquareMeterConversionBothDirections() {
        let sqm = UnitConversionService.convert(value: Decimal(1), direction: .squareFootToSquareMeter)
        XCTAssertEqual(sqm, Decimal(string: "0.09290304"))

        let sqft = UnitConversionService.convert(value: Decimal(1), direction: .squareMeterToSquareFoot)
        XCTAssertEqual(DecimalMath.round(sqft!, scale: 8), Decimal(string: "10.76391042"))
    }

    func testPoundKilogramConversionBothDirections() {
        let kg = UnitConversionService.convert(value: Decimal(1), direction: .poundToKilogram)
        XCTAssertEqual(kg, Decimal(string: "0.45359237"))

        let lb = UnitConversionService.convert(value: Decimal(1), direction: .kilogramToPound)
        XCTAssertEqual(DecimalMath.round(lb!, scale: 8), Decimal(string: "2.20462262"))
    }

    func testGramLiterRequiresDensity() {
        XCTAssertNil(UnitConversionService.convert(value: Decimal(1000), direction: .gramToLiter))
        XCTAssertNil(UnitConversionService.convert(value: Decimal(1000), direction: .gramToLiter, densityGramsPerMilliliter: .zero))
    }

    func testGramLiterWithWaterDensity() {
        let density = Decimal(string: "1.0")!
        XCTAssertEqual(
            UnitConversionService.convert(value: Decimal(1000), direction: .gramToLiter, densityGramsPerMilliliter: density),
            Decimal(1)
        )
        XCTAssertEqual(
            UnitConversionService.convert(value: Decimal(1), direction: .literToGram, densityGramsPerMilliliter: density),
            Decimal(1000)
        )
    }

    func testGramLiterWithNonWaterDensity() {
        let density = Decimal(string: "0.8")!
        XCTAssertEqual(
            UnitConversionService.convert(value: Decimal(800), direction: .gramToLiter, densityGramsPerMilliliter: density),
            Decimal(1)
        )
        XCTAssertEqual(
            UnitConversionService.convert(value: Decimal(2), direction: .literToGram, densityGramsPerMilliliter: density),
            Decimal(1600)
        )
    }

    func testZeroAndNegativeInputs() {
        XCTAssertEqual(UnitConversionService.convert(value: Decimal(0), direction: .caratToGram), Decimal(0))
        XCTAssertNil(UnitConversionService.convert(value: Decimal(-5), direction: .caratToGram))
    }

    func testStringConvenienceConverter() {
        let (res1, formatted1, valid1, densityValid1) = UnitConversionService.convert(textInput: "2,5", direction: .caratToGram)
        XCTAssertTrue(valid1)
        XCTAssertTrue(densityValid1)
        XCTAssertEqual(res1, Decimal(string: "0.5"))
        XCTAssertTrue(formatted1.contains("0.5"))

        let (resEmpty, _, validEmpty, _) = UnitConversionService.convert(textInput: "", direction: .gramToKilogram)
        XCTAssertTrue(validEmpty)
        XCTAssertNil(resEmpty)

        let (resInv, _, validInv, _) = UnitConversionService.convert(textInput: "abc", direction: .poundToKilogram)
        XCTAssertFalse(validInv)
        XCTAssertNil(resInv)
    }

    func testStringGramLiterDensityValidation() {
        let missing = UnitConversionService.convert(textInput: "1000", direction: .gramToLiter, densityInput: "")
        XCTAssertTrue(missing.isValid)
        XCTAssertFalse(missing.isDensityValid)
        XCTAssertNil(missing.result)

        let valid = UnitConversionService.convert(textInput: "1000", direction: .gramToLiter, densityInput: "1")
        XCTAssertTrue(valid.isValid)
        XCTAssertTrue(valid.isDensityValid)
        XCTAssertEqual(valid.result, Decimal(1))
    }
}
