import SwiftUI

public struct SavedView: View {
    @State private var navigateToHSSearch = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.large) {
                    
                    AppEmptyStateView(
                        icon: "bookmark.circle",
                        title: LanguageManager.shared.string(.savedEmptyTitle),
                        description: LanguageManager.shared.string(.savedEmptyDesc)
                    )
                    
                    AppCard {
                        HStack(spacing: AppSpacing.medium) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 20))
                                .foregroundColor(AppColors.brandPrimary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(LanguageManager.shared.string(.futureFavoritesComingSoon))
                                    .font(AppTypography.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Text(LanguageManager.shared.string(.comingSoon))
                                    .font(AppTypography.caption2)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            
                            Spacer()
                        }
                    }
                    
                    Spacer(minLength: AppSpacing.xxLarge)
                }
                .padding(AppSpacing.medium)
            }
            .background(AppColors.groupedBackground.ignoresSafeArea())
            .navigationTitle(LanguageManager.shared.string(.tabSaved))
        }
    }
}
