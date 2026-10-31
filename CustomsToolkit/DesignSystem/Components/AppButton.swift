import SwiftUI

public enum AppButtonStyle {
    case primary
    case secondary
    case destructive
    case outline
}

public struct AppButton: View {
    let title: String
    let icon: String?
    let style: AppButtonStyle
    let isLoading: Bool
    let action: () -> Void
    
    public init(
        _ title: String,
        icon: String? = nil,
        style: AppButtonStyle = .primary,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.isLoading = isLoading
        self.action = action
    }
    
    public var body: some View {
        Button(action: {
            HapticFeedback.impact(style: .medium)
            action()
        }) {
            HStack(spacing: AppSpacing.xSmall) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: foregroundColor))
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(title)
                        .font(AppTypography.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .stroke(borderColor, lineWidth: style == .outline ? 1.5 : 0)
            )
        }
        .disabled(isLoading)
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return AppColors.brandPrimary
        case .secondary:
            return AppColors.innerCardBackground
        case .destructive:
            return AppColors.error
        case .outline:
            return .clear
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary, .destructive:
            return .white
        case .secondary:
            return AppColors.textPrimary
        case .outline:
            return AppColors.brandPrimary
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .outline:
            return AppColors.brandPrimary
        default:
            return .clear
        }
    }
}
