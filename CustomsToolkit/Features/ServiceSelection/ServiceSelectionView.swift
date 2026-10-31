import SwiftUI

public struct ServiceSelectionView: View {
    let onSelect: (ServiceArea) -> Void

    public init(onSelect: @escaping (ServiceArea) -> Void) {
        self.onSelect = onSelect
    }

    public var body: some View {
        ZStack {
            AppColors.groupedBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.large) {
                    hero
                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                        Text(LanguageManager.shared.string(.serviceChooseTitle))
                            .font(AppTypography.title2)
                            .foregroundStyle(AppColors.textPrimary)
                        Text(LanguageManager.shared.string(.serviceChooseDesc))
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    serviceCard(
                        area: .air,
                        title: LanguageManager.shared.string(.serviceAirTitle),
                        subtitle: LanguageManager.shared.string(.serviceAirDesc),
                        secondaryIcon: "shippingbox.and.arrow.backward.fill"
                    )

                    serviceCard(
                        area: .sea,
                        title: LanguageManager.shared.string(.serviceSeaTitle),
                        subtitle: LanguageManager.shared.string(.serviceSeaDesc),
                        secondaryIcon: "shippingbox.fill"
                    )
                }
                .padding(AppSpacing.medium)
                .padding(.top, AppSpacing.medium)
            }
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomTrailing) {
            LinearGradient(
                colors: [AppColors.brandDeepNavy, AppColors.brandPrimary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack(spacing: 18) {
                Image(systemName: "airplane")
                Image(systemName: "ferry.fill")
            }
            .font(.system(size: 42, weight: .bold))
            .foregroundStyle(.white.opacity(0.05))
            .padding(18)

            HStack(spacing: 14) {
                Image("BrandMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(LanguageManager.shared.string(.appName))
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("CUSTOMS TOOLKIT")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(AppColors.brandGold)
                        .preserveTechnicalLTR()
                }
                Spacer()
            }
            .padding(AppSpacing.large)
        }
        .frame(height: 136)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: AppColors.brandDeepNavy.opacity(0.18), radius: 14, x: 0, y: 6)
    }

    private func serviceCard(
        area: ServiceArea,
        title: String,
        subtitle: String,
        secondaryIcon: String
    ) -> some View {
        Button {
            HapticFeedback.selection()
            onSelect(area)
        } label: {
            AppCard(padding: AppSpacing.large, cornerRadius: 24) {
                HStack(spacing: AppSpacing.medium) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [AppColors.brandPrimary, AppColors.brandDeepNavy],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 72, height: 72)
                        Image(systemName: area.icon)
                            .font(.system(size: 31, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(AppTypography.title2)
                            .foregroundStyle(AppColors.textPrimary)
                        Text(subtitle)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 6) {
                            Image(systemName: secondaryIcon)
                            Text(area == .air
                                 ? LanguageManager.shared.string(.serviceAirBadge)
                                 : LanguageManager.shared.string(.serviceSeaBadge))
                        }
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.brandGold)
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
