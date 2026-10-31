import SwiftUI

/// Premium, high-contrast tool card for the Home Grid and Tools List.
public struct ToolGridCard: View {
    let icon: String
    let title: String
    let description: String
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    public init(
        icon: String,
        title: String,
        description: String,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.action = action
    }
    
    public var body: some View {
        Button(action: {
            HapticFeedback.selection()
            action()
        }) {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                HStack(alignment: .top) {
                    // Icon Badge
                    ZStack {
                        RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                            .fill(AppColors.brandPrimary.opacity(colorScheme == .dark ? 0.25 : 0.12))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(AppColors.brandPrimary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                        .flipsForRightToLeftLayoutDirection(true)
                }
                
                VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                    Text(title)
                        .font(AppTypography.headline)
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.leading)
                    
                    Text(description)
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(AppSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .stroke(AppColors.subtleBorder, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
