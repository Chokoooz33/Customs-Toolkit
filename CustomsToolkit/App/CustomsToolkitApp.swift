import SwiftUI

@main
struct CustomsToolkitApp: App {
    @State private var languageManager = LanguageManager.shared
    @State private var storage = StorageService.shared
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.layoutDirection, languageManager.layoutDirection)
                .environment(\.locale, languageManager.locale)
                .preferredColorScheme(storage.appearanceMode.colorScheme)
                .id(languageManager.currentLanguage.rawValue)
        }
    }
}
