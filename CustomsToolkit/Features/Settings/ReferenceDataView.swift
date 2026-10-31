import SwiftUI

public struct ReferenceDataView: View {
    @State private var searchService = HSSearchService.shared
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.large) {
                
                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.medium) {
                        HStack {
                            Image(systemName: "doc.badge.gearshape")
                                .font(.system(size: 24))
                                .foregroundColor(AppColors.brandPrimary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(LanguageManager.shared.string(.officialTariffSource))
                                    .font(AppTypography.headline)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Text("Oman (\(AppConfig.tariffYear))")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            Spacer()
                        }
                        
                        Divider()
                        
                        // Status Row
                        HStack {
                            Text("Status:")
                                .font(AppTypography.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                            Spacer()
                            switch searchService.status {
                            case .notInstalled:
                                Text(LanguageManager.shared.string(.statusPendingDataset))
                                    .font(AppTypography.headline)
                                    .foregroundColor(AppColors.warning)
                            case .ready:
                                Text(LanguageManager.shared.string(.statusInstalled))
                                    .font(AppTypography.headline)
                                    .foregroundColor(AppColors.success)
                            }
                        }
                        
                        Divider()
                        
                        // Year Row
                        HStack {
                            Text("Year:")
                                .font(AppTypography.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                            Spacer()
                            Text("\(AppConfig.tariffYear)")
                                .font(AppTypography.headline)
                                .foregroundColor(AppColors.textPrimary)
                                .preserveTechnicalLTR()
                        }
                        
                        Divider()
                        
                        // Records Count Row
                        HStack {
                            Text("Indexed Records:")
                                .font(AppTypography.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                            Spacer()
                            switch searchService.status {
                            case .notInstalled:
                                Text("0 (Pending)")
                                    .font(AppTypography.subheadline)
                                    .foregroundColor(AppColors.textTertiary)
                            case .ready(_, let count):
                                Text("\(count)")
                                    .font(AppTypography.headline)
                                    .foregroundColor(AppColors.brandPrimary)
                                    .preserveTechnicalLTR()
                            }
                        }
                        
                        Divider()
                        
                        // Source Reference Identifier
                        VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                            Text("Source Reference:")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                            
                            Text(AppConfig.omanCustomsTariffSource)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textPrimary)
                        }
                        
                        Divider()
                        
                        Text(LanguageManager.shared.string(.referenceDataDesc))
                            .font(AppTypography.footnote)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                Spacer(minLength: AppSpacing.xxLarge)
            }
            .padding(AppSpacing.medium)
        }
        .background(AppColors.groupedBackground.ignoresSafeArea())
        .navigationTitle(LanguageManager.shared.string(.referenceData))
        .navigationBarTitleDisplayMode(.inline)
    }
}
