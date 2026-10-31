import SwiftUI

public struct DifferenceCalculatorView: View {
    @State private var viewModel = DifferenceCalculatorViewModel()
    @FocusState private var isInputFocused: Bool
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.large) {
                
                // Mode Selector
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    AppSegmentedPicker(
                        items: DifferenceCalculatorMode.allCases,
                        selection: $viewModel.mode
                    ) { mode in
                        switch mode {
                        case .taxDifference:
                            return LanguageManager.shared.string(.modeTaxDifference)
                        case .originalAmount:
                            return LanguageManager.shared.string(.modeOriginalAmount)
                        }
                    }
                }
                
                // Primary Amount Input
                AppTextField(
                    label: viewModel.mode == .taxDifference ?
                        LanguageManager.shared.string(.enter5PercentAmount) :
                        LanguageManager.shared.string(.enterOriginalAmount),
                    placeholder: "0.000",
                    text: $viewModel.inputAmountText,
                    suffix: "OMR",
                    errorMessage: viewModel.isInputAmountValid ? nil : LanguageManager.shared.string(.invalidAmountError)
                )
                
                // Condition Selector (Duty + VAT vs VAT Only)
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(LanguageManager.shared.string(.condition))
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                    
                    AppSegmentedPicker(
                        items: CustomsCondition.allCases,
                        selection: $viewModel.selectedCondition
                    ) { condition in
                        switch condition {
                        case .dutyAndVat:
                            return LanguageManager.shared.string(.conditionDutyAndVat)
                        case .vatOnly:
                            return LanguageManager.shared.string(.conditionVatOnly)
                        }
                    }
                    
                    // Fixed adjustment informative note
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                        Text(LanguageManager.shared.string(.temporaryAdjustmentNotice))
                            .font(AppTypography.caption2)
                    }
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.top, 2)
                }
                
                // Currency Conversion Section
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    AppSectionHeader(title: LanguageManager.shared.string(.currencyConversion))
                    
                    AppCard {
                        VStack(spacing: AppSpacing.medium) {
                            // Target Currency Selector
                            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                                Text(LanguageManager.shared.string(.selectTargetCurrency))
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondary)
                                
                                AppSegmentedPicker(
                                    items: Currency.allCases,
                                    selection: $viewModel.targetCurrency
                                ) { currency in
                                    currency.code
                                }
                            }
                            
                            // Exchange Rate Input (Shown when non-OMR)
                            if viewModel.targetCurrency != .omr {
                                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                                    AppTextField(
                                        label: LanguageManager.shared.string(.enterCustomsExchangeRate),
                                        placeholder: "e.g. 2.6008",
                                        text: $viewModel.exchangeRateText,
                                        suffix: LanguageManager.shared.string(.rateLabel),
                                        errorMessage: viewModel.isExchangeRateValid ? nil : LanguageManager.shared.string(.invalidExchangeRateError)
                                    )
                                    
                                    // Rate Convention Selector (Pending Verification)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(LanguageManager.shared.string(.conventionPendingNotice))
                                            .font(AppTypography.caption2)
                                            .foregroundColor(AppColors.warning)
                                        
                                        AppSegmentedPicker(
                                            items: ExchangeRateConvention.allCases,
                                            selection: $viewModel.rateConvention
                                        ) { convention in
                                            switch convention {
                                            case .multiply:
                                                return LanguageManager.shared.string(.conventionMultiply)
                                            case .divide:
                                                return LanguageManager.shared.string(.conventionDivide)
                                            }
                                        }
                                    }
                                    .padding(.top, AppSpacing.xxSmall)
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                }
                
                // Calculation Summary Card
                if let result = viewModel.calculationResult {
                    calculationSummaryCard(result: result)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
                
                Spacer(minLength: AppSpacing.xxLarge)
            }
            .padding(AppSpacing.medium)
        }
        .background(AppColors.groupedBackground.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnBackgroundTap()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(LanguageManager.shared.string(.toolDifferenceCalculator))
                    .font(AppTypography.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(LanguageManager.shared.string(.reset)) {
                    viewModel.reset()
                }
                .font(AppTypography.subheadline)
                .disabled(viewModel.inputAmountText.isEmpty)
            }
        }
    }
    
    // MARK: - Summary Card
    
    private func calculationSummaryCard(result: DifferenceCalculationResult) -> some View {
        let conditionName = (result.condition == .dutyAndVat) ?
            LanguageManager.shared.string(.conditionDutyAndVat) :
            LanguageManager.shared.string(.conditionVatOnly)
        
        var rows: [ResultRowData] = []
        
        if result.mode == .taxDifference {
            rows.append(ResultRowData(
                label: LanguageManager.shared.string(.enteredTaxDifference),
                value: result.enteredAmount.formattedOMR()
            ))
            rows.append(ResultRowData(
                label: LanguageManager.shared.string(.calculated5PercentOriginal),
                value: result.calculatedOriginalAmount.formattedOMR()
            ))
        } else {
            rows.append(ResultRowData(
                label: LanguageManager.shared.string(.enterOriginalAmount),
                value: result.enteredAmount.formattedOMR()
            ))
        }
        
        rows.append(ResultRowData(
            label: "\(LanguageManager.shared.string(.condition)) (\(conditionName))",
            value: "-\(result.adjustmentAmount.formattedOMR())"
        ))
        
        rows.append(ResultRowData(
            label: LanguageManager.shared.string(.adjustedOMRValue),
            value: result.adjustedOMRAmount.formattedOMR(),
            isEmphasized: result.targetCurrencyCode == "OMR"
        ))
        
        if result.targetCurrencyCode != "OMR" {
            let convText = result.rateConvention == .multiply ? "×" : "÷"
            rows.append(ResultRowData(
                label: "\(LanguageManager.shared.string(.exchangeRate)) (\(convText))",
                value: "\(result.exchangeRate)"
            ))
        }
        
        let fractionDigits = result.targetCurrencyCode == "OMR" ? 3 : 2
        let formattedFinal = result.finalDeclarationValue.formattedCurrency(
            code: result.targetCurrencyCode,
            fractionDigits: fractionDigits
        )
        
        return AppResultCard(
            title: LanguageManager.shared.string(.calculationSummary),
            primaryValue: formattedFinal,
            rows: rows,
            onCopy: {
                viewModel.copyFinalResult()
            },
            onReset: {
                viewModel.reset()
            }
        )
    }
}
