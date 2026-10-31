import SwiftUI

public struct HomeView: View {
    @State private var navigateToUnitConverter = false
    @State private var navigateToHSSearch = false
    @State private var navigateToDifferenceCalc = false
    @State private var navigateToDutyCalculator = false
    @State private var navigateToGoldPrice = false
    @State private var navigateToAirCargoTracking = false
    @State private var navigateToCargoBoard = false

    @State private var storageService = StorageService.shared
    @State private var goldPriceService = GoldPriceService.shared

    public init() {}

    private var isShowingDetailScreen: Bool {
        navigateToUnitConverter || navigateToHSSearch || navigateToDifferenceCalc || navigateToDutyCalculator || navigateToGoldPrice || navigateToAirCargoTracking || navigateToCargoBoard
    }

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.large) {
                    dashboardHero
                    goldPriceDashboardCard
                    quickToolsSection
                    recentActivitySection
                }
                .padding(.horizontal, AppSpacing.medium)
                .padding(.top, AppSpacing.xSmall)
                // Extra scroll clearance keeps the final dashboard cards fully visible
                // above the floating custom tab bar at the end of the scroll view.
                .padding(.bottom, 116)
            }
            .background(AppColors.groupedBackground.ignoresSafeArea())
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
            .task {
                await goldPriceService.refreshIfNeeded()
                await CargoBoardStore.shared.refreshAll()
            }
        }
        .onChange(of: isShowingDetailScreen) { _, isActive in
            AppState.shared.isTabBarHidden = isActive
        }
        .onAppear {
            AppState.shared.isTabBarHidden = isShowingDetailScreen
        }
    }

    // MARK: - Hero

    private var dashboardHero: some View {
        ZStack(alignment: .bottomTrailing) {
            LinearGradient(
                colors: [AppColors.brandDeepNavy, AppColors.brandPrimary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Very subtle logistics motif so the hero stays brand-first, not content-heavy.
            HStack(spacing: 14) {
                Image(systemName: "ferry.fill")
                Image(systemName: "airplane")
                Image(systemName: "shippingbox.fill")
            }
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(.white.opacity(0.045))
            .padding(.trailing, 16)
            .padding(.bottom, 14)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    CustomsBrandMark(size: 58)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(LanguageManager.shared.string(.appName))
                            .font(.system(size: 23, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.78)
                            .lineLimit(2)

                        Text("CUSTOMS TOOLKIT")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(1.35)
                            .foregroundStyle(AppColors.brandGold)
                            .preserveTechnicalLTR()
                    }

                    Spacer(minLength: 0)
                }

                Text(LanguageManager.shared.string(.appSubtitle))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                HStack(spacing: 6) {
                    DashboardBadge(icon: "mappin.and.ellipse", text: LanguageManager.shared.string(.dashboardOman))
                    DashboardBadge(icon: "doc.text.fill", text: LanguageManager.shared.string(.dashboardTariff2026))
                    DashboardBadge(icon: "wifi.slash", text: LanguageManager.shared.string(.dashboardOffline))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.09), lineWidth: 1)
        )
        .shadow(color: AppColors.brandDeepNavy.opacity(0.12), radius: 12, x: 0, y: 6)
    }

    // MARK: - Native gold price dashboard

    private var goldPriceDashboardCard: some View {
        AppCard(padding: 0, cornerRadius: 24) {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: AppSpacing.medium) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 7) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(AppColors.brandGold)
                            Text(LanguageManager.shared.string(.dashboardGoldOman))
                                .font(AppTypography.headline)
                                .foregroundStyle(AppColors.textPrimary)
                        }

                        if let snapshot = goldPriceService.snapshot {
                            Text(snapshot.price24.formattedOMR())
                                .font(.system(size: 31, weight: .bold, design: .rounded))
                                .foregroundStyle(AppColors.goldPriceValue)
                                .minimumScaleFactor(0.72)
                                .lineLimit(1)
                                .preserveTechnicalLTR()

                            Text("\(LanguageManager.shared.string(.dashboardGoldKarat24)) • \(LanguageManager.shared.string(.dashboardGoldPerGram))")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)

                            Text("\(LanguageManager.shared.string(.dashboardGoldLastUpdate)): \(goldFetchTime(snapshot.fetchedAt))")
                                .font(AppTypography.caption2)
                                .foregroundStyle(AppColors.textTertiary)
                        } else if goldPriceService.isLoading {
                            HStack(spacing: AppSpacing.small) {
                                ProgressView()
                                Text(LanguageManager.shared.string(.dashboardGoldLoading))
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                            .padding(.vertical, AppSpacing.small)
                        } else {
                            Text(LanguageManager.shared.string(.dashboardGoldUnavailable))
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 8)

                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [AppColors.brandGold.opacity(0.30), AppColors.brandGold.opacity(0.10)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 78, height: 78)

                        GoldBarsIcon()
                            .frame(width: 50, height: 43)
                    }
                }
                .padding(AppSpacing.medium)

                if let snapshot = goldPriceService.snapshot {
                    Divider()
                    HStack(spacing: 0) {
                        goldKaratMetric(22, price: snapshot.price22)
                        Divider().frame(height: 42)
                        goldKaratMetric(21, price: snapshot.price21)
                        Divider().frame(height: 42)
                        goldKaratMetric(18, price: snapshot.price18)
                    }
                    .padding(.vertical, AppSpacing.small)
                }

                Divider()

                HStack(spacing: AppSpacing.small) {
                    Button {
                        HapticFeedback.selection()
                        Task { await goldPriceService.refresh(force: true) }
                    } label: {
                        Label(
                            LanguageManager.shared.string(.dashboardGoldRefresh),
                            systemImage: "arrow.clockwise"
                        )
                        .font(AppTypography.caption)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppColors.brandPrimary)
                    .disabled(goldPriceService.isLoading)

                    Divider().frame(height: 24)

                    Button {
                        HapticFeedback.selection()
                        navigateToGoldPrice = true
                    } label: {
                        Label(
                            LanguageManager.shared.string(.dashboardGoldViewSource),
                            systemImage: "safari"
                        )
                        .font(AppTypography.caption)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppColors.brandPrimary)
                }
                .padding(.horizontal, AppSpacing.medium)
                .padding(.vertical, 12)

                Text(LanguageManager.shared.string(.dashboardGoldSource))
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.textTertiary)
                    .padding(.bottom, 10)
                    .preserveTechnicalLTR()
            }
        }
    }

    private func goldKaratMetric(_ karat: Int, price: Decimal) -> some View {
        VStack(spacing: 3) {
            Text("\(karat)K")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.brandGold)
                .preserveTechnicalLTR()
            Text(price.formattedOMR())
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
                .minimumScaleFactor(0.65)
                .lineLimit(1)
                .preserveTechnicalLTR()
        }
        .frame(maxWidth: .infinity)
    }

    private func goldFetchTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = LanguageManager.shared.currentLanguage.locale
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    // MARK: - Quick tools

    private var quickToolsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            sectionHeader(
                title: LanguageManager.shared.string(.dashboardQuickTools),
                icon: "square.grid.2x2.fill"
            )

            // HS search is intentionally the visual primary action.
            DashboardPrimaryToolCard(
                icon: "magnifyingglass",
                title: LanguageManager.shared.string(.toolHSCodeSearch),
                description: LanguageManager.shared.string(.toolHSCodeSearchDesc),
                badge: LanguageManager.shared.string(.dashboardPrimaryTool)
            ) {
                navigateToHSSearch = true
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: AppSpacing.medium),
                    GridItem(.flexible(), spacing: AppSpacing.medium)
                ],
                spacing: AppSpacing.medium
            ) {
                DashboardToolCard(
                    icon: "airplane",
                    title: LanguageManager.shared.string(.toolAirCargoTracking),
                    description: LanguageManager.shared.string(.toolAirCargoTrackingDesc),
                    accent: AppColors.brandPrimary
                ) {
                    navigateToAirCargoTracking = true
                }

                DashboardToolCard(
                    icon: "shippingbox.and.arrow.backward.fill",
                    title: LanguageManager.shared.string(.toolCargoBoard),
                    description: LanguageManager.shared.string(.toolCargoBoardDesc),
                    accent: AppColors.brandGold
                ) {
                    navigateToCargoBoard = true
                }

                DashboardToolCard(
                    icon: "scalemass.fill",
                    title: LanguageManager.shared.string(.toolUnitConverter),
                    description: LanguageManager.shared.string(.toolUnitConverterDesc),
                    accent: AppColors.brandPrimary
                ) {
                    navigateToUnitConverter = true
                }

                DashboardToolCard(
                    icon: "percent",
                    title: LanguageManager.shared.string(.toolDifferenceCalculator),
                    description: LanguageManager.shared.string(.toolDifferenceCalculatorDesc),
                    accent: AppColors.brandGold
                ) {
                    navigateToDifferenceCalc = true
                }

                DashboardToolCard(
                    icon: "banknote.fill",
                    title: LanguageManager.shared.string(.toolDutyCalculator),
                    description: LanguageManager.shared.string(.toolDutyCalculatorDesc),
                    accent: AppColors.brandPrimary
                ) {
                    navigateToDutyCalculator = true
                }

                DashboardToolCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: LanguageManager.shared.string(.toolGoldPrice),
                    description: LanguageManager.shared.string(.toolGoldPriceDesc),
                    accent: AppColors.brandGold
                ) {
                    navigateToGoldPrice = true
                }

                DashboardToolCard(
                    icon: "doc.text.magnifyingglass",
                    title: LanguageManager.shared.string(.dashboardTariff2026),
                    description: LanguageManager.shared.string(.dashboardTariffCardDesc),
                    accent: AppColors.brandPrimary
                ) {
                    navigateToHSSearch = true
                }
            }
        }
    }

    // MARK: - Recent activity

    @ViewBuilder
    private var recentActivitySection: some View {
        if !storageService.recentHSSearches.isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                sectionHeader(
                    title: LanguageManager.shared.string(.dashboardRecentActivity),
                    icon: "clock.arrow.circlepath"
                )

                AppCard(padding: 0, cornerRadius: 22) {
                    VStack(spacing: 0) {
                        ForEach(Array(storageService.recentHSSearches.prefix(4).enumerated()), id: \.element.id) { index, item in
                            Button {
                                HapticFeedback.selection()
                                navigateToHSSearch = true
                            } label: {
                                HStack(spacing: AppSpacing.small) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(AppColors.brandPrimary.opacity(0.09))
                                            .frame(width: 38, height: 38)
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(AppColors.brandPrimary)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(LanguageManager.shared.string(.dashboardHSSearchActivity))
                                            .font(AppTypography.caption)
                                            .foregroundStyle(AppColors.textSecondary)

                                        Text(item.query)
                                            .font(AppTypography.technicalNumberMedium)
                                            .foregroundStyle(AppColors.textPrimary)
                                            .lineLimit(1)
                                            .preserveTechnicalLTR()
                                    }

                                    Spacer()

                                    Text(relativeTime(item.timestamp))
                                        .font(AppTypography.caption2)
                                        .foregroundStyle(AppColors.textTertiary)

                                    Image(systemName: "chevron.forward")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(AppColors.textTertiary)
                                        .flipsForRightToLeftLayoutDirection(true)
                                }
                                .padding(.horizontal, AppSpacing.medium)
                                .padding(.vertical, AppSpacing.small)
                            }
                            .buttonStyle(.plain)

                            if index < min(storageService.recentHSSearches.count, 4) - 1 {
                                Divider().padding(.leading, 66)
                            }
                        }
                    }
                }
            }
        }
    }

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: AppSpacing.xSmall) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppColors.brandPrimary)
            Text(title)
                .font(AppTypography.title3)
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
        }
    }

    // MARK: - Helpers

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = LanguageManager.shared.currentLanguage.locale
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Dashboard components

