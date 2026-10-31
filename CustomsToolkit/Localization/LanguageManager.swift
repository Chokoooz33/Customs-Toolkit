import SwiftUI
import Combine

public enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case arabic = "ar"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .english: return "English"
        case .arabic: return "العربية"
        }
    }
    
    public var layoutDirection: LayoutDirection {
        switch self {
        case .english: return .leftToRight
        case .arabic: return .rightToLeft
        }
    }
    
    public var locale: Locale {
        switch self {
        case .english: return Locale(identifier: "en_US")
        case .arabic: return Locale(identifier: "ar_OM")
        }
    }
    
    public var isRTL: Bool {
        return self == .arabic
    }
}

@Observable
public final class LanguageManager {
    
    public static let shared = LanguageManager()
    
    private let storageKey = "customs_toolkit_selected_language"
    
    public var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: storageKey)
            updateBundle()
        }
    }
    
    public var layoutDirection: LayoutDirection {
        currentLanguage.layoutDirection
    }
    
    public var locale: Locale {
        currentLanguage.locale
    }
    
    public var isRTL: Bool {
        currentLanguage.isRTL
    }
    
    private var bundle: Bundle = .main
    
    public init() {
        if let savedRaw = UserDefaults.standard.string(forKey: storageKey),
           let saved = AppLanguage(rawValue: savedRaw) {
            self.currentLanguage = saved
        } else {
            // Default based on device language if Arabic, otherwise English
            let preferred = Locale.preferredLanguages.first ?? "en"
            if preferred.starts(with: "ar") {
                self.currentLanguage = .arabic
            } else {
                self.currentLanguage = .english
            }
        }
        updateBundle()
    }
    
    private func updateBundle() {
        if let path = Bundle.main.path(forResource: currentLanguage.rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            self.bundle = bundle
        } else {
            self.bundle = .main
        }
    }
    
    public func string(_ key: LocalizedKey) -> String {
        return string(key.rawValue)
    }
    
    public func string(_ key: String) -> String {
        return bundle.localizedString(forKey: key, value: nil, table: "Localizable")
    }
    
    public func string(_ key: LocalizedKey, _ arguments: CVarArg...) -> String {
        let format = string(key)
        return String(format: format, locale: currentLanguage.locale, arguments: arguments)
    }
}
