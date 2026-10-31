import SwiftUI

public enum AppTypography {
    
    public static let largeTitle = Font.system(.largeTitle, design: .default, weight: .bold)
    public static let title1 = Font.system(.title, design: .default, weight: .bold)
    public static let title2 = Font.system(.title2, design: .default, weight: .semibold)
    public static let title3 = Font.system(.title3, design: .default, weight: .semibold)
    public static let headline = Font.system(.headline, design: .default, weight: .semibold)
    public static let body = Font.system(.body, design: .default, weight: .regular)
    public static let callout = Font.system(.callout, design: .default, weight: .regular)
    public static let subheadline = Font.system(.subheadline, design: .default, weight: .regular)
    public static let footnote = Font.system(.footnote, design: .default, weight: .regular)
    public static let caption = Font.system(.caption, design: .default, weight: .regular)
    public static let caption2 = Font.system(.caption2, design: .default, weight: .medium)
    
    // Monospaced for technical numbers and HS codes
    public static let technicalNumberLarge = Font.system(size: 32, weight: .bold, design: .monospaced)
    public static let technicalNumberMedium = Font.system(size: 20, weight: .semibold, design: .monospaced)
    public static let technicalNumberSmall = Font.system(size: 15, weight: .medium, design: .monospaced)
}
