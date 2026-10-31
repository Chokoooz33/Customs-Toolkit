import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public enum AppColors {
    
    // MARK: - Primary Brand Colors
    public static let brandPrimary = Color(
        light: Color(red: 15/255, green: 76/255, blue: 129/255),
        dark: Color(red: 70/255, green: 145/255, blue: 230/255)
    )
    
    public static let brandSecondary = Color(
        light: Color(red: 30/255, green: 41/255, blue: 59/255),
        dark: Color(red: 148/255, green: 163/255, blue: 184/255)
    )

    /// Deep navy used for the dashboard hero and premium navigation surfaces.
    public static let brandDeepNavy = Color(
        light: Color(red: 7/255, green: 38/255, blue: 74/255),
        dark: Color(red: 4/255, green: 23/255, blue: 45/255)
    )

    /// Restrained gold accent used for identity and status emphasis.
    public static let brandGold = Color(
        light: Color(red: 220/255, green: 169/255, blue: 55/255),
        dark: Color(red: 239/255, green: 192/255, blue: 78/255)
    )

    /// Main numeric value on the gold-price card: navy in light mode, high-contrast white in dark mode.
    public static let goldPriceValue = Color(
        light: Color(red: 7/255, green: 38/255, blue: 74/255),
        dark: Color.white.opacity(0.96)
    )
    
    // MARK: - Surfaces & Backgrounds
    #if os(iOS)
    public static let background = Color(uiColor: .systemBackground)
    public static let secondaryBackground = Color(uiColor: .secondarySystemBackground)
    public static let tertiaryBackground = Color(uiColor: .tertiarySystemBackground)
    public static let groupedBackground = Color(uiColor: .systemGroupedBackground)
    public static let secondaryGroupedBackground = Color(uiColor: .secondarySystemGroupedBackground)
    public static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)
    public static let innerCardBackground = Color(uiColor: .tertiarySystemGroupedBackground)
    public static let border = Color(uiColor: .separator).opacity(0.6)
    public static let subtleBorder = Color(uiColor: .separator).opacity(0.3)
    public static let textPrimary = Color(uiColor: .label)
    public static let textSecondary = Color(uiColor: .secondaryLabel)
    public static let textTertiary = Color(uiColor: .tertiaryLabel)
    #else
    public static let background = Color.white
    public static let secondaryBackground = Color.gray.opacity(0.1)
    public static let tertiaryBackground = Color.gray.opacity(0.15)
    public static let groupedBackground = Color.gray.opacity(0.08)
    public static let secondaryGroupedBackground = Color.white
    public static let cardBackground = Color.white
    public static let innerCardBackground = Color.gray.opacity(0.1)
    public static let border = Color.gray.opacity(0.3)
    public static let subtleBorder = Color.gray.opacity(0.15)
    public static let textPrimary = Color.primary
    public static let textSecondary = Color.secondary
    public static let textTertiary = Color.gray
    #endif
    
    // MARK: - Status
    public static let success = Color(
        light: Color(red: 16/255, green: 140/255, blue: 74/255),
        dark: Color(red: 52/255, green: 199/255, blue: 89/255)
    )
    public static let warning = Color(
        light: Color(red: 217/255, green: 119/255, blue: 6/255),
        dark: Color(red: 251/255, green: 191/255, blue: 36/255)
    )
    public static let error = Color(
        light: Color(red: 220/255, green: 38/255, blue: 38/255),
        dark: Color(red: 248/255, green: 113/255, blue: 113/255)
    )
}

public extension Color {
    init(light: Color, dark: Color) {
        #if os(iOS)
        self.init(uiColor: UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
        #else
        self = light
        #endif
    }
}
