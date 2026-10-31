import SwiftUI

/// Reusable card container with subtle borders and adaptive Light/Dark surfaces.
public struct AppCard<Content: View>: View {
    private let content: Content
    private let padding: CGFloat
    private let cornerRadius: CGFloat
    private let backgroundColor: Color
    
    public init(
        padding: CGFloat = AppSpacing.medium,
        cornerRadius: CGFloat = AppRadius.card,
        backgroundColor: Color = AppColors.cardBackground,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.backgroundColor = backgroundColor
    }
    
    public var body: some View {
        content
            .padding(padding)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppColors.subtleBorder, lineWidth: 1)
            )
    }
}
