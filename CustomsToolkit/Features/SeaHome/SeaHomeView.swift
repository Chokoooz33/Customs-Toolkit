import SwiftUI

public struct SeaHomeView: View {
    @State private var navigateToHSSearch = false
    @State private var navigateToDutyCalculator = false
    @State private var navigateToUnitConverter = false
    @State private var storageService = StorageService.shared

    public init() {}

    private var isShowingDetailScreen: Bool {
        navigateToHSSearch || navigateToDutyCalculator || navigateToUnitConverter
    }

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.large) {
                    seaHero
                    hsPrimaryCard
                    quickTools
                    recentActivity
                }
                .padding(.horizontal, AppSpacing.medium)
                .padding(.top, AppSpacing.xSmall)
                .padding(.bottom, 116)
            }
            .background(AppColors.groupedBackground.ignoresSafeArea())
            .navigationDestination(isPresented: $navigateToHSSearch) { HSCodeSearchView() }
            .navigationDestination(isPresented: $navigateToDutyCalculator) { DutyCalculatorView() }
            .navigationDestination(isPresented: $navigateToUnitConverter) { UnitConverterView() }
        }
        .onChange(of: isShowingDetailScreen) { _, active in
            AppState.shared.isTabBarHidden = active
        }
        .onAppear { AppState.shared.isTabBarHidden = isShowingDetailScreen }
    }

    private var seaHero: some View {
        ZStack(alignment: .bottomTrailing) {
            LinearGradient(
                colors: [AppColors.brandDeepNavy, AppColors.brandPrimary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack(spacing: 14) {
                Image(systemName: "ferry.fill")
                Image(systemName: "shippingbox.fill")
                Image(systemName: "doc.text.magnifyingglass")
            }
            .font(.system(size: 25, weight: .semibold))
            .foregroundStyle(.white.opacity(0.05))
            .padding(.trailing, 16)
            .padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image("BrandMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 58, height: 58)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LanguageManager.shared.string(.serviceSeaTitle))
                            .font(.system(size: 23, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("SEA SERVICES")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(1.35)
                            .foregroundStyle(AppColors.brandGold)
                            .preserveTechnicalLTR()
                    }
                    Spacer()
                }

                Text(LanguageManager.shared.string(.seaDashboardSubtitle))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))

                HStack(spacing: 6) {
                    seaBadge("arrow.down.to.line", LanguageManager.shared.string(.dutyImportOnly))
                    seaBadge("doc.text.fill", LanguageManager.shared.string(.dashboardTariff2026))
                    seaBadge("mappin.and.ellipse", LanguageManager.shared.string(.dashboardOman))
                }
            }
            .padding(AppSpacing.medium)
        }
        .frame(minHeight: 176)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: AppColors.brandDeepNavy.opacity(0.16), radius: 12, x: 0, y: 5)
    }

    private var hsPrimaryCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            HStack(spacing: 7) {
                Image(systemName: "sparkles")
                    .foregroundStyle(AppColors.brandGold)
                Text(LanguageManager.shared.string(.seaHSFocus))
                    .font(AppTypography.title3)
                Spacer()
            }

            Button {
                HapticFeedback.selection()
                navigateToHSSearch = true
            } label: {
                AppCard(padding: AppSpacing.medium, cornerRadius: 22) {
                    HStack(spacing: AppSpacing.medium) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(AppColors.brandPrimary)
                                .frame(width: 62, height: 62)
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 27, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 5) {
                            Text(LanguageManager.shared.string(.toolHSCodeSearch))
                                .font(AppTypography.headline)
                                .foregroundStyle(AppColors.textPrimary)
                            Text(LanguageManager.shared.string(.seaHSCardDesc))
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Image(systemName: "chevron.forward")
                            .foregroundStyle(AppColors.textTertiary)
                            .flipsForRightToLeftLayoutDirection(true)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var quickTools: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack(spacing: 7) {
                Image(systemName: "square.grid.2x2.fill")
                    .foregroundStyle(AppColors.brandPrimary)
                Text(LanguageManager.shared.string(.dashboardQuickTools))
                    .font(AppTypography.title3)
                Spacer()
            }

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: AppSpacing.medium), GridItem(.flexible(), spacing: AppSpacing.medium)],
                spacing: AppSpacing.medium
            ) {
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
            }
        }
    }

    @ViewBuilder
    private var recentActivity: some View {
        if !storageService.recentHSSearches.isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Text(LanguageManager.shared.string(.dashboardRecentActivity))
                    .font(AppTypography.title3)
                AppCard(padding: 0, cornerRadius: 20) {
                    VStack(spacing: 0) {
                        ForEach(Array(storageService.recentHSSearches.prefix(3).enumerated()), id: \.element.id) { index, item in
                            Button { navigateToHSSearch = true } label: {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundStyle(AppColors.brandPrimary)
                                    Text(item.query)
                                        .font(AppTypography.technicalNumberMedium)
                                        .foregroundStyle(AppColors.textPrimary)
                                        .lineLimit(1)
                                        .preserveTechnicalLTR()
                                    Spacer()
                                    Image(systemName: "chevron.forward")
                                        .foregroundStyle(AppColors.textTertiary)
                                        .flipsForRightToLeftLayoutDirection(true)
                                }
                                .padding(AppSpacing.medium)
                            }
                            .buttonStyle(.plain)
                            if index < min(storageService.recentHSSearches.count, 3) - 1 { Divider() }
                        }
                    }
                }
            }
        }
    }

    private func seaBadge(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 9, weight: .semibold))
            Text(text).font(.system(size: 9, weight: .semibold, design: .rounded)).lineLimit(1)
        }
        .foregroundStyle(.white.opacity(0.88))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.white.opacity(0.09))
        .clipShape(Capsule())
    }
}
