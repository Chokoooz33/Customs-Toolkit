import SwiftUI

@Observable
public final class UnitConverterViewModel {

    public var selectedPair: UnitConversionPair = .caratGram {
        didSet {
            if direction.pair != selectedPair {
                direction = selectedPair.defaultDirection
                inputValue = ""
                resultDecimal = nil
                formattedResult = ""
            }
            recalculate()
        }
    }

    public var inputValue: String = "" {
        didSet { recalculate() }
    }

    public var densityInput: String = "" {
        didSet { recalculate() }
    }

    public var direction: UnitConversionDirection = .caratToGram {
        didSet { recalculate() }
    }

    public var resultDecimal: Decimal?
    public var formattedResult: String = ""
    public var isValid: Bool = true
    public var isDensityValid: Bool = true

    public init() {}

    public func recalculate() {
        let outcome = UnitConversionService.convert(
            textInput: inputValue,
            direction: direction,
            densityInput: densityInput
        )
        resultDecimal = outcome.result
        formattedResult = outcome.formattedResult
        isValid = outcome.isValid
        isDensityValid = outcome.isDensityValid
    }

    public func swapDirection() {
        HapticFeedback.selection()

        if let result = resultDecimal {
            inputValue = result.plainDecimalString(fractionDigits: 6)
        }

        direction = direction.swapped
    }

    public func reset() {
        HapticFeedback.impact(style: .light)
        inputValue = ""
        densityInput = ""
        resultDecimal = nil
        formattedResult = ""
        isValid = true
        isDensityValid = true
    }

    public func copyResult() {
        guard let result = resultDecimal else { return }
        let textToCopy = result.formattedUnit(unit: direction.targetUnit, maxFractionDigits: 6)
        ClipboardService.copy(textToCopy)
        HapticFeedback.success()
    }
}
