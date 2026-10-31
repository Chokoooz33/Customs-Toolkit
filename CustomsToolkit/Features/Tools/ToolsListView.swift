import SwiftUI

public struct ToolsListView: View {
    @State private var navigateToUnitConverter = false
    @State private var navigateToHSSearch = false
    @State private var navigateToDifferenceCalc = false
    @State private var navigateToDutyCalculator = false
    @State private var navigateToGoldPrice = false
    @State private var navigateToAirCargoTracking = false
    @State private var navigateToCargoBoard = false
    
    public init() {}

    private var isShowingDetailScreen: Bool {
        navigateToUnitConverter || navigateToHSSearch || navigateToDifferenceCalc || navigateToDutyCalculator || navigateToGoldPrice || navigateToAirCargoTracking || navigateToCargoBoard
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.medium) {
                    ToolGridCard(
                        icon: "airplane",
                        title: LanguageManager.shared.string(.toolAirCargoTracking),
                        description: LanguageManager.shared.string(.toolAirCargoTrackingDesc)
                    ) {
                        navigateToAirCargoTracking = true
                    }

                    ToolGridCard(
                        icon: "shippingbox.and.arrow.backward.fill",
                        title: LanguageManager.shared.string(.toolCargoBoard),
                        description: LanguageManager.shared.string(.toolCargoBoardDesc)
                    ) {
                        navigateToCargoBoard = true
                    }

                    ToolGridCard(
                        icon: "scalemass.fill",
                        title: LanguageManager.shared.string(.toolUnitConverter),
                        description: LanguageManager.shared.string(.toolUnitConverterDesc)
                    ) {
                        navigateToUnitConverter = true
                    }
                    
                    ToolGridCard(
                        icon: "magnifyingglass",
                        title: LanguageManager.shared.string(.toolHSCodeSearch),
                        description: LanguageManager.shared.string(.toolHSCodeSearchDesc)
                    ) {
                        navigateToHSSearch = true
                    }
                    
                    ToolGridCard(
                        icon: "percent",
                        title: LanguageManager.shared.string(.toolDifferenceCalculator),
                        description: LanguageManager.shared.string(.toolDifferenceCalculatorDesc)
                    ) {
                        navigateToDifferenceCalc = true
                    }

                    ToolGridCard(
                        icon: "banknote.fill",
                        title: LanguageManager.shared.string(.toolDutyCalculator),
                        description: LanguageManager.shared.string(.toolDutyCalculatorDesc)
                    ) {
                        navigateToDutyCalculator = true
                    }
                    
                    ToolGridCard(
                        icon: "chart.line.uptrend.xyaxis",
                        title: LanguageManager.shared.string(.toolGoldPrice),
                        description: LanguageManager.shared.string(.toolGoldPriceDesc)
                    ) {
                        navigateToGoldPrice = true
                    }
                    
                    Spacer(minLength: AppSpacing.xxLarge)
                }
                .padding(AppSpacing.medium)
            }
            .background(AppColors.groupedBackground.ignoresSafeArea())
            .navigationTitle(LanguageManager.shared.string(.tabTools))
            .navigationDestination(isPresented: $navigateToUnitConverter) {
                UnitConverterView()
            }
            .navigationDestination(isPresented: $navigateToHSSearch) {
                HSCodeSearchView()
            }
            .navigationDestination(isPresented: $navigateToDifferenceCalc) {
                DifferenceCalculatorView()
            }
            .navigationDestination(isPresented: $navigateToDutyCalculator) {
                DutyCalculatorView()
            }
            .navigationDestination(isPresented: $navigateToGoldPrice) {
                GoldPriceWebView()
            }
            .navigationDestination(isPresented: $navigateToAirCargoTracking) {
                AirCargoTrackingView()
            }
            .navigationDestination(isPresented: $navigateToCargoBoard) {
                CargoBoardView()
            }
        }
        .onChange(of: isShowingDetailScreen) { _, isActive in
            AppState.shared.isTabBarHidden = isActive
        }
        .onAppear {
            AppState.shared.isTabBarHidden = isShowingDetailScreen
        }
    }
}
