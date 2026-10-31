import SwiftUI

public struct SettingsView: View {
    @State private var storage = StorageService.shared
    @State private var languageManager = LanguageManager.shared
    @State private var appState = AppState.shared
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                // Active operational department
                Section(header: Text(LanguageManager.shared.string(.serviceCurrent))) {
                    HStack {
                        Image(systemName: appState.selectedServiceArea?.icon ?? "square.grid.2x2")
                            .foregroundStyle(AppColors.brandPrimary)
                        Text(appState.selectedServiceArea == .sea
                             ? LanguageManager.shared.string(.serviceSeaTitle)
                             : LanguageManager.shared.string(.serviceAirTitle))
                        Spacer()
                        Button(LanguageManager.shared.string(.serviceChange)) {
                            HapticFeedback.selection()
                            appState.isTabBarHidden = false
                            appState.selectedServiceArea = nil
                        }
                        .font(AppTypography.caption)
                    }
                }

                // Appearance Section
                Section(header: Text(LanguageManager.shared.string(.appearance))) {
                    Picker(LanguageManager.shared.string(.appearance), selection: $storage.appearanceMode) {
                        Text(LanguageManager.shared.string(.appearanceSystem)).tag(AppAppearance.system)
                        Text(LanguageManager.shared.string(.appearanceLight)).tag(AppAppearance.light)
                        Text(LanguageManager.shared.string(.appearanceDark)).tag(AppAppearance.dark)
                    }
                    .pickerStyle(.menu)
                }
                
                // Language Section
                Section(header: Text(LanguageManager.shared.string(.language))) {
                    Picker(LanguageManager.shared.string(.language), selection: $languageManager.currentLanguage) {
                        Text(LanguageManager.shared.string(.languageEnglish)).tag(AppLanguage.english)
                        Text(LanguageManager.shared.string(.languageArabic)).tag(AppLanguage.arabic)
                    }
                    .pickerStyle(.menu)
                }
                
                // Reference Data Section
                Section(header: Text(LanguageManager.shared.string(.referenceData))) {
                    NavigationLink(destination: ReferenceDataView()
                        .onAppear { AppState.shared.isTabBarHidden = true }
                        .onDisappear { AppState.shared.isTabBarHidden = false }) {
                        HStack {
                            Text(LanguageManager.shared.string(.officialTariffSource))
                                .font(AppTypography.body)
                            Spacer()
                            Text(LanguageManager.shared.string(.notInstalled))
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.warning)
                        }
                    }
                }
                
                // About Section
                Section(header: Text(LanguageManager.shared.string(.about))) {
                    HStack {
                        Text(LanguageManager.shared.string(.appName))
                            .font(AppTypography.body)
                        Spacer()
                        Text("v\(AppConfig.appVersion) (\(AppConfig.buildNumber))")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .preserveTechnicalLTR()
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundColor(.accentColor)
                        Text(LanguageManager.shared.string(.creatorCredit))
                            .font(AppTypography.body)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(LanguageManager.shared.string(.tabMore))
        }
    }
}
