import SwiftUI

public struct HSCodeSearchView: View {
    @State private var viewModel = HSCodeSearchViewModel()
    @FocusState private var isInputFocused: Bool
    @State private var isShowingCameraScanner = false
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.large) {
                
                // Search Input Card
                AppCard(padding: AppSpacing.small) {
                    HStack(spacing: AppSpacing.small) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.brandPrimary)
                        
                        TextField(
                            LanguageManager.shared.string(.hsSearchPlaceholder),
                            text: $viewModel.searchQuery
                        )
                        .font(AppTypography.body)
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($isInputFocused)
                        .onSubmit {
                            viewModel.commitSearchQuery()
                        }
                        
                        if !viewModel.searchQuery.isEmpty {
                            Button(action: {
                                HapticFeedback.selection()
                                viewModel.searchQuery = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(AppColors.textTertiary)
                            }
                        }

                        Button {
                            HapticFeedback.selection()
                            isInputFocused = false
                            isShowingCameraScanner = true
                        } label: {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(AppColors.brandPrimary)
                                .padding(6)
                                .background(AppColors.brandPrimary.opacity(0.09))
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(LanguageManager.shared.string(.hsCameraTitle))
                    }
                    .padding(.horizontal, AppSpacing.xSmall)
                    .padding(.vertical, 4)
                }
                
                // Live Normalization Preview
                if !viewModel.searchQuery.isEmpty {
                    let normalized = HSNormalizer.normalize(viewModel.searchQuery)
                    if !normalized.isEmpty {
                        let formatted = HSNormalizer.formatForDisplay(normalized)
                        
                        HStack {
                            Text(LanguageManager.shared.string(.normalizedLabel))
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                            Text(formatted)
                                .font(AppTypography.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.brandPrimary)
                                .preserveTechnicalLTR()
                            Spacer()
                        }
                        .padding(.horizontal, AppSpacing.small)
                    }
                }
                
                // Content Switcher based on search state & dataset status
                if viewModel.searchQuery.isEmpty {
                    // Recent Searches & Dataset Information
                    recentSearchesSection
                    
                    datasetStatusCard
                } else {
                    // Search Results
                    searchResultsSection
                }
                
                Spacer(minLength: AppSpacing.xxLarge)
            }
            .padding(AppSpacing.medium)
        }
        .background(AppColors.groupedBackground.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnBackgroundTap()
        .navigationTitle(LanguageManager.shared.string(.toolHSCodeSearch))
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $isShowingCameraScanner) {
            HSCodeCameraScannerView { code in
                viewModel.searchQuery = code
                viewModel.commitSearchQuery()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            if !viewModel.recentSearches.isEmpty {
                AppSectionHeader(
                    title: LanguageManager.shared.string(.recentSearches),
                    actionTitle: LanguageManager.shared.string(.clearHistory)
                ) {
                    viewModel.clearRecentSearches()
                }
                
                AppCard(padding: AppSpacing.xSmall) {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.recentSearches.enumerated()), id: \.element.id) { index, item in
                            Button(action: {
                                viewModel.selectRecentSearch(item)
                            }) {
                                HStack {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 14))
                                        .foregroundColor(AppColors.brandPrimary)
                                    
                                    Text(item.query)
                                        .font(AppTypography.body)
                                        .foregroundColor(AppColors.textPrimary)
                                        .preserveTechnicalLTR()
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.up.left")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppColors.textTertiary)
                                        .flipsForRightToLeftLayoutDirection(true)
                                }
                                .padding(.horizontal, AppSpacing.small)
                                .padding(.vertical, 10)
                            }
                            
                            if index < viewModel.recentSearches.count - 1 {
                                Divider()
                                    .padding(.leading, 32)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var datasetStatusCard: some View {
        VStack(spacing: AppSpacing.medium) {
            switch viewModel.datasetStatus {
            case .notInstalled:
                AppEmptyStateView(
                    icon: "doc.text.magnifyingglass",
                    title: LanguageManager.shared.string(.tariffNotInstalledTitle),
                    description: LanguageManager.shared.string(.tariffNotInstalledDesc)
                )
            case .ready(let metadata, let count):
                AppCard {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppColors.success)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(metadata.source) (\(metadata.year))")
                                .font(AppTypography.subheadline)
                                .fontWeight(.semibold)
                            Text(LanguageManager.shared.string(.recordsCount, count))
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        Spacer()
                    }
                }
            }
        }
    }
    
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            if viewModel.needsMoreInput {
                AppEmptyStateView(
                    icon: "text.cursor",
                    title: LanguageManager.shared.string(.searchMoreCharactersTitle),
                    description: LanguageManager.shared.string(.searchMoreCharactersDesc)
                )
            } else if viewModel.isSearching {
                HStack(spacing: AppSpacing.small) {
                    ProgressView()
                    Text(LanguageManager.shared.string(.searchingTariff))
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.xSmall)
            } else if viewModel.searchResults.isEmpty {
                AppEmptyStateView(
                    icon: "magnifyingglass",
                    title: LanguageManager.shared.string(.noResultsFound),
                    description: LanguageManager.shared.string(.partialSearchHint)
                )
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text(LanguageManager.shared.string(.hsResultsCount, viewModel.totalMatchCount))
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)

                    if viewModel.resultsAreTruncated {
                        Text(LanguageManager.shared.string(.showingTopResults, viewModel.searchResults.count))
                            .font(AppTypography.caption2)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                .padding(.horizontal, AppSpacing.xSmall)

                LazyVStack(spacing: AppSpacing.small) {
                    ForEach(viewModel.searchResults) { item in
                        NavigationLink(destination: HSCodeDetailView(item: item)) {
                            AppCard {
                                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                                    HStack(alignment: .center) {
                                        Text(item.formattedCode)
                                            .font(AppTypography.headline)
                                            .foregroundColor(AppColors.brandPrimary)
                                            .preserveTechnicalLTR()

                                        Spacer()

                                        if let duty = item.dutyRate, !duty.isEmpty {
                                            Text(duty)
                                                .font(AppTypography.caption)
                                                .fontWeight(.semibold)
                                                .foregroundColor(AppColors.brandPrimary)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(AppColors.brandPrimary.opacity(0.12))
                                                .clipShape(Capsule())
                                                .preserveTechnicalLTR()
                                        }

                                        statusBadge(item.status)
                                    }

                                    let primaryDesc = LanguageManager.shared.isRTL ?
                                        (item.descriptionArabic ?? item.descriptionEnglish ?? "") :
                                        (item.descriptionEnglish ?? item.descriptionArabic ?? "")
                                    let secondaryDesc = LanguageManager.shared.isRTL ?
                                        item.descriptionEnglish : item.descriptionArabic

                                    if !primaryDesc.isEmpty {
                                        Text(primaryDesc)
                                            .font(AppTypography.body)
                                            .foregroundColor(AppColors.textPrimary)
                                            .multilineTextAlignment(.leading)
                                            .lineLimit(2)
                                    }

                                    if let secondary = secondaryDesc, !secondary.isEmpty {
                                        Text(secondary)
                                            .font(AppTypography.caption)
                                            .foregroundColor(AppColors.textSecondary)
                                            .multilineTextAlignment(.leading)
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func statusBadge(_ status: TariffStatus) -> some View {
        switch status {
        case .restricted:
            HStack(spacing: 3) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9))
                Text(LanguageManager.shared.string(.statusRestricted))
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(AppColors.warning)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(AppColors.warning.opacity(0.12))
            .clipShape(Capsule())
        case .prohibited:
            HStack(spacing: 3) {
                Image(systemName: "nosign")
                    .font(.system(size: 9, weight: .bold))
                Text(LanguageManager.shared.string(.statusProhibited))
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(AppColors.error)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(AppColors.error.opacity(0.12))
            .clipShape(Capsule())
        case .normal, .unknown:
            EmptyView()
        }
    }
}
