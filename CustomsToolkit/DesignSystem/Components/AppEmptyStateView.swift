import SwiftUI

public struct AppEmptyStateView: View {
    let icon: String
    let title: String
    let description: String
    let buttonTitle: String?
    let action: (() -> Void)?
    
    public init(
        icon: String,
        title: String,
        description: String,
        buttonTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.buttonTitle = buttonTitle
        self.action = action
    }
    
    public var body: some View {
        VStack(spacing: AppSpacing.medium) {
            ZStack {
                Circle()
                    .fill(AppColors.brandPrimary.opacity(0.1))
                    .frame(width: 72, height: 72)
                
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(AppColors.brandPrimary)
            }
            .padding(.bottom, AppSpacing.xxSmall)
            
            VStack(spacing: AppSpacing.xSmall) {
                Text(title)
                    .font(AppTypography.headline)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text(description)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.large)
            }
            
            if let buttonTitle = buttonTitle, let action = action {
                Button(action: {
                    HapticFeedback.impact(style: .medium)
                    action()
                }) {
                    Text(buttonTitle)
                        .font(AppTypography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.brandPrimary)
                        .padding(.horizontal, AppSpacing.medium)
                        .padding(.vertical, 8)
                        .background(AppColors.brandPrimary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                }
                .padding(.top, AppSpacing.xSmall)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xxLarge)
    }
}
