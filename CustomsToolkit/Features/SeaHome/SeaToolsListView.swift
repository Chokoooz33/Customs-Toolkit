import SwiftUI

public struct SeaToolsListView: View {
    @State private var navigateToHSSearch = false
    @State private var navigateToDutyCalculator = false
    @State private var navigateToUnitConverter = false

    public init() {}

    private var isShowingDetailScreen: Bool {
        navigateToHSSearch || navigateToDutyCalculator || navigateToUnitConverter
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.medium) {
                    ToolGridCard(
                        icon: "magnifyingglass",
                        title: LanguageManager.shared.string(.toolHSCodeSearch),
                        description: LanguageManager.shared.string(.seaHSCardDesc)
                    ) { navigateToHSSearch = true }

                    ToolGridCard(
                        icon: "percent",
                        title: LanguageManager.shared.string(.toolDutyCalculator),
                        description: LanguageManager.shared.string(.toolDutyCalculatorDesc)
                    ) { navigateToDutyCalculator = true }

                    ToolGridCard(
                        icon: "scalemass.fill",
                        title: LanguageManager.shared.string(.toolUnitConverter),
                        description: LanguageManager.shared.string(.toolUnitConverterDesc)
                    ) { navigateToUnitConverter = true }

                    Spacer(minLength: AppSpacing.xxLarge)
                }
                .padding(AppSpacing.medium)
            }
            .background(AppColors.groupedBackground.ignoresSafeArea())
            .navigationTitle(LanguageManager.shared.string(.serviceSeaTitle))
            .navigationDestination(isPresented: $navigateToHSSearch) { HSCodeSearchView() }
            .navigationDestination(isPresented: $navigateToDutyCalculator) { DutyCalculatorView() }
            .navigationDestination(isPresented: $navigateToUnitConverter) { UnitConverterView() }
        }
        .onChange(of: isShowingDetailScreen) { _, active in
            AppState.shared.isTabBarHidden = active
        }
        .onAppear { AppState.shared.isTabBarHidden = isShowingDetailScreen }
    }
}
