import SwiftUI

public struct UnitConverterView: View {
    @State private var viewModel = UnitConverterViewModel()
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.large) {

                AppCard(padding: AppSpacing.small, backgroundColor: AppColors.innerCardBackground) {
                    HStack(spacing: AppSpacing.small) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.brandPrimary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(LanguageManager.shared.string(.conversionRule))
                                .font(AppTypography.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textSecondary)

                            Text(LanguageManager.shared.string(.conversionRuleDesc))
                                .font(AppTypography.caption2)
                                .foregroundColor(AppColors.textTertiary)
                        }

                        Spacer()
                    }
                }

                // Conversion family selector. A menu scales better than a 5-item segmented control on iPhone.
                VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                    Text(LanguageManager.shared.string(.conversionType))
                        .font(AppTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textSecondary)

                    Menu {
                        ForEach(UnitConversionPair.allCases) { pair in
                            Button {
                                HapticFeedback.selection()
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    viewModel.selectedPair = pair
                                }
                            } label: {
                                if pair == viewModel.selectedPair {
                                    Label(pairTitle(pair), systemImage: "checkmark")
                                } else {
                                    Text(pairTitle(pair))
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: pairIcon(viewModel.selectedPair))
                                .foregroundColor(AppColors.brandPrimary)
                            Text(pairTitle(viewModel.selectedPair))
                                .font(AppTypography.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppColors.textTertiary)
                        }
                        .padding(.horizontal, AppSpacing.small)
                        .frame(minHeight: 48)
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                                .stroke(AppColors.subtleBorder, lineWidth: 0.5)
                        )
                    }
                }

                // Direction switcher
                HStack {
                    Text(unitDisplayName(for: viewModel.direction, source: true))
                        .font(AppTypography.headline)
                        .foregroundColor(AppColors.brandPrimary)

                    Spacer()

                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.swapDirection()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 14, weight: .bold))
                            Text(LanguageManager.shared.string(.swap))
                                .font(AppTypography.footnote)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, AppSpacing.small)
                        .padding(.vertical, 8)
                        .background(AppColors.brandPrimary.opacity(0.12))
                        .foregroundColor(AppColors.brandPrimary)
                        .clipShape(Capsule())
                    }
                }

                AppTextField(
                    label: LanguageManager.shared.string(.enterValue) + " (\(unitDisplayName(for: viewModel.direction, source: true)))",
                    placeholder: "0.00",
                    text: $viewModel.inputValue,
                    suffix: viewModel.direction.sourceUnit,
                    errorMessage: viewModel.isValid ? nil : LanguageManager.shared.string(.invalidAmountError)
                )

                if viewModel.direction.requiresDensity {
                    VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                        AppTextField(
                            label: LanguageManager.shared.string(.density),
                            placeholder: "1.0",
                            text: $viewModel.densityInput,
                            suffix: "g/mL",
                            errorMessage: viewModel.isDensityValid ? nil : LanguageManager.shared.string(.densityRequiredError)
                        )

                        Text(LanguageManager.shared.string(.densityHint))
                            .font(AppTypography.caption2)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if let _ = viewModel.resultDecimal, !viewModel.formattedResult.isEmpty {
                    AppResultCard(
                        title: LanguageManager.shared.string(.convertedResult),
                        primaryValue: viewModel.formattedResult,
                        rows: [
                            ResultRowData(
                                label: unitDisplayName(for: viewModel.direction, source: true),
                                value: "\(viewModel.inputValue) \(viewModel.direction.sourceUnit)"
                            ),
                            ResultRowData(
                                label: unitDisplayName(for: viewModel.direction, source: false),
                                value: viewModel.formattedResult,
                                isEmphasized: true
                            )
                        ],
                        onCopy: { viewModel.copyResult() },
                        onReset: { viewModel.reset() }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }

                Spacer(minLength: AppSpacing.xxLarge)
            }
            .padding(AppSpacing.medium)
        }
        .background(AppColors.groupedBackground.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnBackgroundTap()
        .navigationTitle(LanguageManager.shared.string(.toolUnitConverter))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(LanguageManager.shared.string(.reset)) {
                    viewModel.reset()
                }
                .font(AppTypography.subheadline)
                .disabled(viewModel.inputValue.isEmpty && viewModel.densityInput.isEmpty)
            }
        }
    }

    private func pairTitle(_ pair: UnitConversionPair) -> String {
        let key: LocalizedKey
        switch pair {
        case .caratGram: key = .pairCaratGram
        case .gramKilogram: key = .pairGramKilogram
        case .squareFootSquareMeter: key = .pairSquareFootSquareMeter
        case .poundKilogram: key = .pairPoundKilogram
        case .gramLiter: key = .pairGramLiter
        }
        return LanguageManager.shared.string(key)
    }

    private func pairIcon(_ pair: UnitConversionPair) -> String {
        switch pair {
        case .caratGram: return "diamond"
        case .gramKilogram: return "scalemass"
        case .squareFootSquareMeter: return "square.dashed"
        case .poundKilogram: return "shippingbox"
        case .gramLiter: return "drop"
        }
    }

    private func unitDisplayName(for direction: UnitConversionDirection, source: Bool) -> String {
        let dir = source ? direction : direction.swapped
        let key: LocalizedKey
        switch dir.sourceUnit {
        case "ct": key = .carats
        case "g": key = .grams
        case "kg": key = .kilograms
        case "ft²": key = .squareFeet
        case "m²": key = .squareMeters
        case "lb": key = .pounds
        case "L": key = .liters
        default: return dir.sourceUnit
        }
        return LanguageManager.shared.string(key)
    }
}
