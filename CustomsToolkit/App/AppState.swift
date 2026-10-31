import SwiftUI

@Observable
public final class AppState {
    public static let shared = AppState()
    
    public var languageManager: LanguageManager
    public var storageService: StorageService
    public var searchService: HSSearchService

    /// The active operational department. Nil means the launch selector is being shown.
    public var selectedServiceArea: ServiceArea? = nil

    /// Controls the custom root tab bar. Detail/tool screens hide it so content and the keyboard
    /// can use the full bottom safe area, matching native iOS navigation behavior.
    public var isTabBarHidden: Bool = false
    
    public init(
        languageManager: LanguageManager = .shared,
        storageService: StorageService = .shared,
        searchService: HSSearchService = .shared
    ) {
        self.languageManager = languageManager
        self.storageService = storageService
        self.searchService = searchService
    }
}
