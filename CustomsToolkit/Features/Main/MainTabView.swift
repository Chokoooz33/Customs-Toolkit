import SwiftUI

public struct MainTabView: View {
    @State private var selectedTab: Int = 0
    @State private var appState = AppState.shared

    public init() {}

    public var body: some View {
        Group {
            if let serviceArea = appState.selectedServiceArea {
                ZStack {
                    // IMPORTANT: do not use SwiftUI TabView here.
                    // Customs Toolkit owns its bottom navigation completely.
                    if serviceArea == .air {
                        rootTab(HomeView(), index: 0)
                        rootTab(ToolsListView(), index: 1)
                    } else {
                        rootTab(SeaHomeView(), index: 0)
                        rootTab(SeaToolsListView(), index: 1)
                    }
                    rootTab(SavedView(), index: 2)
                    rootTab(SettingsView(), index: 3)
                }
                .background(AppColors.groupedBackground.ignoresSafeArea())
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if !appState.isTabBarHidden {
                        CustomBottomTabBar(selectedTab: $selectedTab)
                            .padding(.horizontal, AppSpacing.medium)
                            .padding(.top, 2)
                            .padding(.bottom, -10)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.easeOut(duration: 0.16), value: appState.isTabBarHidden)
            } else {
                ServiceSelectionView { area in
                    withAnimation(.easeOut(duration: 0.22)) {
                        selectedTab = 0
                        appState.isTabBarHidden = false
                        appState.selectedServiceArea = area
                    }
                }
            }
        }
        .onChange(of: selectedTab) { _, _ in
            appState.isTabBarHidden = false
        }
        .onChange(of: appState.selectedServiceArea) { _, _ in
            selectedTab = 0
            appState.isTabBarHidden = false
        }
    }

    @ViewBuilder
    private func rootTab<Content: View>(_ content: Content, index: Int) -> some View {
        content
            .opacity(selectedTab == index ? 1 : 0)
            .allowsHitTesting(selectedTab == index)
            .accessibilityHidden(selectedTab != index)
            .zIndex(selectedTab == index ? 1 : 0)
    }
}

private struct CustomBottomTabBar: View {
    @Binding var selectedTab: Int

    private var items: [(icon: String, title: String)] {
        [
            ("house.fill", LanguageManager.shared.string(.tabHome)),
            ("square.grid.2x2.fill", LanguageManager.shared.string(.tabTools)),
            ("bookmark.fill", LanguageManager.shared.string(.tabSaved)),
            ("ellipsis.circle.fill", LanguageManager.shared.string(.tabMore))
        ]
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Button {
                    HapticFeedback.selection()
                    withAnimation(.easeOut(duration: 0.18)) {
                        selectedTab = index
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.icon)
                            .font(.system(size: 20, weight: .semibold))
                        Text(item.title)
                            .font(.system(size: 11, weight: selectedTab == index ? .bold : .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(selectedTab == index ? AppColors.brandGold : Color.white.opacity(0.86))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        Group {
                            if selectedTab == index {
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color.white.opacity(0.10))
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedTab == index ? .isSelected : [])
            }
        }
        .padding(6)
        .background(
            LinearGradient(
                colors: [AppColors.brandDeepNavy, AppColors.brandPrimary],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        )
        .shadow(color: AppColors.brandDeepNavy.opacity(0.18), radius: 12, x: 0, y: 5)
    }
}