private struct GoldBarsIcon: View {
    var body: some View {
        ZStack {
            GoldIngotShape()
                .fill(goldGradient)
                .frame(width: 31, height: 15)
                .offset(x: -14, y: 7)

            GoldIngotShape()
                .fill(goldGradient)
                .frame(width: 31, height: 15)
                .offset(x: 14, y: 7)

            GoldIngotShape()
                .fill(goldGradient)
                .frame(width: 34, height: 16)
                .offset(y: -8)
        }
        .shadow(color: AppColors.brandGold.opacity(0.22), radius: 3, x: 0, y: 2)
        .accessibilityHidden(true)
    }

    private var goldGradient: LinearGradient {
        LinearGradient(
            colors: [AppColors.brandGold.opacity(0.72), AppColors.brandGold],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct GoldIngotShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset = rect.width * 0.13
        path.move(to: CGPoint(x: inset, y: 0))
        path.addLine(to: CGPoint(x: rect.width - inset, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

private struct CustomsBrandMark: View {
    let size: CGFloat

    var body: some View {
        Image("BrandMark")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            .shadow(color: Color.black.opacity(0.16), radius: 8, x: 0, y: 4)
            .accessibilityHidden(true)
    }
}

private struct DashboardBadge: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(text)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(.white.opacity(0.88))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.white.opacity(0.09))
        .clipShape(Capsule())
    }
}

private struct DashboardPrimaryToolCard: View {
    let icon: String
    let title: String
    let description: String
    let badge: String
    let action: () -> Void

    var body: some View {
        Button {
            HapticFeedback.selection()
            action()
        } label: {
            HStack(spacing: AppSpacing.medium) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppColors.brandPrimary)
                        .frame(width: 62, height: 62)
                    Image(systemName: icon)
                        .font(.system(size: 27, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text(title)
                            .font(AppTypography.headline)
                            .foregroundStyle(AppColors.textPrimary)
                            .multilineTextAlignment(.leading)

                        Text(badge)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.brandDeepNavy)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(AppColors.brandGold.opacity(0.82))
                            .clipShape(Capsule())
                    }

                    Text(description)
                        .font(AppTypography.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.forward")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.brandPrimary)
                    .flipsForRightToLeftLayoutDirection(true)
            }
            .padding(AppSpacing.medium)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppColors.brandPrimary.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct DashboardToolCard: View {
    let icon: String
    let title: String
    let description: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button {
            HapticFeedback.selection()
            action()
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(accent.opacity(0.11))
                            .frame(width: 46, height: 46)
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(accent)
                    }
                    Spacer()
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.textTertiary)
                        .flipsForRightToLeftLayoutDirection(true)
                }

                Text(title)
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(description)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }
            .padding(AppSpacing.medium)
            .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppColors.subtleBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
