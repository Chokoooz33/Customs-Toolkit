import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct DutyCalculatorView: View {
    @State private var viewModel: DutyCalculatorViewModel
    @FocusState private var focusedField: Field?
    @State private var sharePayload: DutySharePayload?
    @State private var copied = false

    private enum Field: Hashable {
        case cif, cfr, cost, freight
        case cifRate, cfrRate, costRate, freightRate
        case hs
    }

    public init(prefilledHSItem: HSCodeItem? = nil) {
        _viewModel = State(initialValue: DutyCalculatorViewModel(prefilledHSItem: prefilledHSItem))
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.large) {
                importHeader
                deliveryTermSection
                declarationDetailsSection
                valueSection
                hsSection
                resultSection
                officialReference
                Spacer(minLength: AppSpacing.xxLarge)
            }
            .padding(AppSpacing.medium)
        }
        .background(AppColors.groupedBackground.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnBackgroundTap()
        .navigationTitle(LanguageManager.shared.string(.toolDutyCalculator))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(LanguageManager.shared.string(.reset)) { viewModel.reset() }
            }
        }
        .sheet(item: $sharePayload) { payload in
            ActivityView(activityItems: payload.items)
        }
    }

    private var importHeader: some View {
        AppCard {
            HStack(spacing: AppSpacing.small) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppColors.brandPrimary.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: "shippingbox.fill")
                        .foregroundStyle(AppColors.brandPrimary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(LanguageManager.shared.string(.dutyImportOnly))
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.textPrimary)
                    Text(LanguageManager.shared.string(.dutyImportOnlyDesc))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                Text("IMPORT")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(AppColors.success)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(AppColors.success.opacity(0.12))
                    .clipShape(Capsule())
                    .preserveTechnicalLTR()
            }
        }
    }

    private var deliveryTermSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            AppSectionHeader(title: LanguageManager.shared.string(.dutyDeliveryTerm))
            // Keep the four operational terms permanently visible. The native segmented
            // control was collapsing one item in RTL on some iPhone widths.
            AppSegmentedPicker(
                items: DeliveryTerm.allCases,
                selection: $viewModel.deliveryTerm,
                titleProvider: { $0.rawValue }
            )

            Text(deliveryHint)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var declarationDetailsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            AppSectionHeader(title: LanguageManager.shared.string(.dutyDeclarationDetails))
            AppCard {
                VStack(spacing: AppSpacing.medium) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LanguageManager.shared.string(.dutyImporterType))
                            .font(AppTypography.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                        Picker(LanguageManager.shared.string(.dutyImporterType), selection: $viewModel.importerType) {
                            Text(LanguageManager.shared.string(.dutyCompany)).tag(ImporterType.company)
                            Text(LanguageManager.shared.string(.dutyPersonal)).tag(ImporterType.personal)
                        }
                        .pickerStyle(.segmented)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text(LanguageManager.shared.string(.dutyDocuments))
                            .font(AppTypography.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                        Picker(LanguageManager.shared.string(.dutyDocuments), selection: $viewModel.documentStatus) {
                            Text(LanguageManager.shared.string(.dutyDocumentsOriginal)).tag(DocumentStatus.original)
                            Text(LanguageManager.shared.string(.dutyDocumentsNotOriginal)).tag(DocumentStatus.notOriginal)
                        }
                        .pickerStyle(.segmented)
                    }

                    HStack {
                        Label(LanguageManager.shared.string(.dutyBayanDocumentation), systemImage: "doc.text.fill")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                        Spacer()
                        Text(viewModel.bayanDocumentationPreviewOMR.formattedOMR())
                            .font(AppTypography.technicalNumberSmall)
                            .foregroundStyle(AppColors.brandPrimary)
                            .preserveTechnicalLTR()
                    }
                    .padding(AppSpacing.small)
                    .background(AppColors.brandPrimary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    if viewModel.documentStatus == .notOriginal {
                        Label(LanguageManager.shared.string(.dutyGuaranteeRule), systemImage: "exclamationmark.shield.fill")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var valueSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            AppSectionHeader(title: LanguageManager.shared.string(.dutyCustomsValue))

            AppCard {
                VStack(spacing: AppSpacing.medium) {
                    switch viewModel.deliveryTerm {
                    case .cif:
                        moneyField(
                            title: LanguageManager.shared.string(.dutyCIFValue),
                            placeholder: "1000.000",
                            text: $viewModel.cifText,
                            currency: $viewModel.cifCurrency,
                            exchangeRateText: $viewModel.cifExchangeRateText,
                            valueField: .cif,
                            rateField: .cifRate
                        )

                    case .cfr:
                        moneyField(
                            title: LanguageManager.shared.string(.dutyCFRValue),
                            placeholder: "1000.000",
                            text: $viewModel.cfrText,
                            currency: $viewModel.cfrCurrency,
                            exchangeRateText: $viewModel.cfrExchangeRateText,
                            valueField: .cfr,
                            rateField: .cfrRate
                        )
                        insurancePreview

                    case .fob, .exw:
                        moneyField(
                            title: LanguageManager.shared.string(.dutyCostValue),
                            placeholder: "1000.000",
                            text: $viewModel.costText,
                            currency: $viewModel.costCurrency,
                            exchangeRateText: $viewModel.costExchangeRateText,
                            valueField: .cost,
                            rateField: .costRate
                        )

                        moneyField(
                            title: LanguageManager.shared.string(.dutyFreightValue),
                            placeholder: "100.000",
                            text: $viewModel.freightText,
                            currency: $viewModel.freightCurrency,
                            exchangeRateText: $viewModel.freightExchangeRateText,
                            valueField: .freight,
                            rateField: .freightRate
                        )

                        insurancePreview
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var insurancePreview: some View {
        if let insurance = viewModel.insurancePreviewOMR {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(LanguageManager.shared.string(.dutyInsuranceAuto))
                        .font(AppTypography.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                    Text(LanguageManager.shared.string(.dutyInsuranceFormula))
                        .font(AppTypography.caption2)
                        .foregroundStyle(AppColors.textTertiary)
                }
                Spacer()
                Text(insurance.formattedOMR())
                    .font(AppTypography.technicalNumberMedium)
                    .foregroundStyle(AppColors.brandGold)
                    .preserveTechnicalLTR()
            }
            .padding(AppSpacing.small)
            .background(AppColors.brandGold.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var hsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            AppSectionHeader(title: LanguageManager.shared.string(.dutyHSMethod))

            Picker(LanguageManager.shared.string(.dutyHSMethod), selection: $viewModel.lookupMode) {
                Text(LanguageManager.shared.string(.dutyMethodHS)).tag(DutyLookupMode.hsCode)
                Text(LanguageManager.shared.string(.dutyMethodDescription)).tag(DutyLookupMode.description)
                Text(LanguageManager.shared.string(.dutyMethodQuick)).tag(DutyLookupMode.quickEstimate)
            }
            .pickerStyle(.segmented)

            if viewModel.lookupMode == .quickEstimate {
                AppCard {
                    HStack(alignment: .top, spacing: AppSpacing.small) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppColors.warning)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LanguageManager.shared.string(.dutyQuickEstimateTitle))
                                .font(AppTypography.headline)
                            Text(LanguageManager.shared.string(.dutyQuickEstimateDesc))
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                }
            } else {
                AppCard {
                    VStack(spacing: AppSpacing.small) {
                        HStack(spacing: AppSpacing.small) {
                            Image(systemName: viewModel.lookupMode == .hsCode ? "number" : "text.magnifyingglass")
                                .foregroundStyle(AppColors.brandPrimary)
                            TextField(
                                viewModel.lookupMode == .hsCode
                                    ? LanguageManager.shared.string(.hsSearchPlaceholder)
                                    : LanguageManager.shared.string(.dutyDescriptionPlaceholder),
                                text: $viewModel.hsQuery
                            )
                            .font(AppTypography.body)
                            .focused($focusedField, equals: .hs)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(viewModel.lookupMode == .hsCode ? .numbersAndPunctuation : .default)
                        }
                        .padding(12)
                        .background(AppColors.innerCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        if let item = viewModel.selectedHSItem {
                            selectedHSCard(item)
                        } else if !viewModel.suggestions.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(Array(viewModel.suggestions.enumerated()), id: \.element.id) { index, item in
                                    Button {
                                        viewModel.selectHSItem(item)
                                    } label: {
                                        HStack(alignment: .top, spacing: AppSpacing.small) {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(item.formattedCode)
                                                    .font(AppTypography.technicalNumberMedium)
                                                    .foregroundStyle(AppColors.brandPrimary)
                                                    .preserveTechnicalLTR()
                                                Text(LanguageManager.shared.isRTL
                                                     ? (item.descriptionArabic ?? item.descriptionEnglish ?? "")
                                                     : (item.descriptionEnglish ?? item.descriptionArabic ?? ""))
                                                    .font(AppTypography.caption)
                                                    .foregroundStyle(AppColors.textSecondary)
                                                    .lineLimit(2)
                                            }
                                            Spacer()
                                            Text(item.dutyRate ?? "—")
                                                .font(AppTypography.caption)
                                                .fontWeight(.bold)
                                                .foregroundStyle(AppColors.brandGold)
                                                .preserveTechnicalLTR()
                                        }
                                        .padding(.vertical, 10)
                                    }
                                    .buttonStyle(.plain)
                                    if index < viewModel.suggestions.count - 1 { Divider() }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        if let result = viewModel.result {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                AppSectionHeader(title: LanguageManager.shared.string(.dutyResultTitle))

                AppCard {
                    VStack(spacing: AppSpacing.small) {
                        // Keep the result operational: users mainly need to know what
                        // they will pay. CIF, duty rate, VAT base and VAT rate remain
                        // part of the calculation model but are intentionally hidden
                        // from the primary result card to reduce visual noise.
                        resultRow(LanguageManager.shared.string(.dutyDutyAmount), result.dutyOMR.formattedOMR())
                        resultRow(LanguageManager.shared.string(.dutyVATAmount), result.vatOMR.formattedOMR())

                        Divider()

                        resultRow(
                            LanguageManager.shared.string(.dutyTotalTaxes),
                            result.totalTaxesOMR.formattedOMR(),
                            emphasized: true
                        )

                        if result.documentationGuaranteeApplied {
                            Divider()
                            resultRow(
                                LanguageManager.shared.string(.dutyDocumentationGuarantee),
                                result.documentationGuaranteeOMR.formattedOMR()
                            )
                        }

                        resultRow(
                            LanguageManager.shared.string(.dutyBayanDocumentation),
                            result.bayanDocumentationOMR.formattedOMR()
                        )

                        Divider()

                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(LanguageManager.shared.string(.dutyTotalPayable))
                                    .font(AppTypography.title3)
                                    .foregroundStyle(.white)
                                Text(LanguageManager.shared.string(.dutyTotalBreakdown))
                                    .font(AppTypography.caption2)
                                    .foregroundStyle(.white.opacity(0.72))
                            }
                            Spacer()
                            Text(result.totalPayableOMR.formattedOMR())
                                .font(.system(size: 25, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppColors.brandGold)
                                .minimumScaleFactor(0.65)
                                .lineLimit(1)
                                .preserveTechnicalLTR()
                        }
                        .padding(AppSpacing.medium)
                        .background(AppColors.brandDeepNavy)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }

                resultActions(result)

                if result.isEstimate {
                    Text(LanguageManager.shared.string(.dutyEstimateDisclaimer))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func resultActions(_ result: DutyCalculationResult) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            AppSectionHeader(title: LanguageManager.shared.string(.dutyActions))
            AppCard {
                HStack(spacing: 8) {
                    actionButton(
                        title: copied ? LanguageManager.shared.string(.dutyCopied) : LanguageManager.shared.string(.dutyCopyResult),
                        icon: copied ? "checkmark" : "doc.on.doc"
                    ) {
                        UIPasteboard.general.string = resultText(result)
                        copied = true
                        HapticFeedback.success()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                    }

                    actionButton(title: LanguageManager.shared.string(.dutyExportPDF), icon: "doc.richtext") {
                        sharePDF(result)
                    }
                }
            }
        }
    }

    private var officialReference: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            AppSectionHeader(title: LanguageManager.shared.string(.sourceReference))
            AppCard {
                VStack(alignment: .leading, spacing: 8) {
                    Label(LanguageManager.shared.string(.dutyOfficialSource), systemImage: "checkmark.seal.fill")
                        .font(AppTypography.subheadline)
                        .foregroundStyle(AppColors.brandPrimary)
                    Text(LanguageManager.shared.string(.dutyOfficialNote))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                    if let url = URL(string: AppConfig.omanDutyCalculatorURL) {
                        Link(destination: url) {
                            Label(LanguageManager.shared.string(.dutyOpenOfficialCalculator), systemImage: "safari")
                                .font(AppTypography.caption)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
    }

    private var deliveryHint: String {
        switch viewModel.deliveryTerm {
        case .cif: return LanguageManager.shared.string(.dutyCIFHint)
        case .cfr: return LanguageManager.shared.string(.dutyCFRHint)
        case .fob, .exw: return LanguageManager.shared.string(.dutyFOBEXWHint)
        }
    }

    private func selectedHSCard(_ item: HSCodeItem) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.small) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(item.formattedCode)
                        .font(AppTypography.technicalNumberMedium)
                        .foregroundStyle(AppColors.brandPrimary)
                        .preserveTechnicalLTR()
                    Text(item.dutyRate ?? "—")
                        .font(AppTypography.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(AppColors.brandGold)
                }
                Text(LanguageManager.shared.isRTL
                     ? (item.descriptionArabic ?? item.descriptionEnglish ?? "")
                     : (item.descriptionEnglish ?? item.descriptionArabic ?? ""))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
            Button { viewModel.clearHSSelection() } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(AppColors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(AppSpacing.small)
        .background(AppColors.brandPrimary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func moneyField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        currency: Binding<Currency>,
        exchangeRateText: Binding<String>,
        valueField: Field,
        rateField: Field
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppTypography.subheadline)
                .foregroundStyle(AppColors.textSecondary)

            HStack(spacing: 8) {
                TextField(placeholder, text: text)
                    .font(AppTypography.technicalNumberMedium)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: valueField)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 48)
                    .background(AppColors.innerCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Picker(LanguageManager.shared.string(.dutyCurrency), selection: currency) {
                    ForEach(Currency.allCases) { item in
                        Text(item.code).tag(item)
                    }
                }
                .pickerStyle(.menu)
                .frame(minWidth: 78, minHeight: 48)
                .background(AppColors.innerCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if currency.wrappedValue != .omr {
                VStack(alignment: .leading, spacing: 6) {
                    Text(LanguageManager.shared.string(.dutyExchangeRateToOMR))
                        .font(AppTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.textSecondary)

                    HStack(spacing: 7) {
                        Text("1 \(currency.wrappedValue.code) =")
                            .font(AppTypography.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColors.textSecondary)
                            .preserveTechnicalLTR()

                        TextField(LanguageManager.shared.string(.dutyExchangeRateRequired), text: exchangeRateText)
                            .font(AppTypography.technicalNumberSmall)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: rateField)
                            .multilineTextAlignment(.center)

                        Text("OMR")
                            .font(AppTypography.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(AppColors.brandPrimary)
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 46)
                    .background(AppColors.brandPrimary.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(
                                exchangeRateText.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? AppColors.warning.opacity(0.65)
                                    : AppColors.subtleBorder,
                                lineWidth: 1
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                    Text(LanguageManager.shared.string(.dutyExchangeRateHint, currency.wrappedValue.code))
                        .font(AppTypography.caption2)
                        .foregroundStyle(
                            exchangeRateText.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? AppColors.warning
                                : AppColors.textTertiary
                        )
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func resultRow(_ title: String, _ value: String, emphasized: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(emphasized ? AppTypography.headline : AppTypography.subheadline)
                .foregroundStyle(emphasized ? AppColors.textPrimary : AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(emphasized ? AppTypography.technicalNumberLarge : AppTypography.technicalNumberMedium)
                .foregroundStyle(emphasized ? AppColors.brandPrimary : AppColors.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .preserveTechnicalLTR()
        }
    }

    private func actionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(AppColors.brandPrimary)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(AppColors.brandPrimary.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func resultText(_ result: DutyCalculationResult) -> String {
        let lm = LanguageManager.shared
        let importer = result.importerType == .company ? lm.string(.dutyCompany) : lm.string(.dutyPersonal)
        let documents = result.documentStatus == .original ? lm.string(.dutyDocumentsOriginal) : lm.string(.dutyDocumentsNotOriginal)
        var lines: [String] = [
            lm.string(.dutyReportTitle),
            "\(lm.string(.dutyDeliveryTerm)): \(result.deliveryTerm.rawValue)",
            "\(lm.string(.dutyImporterType)): \(importer)",
            "\(lm.string(.dutyDocuments)): \(documents)"
        ]

        if let hs = result.hsCode {
            lines.append("HS Code: \(hs)")
            if let item = viewModel.selectedHSItem {
                let description = lm.isRTL
                    ? (item.descriptionArabic ?? item.descriptionEnglish ?? "")
                    : (item.descriptionEnglish ?? item.descriptionArabic ?? "")
                if !description.isEmpty {
                    lines.append("\(lm.string(.commodityDescription)): \(description)")
                }
            }
        }

        lines += [
            "\(lm.string(.dutyCIFOMR)): \(result.cifOMR.formattedOMR())",
            "\(lm.string(.dutyDutyAmount)): \(result.dutyOMR.formattedOMR()) (\(viewModel.dutyRateDisplay))",
            "\(lm.string(.dutyVATAmount)): \(result.vatOMR.formattedOMR()) (5%)",
            "\(lm.string(.dutyTotalTaxes)): \(result.totalTaxesOMR.formattedOMR())"
        ]

        if result.documentationGuaranteeApplied {
            lines.append("\(lm.string(.dutyDocumentationGuarantee)): \(result.documentationGuaranteeOMR.formattedOMR())")
        }

        lines.append("\(lm.string(.dutyBayanDocumentation)): \(result.bayanDocumentationOMR.formattedOMR())")
        lines.append("\(lm.string(.dutyTotalPayable)): \(result.totalPayableOMR.formattedOMR())")
        return lines.joined(separator: "\n")
    }

    private func reportSnapshot(_ result: DutyCalculationResult) -> DutyReportSnapshot {
        let lm = LanguageManager.shared
        let importer = result.importerType == .company ? lm.string(.dutyCompany) : lm.string(.dutyPersonal)
        let documents = result.documentStatus == .original ? lm.string(.dutyDocumentsOriginal) : lm.string(.dutyDocumentsNotOriginal)

        var rows: [(String, String)] = [
            (lm.string(.dutyDeliveryTerm), result.deliveryTerm.rawValue),
            (lm.string(.dutyImporterType), importer),
            (lm.string(.dutyDocuments), documents)
        ]
        if let hs = result.hsCode {
            rows.append(("HS Code", hs))
            if let item = viewModel.selectedHSItem {
                let description = lm.isRTL
                    ? (item.descriptionArabic ?? item.descriptionEnglish ?? "")
                    : (item.descriptionEnglish ?? item.descriptionArabic ?? "")
                if !description.isEmpty {
                    rows.append((lm.string(.commodityDescription), description))
                }
            }
        }
        rows += [
            (lm.string(.dutyCIFOMR), result.cifOMR.formattedOMR()),
            (lm.string(.dutyDutyRate), viewModel.dutyRateDisplay),
            (lm.string(.dutyDutyAmount), result.dutyOMR.formattedOMR()),
            (lm.string(.dutyVATBase), result.vatBaseOMR.formattedOMR()),
            (lm.string(.dutyVATRate), "5%"),
            (lm.string(.dutyVATAmount), result.vatOMR.formattedOMR()),
            (lm.string(.dutyTotalTaxes), result.totalTaxesOMR.formattedOMR())
        ]
        if result.documentationGuaranteeApplied {
            rows.append((lm.string(.dutyDocumentationGuarantee), result.documentationGuaranteeOMR.formattedOMR()))
        }
        rows.append((lm.string(.dutyBayanDocumentation), result.bayanDocumentationOMR.formattedOMR()))

        return DutyReportSnapshot(
            title: lm.string(.dutyReportTitle),
            rows: rows,
            totalLabel: lm.string(.dutyTotalPayable),
            totalValue: result.totalPayableOMR.formattedOMR(),
            note: lm.string(.dutyReportNote),
            footer: lm.string(.dutyGeneratedBy),
            isRTL: lm.isRTL
        )
    }

    private func sharePDF(_ result: DutyCalculationResult) {
        do {
            let url = try DutyReportPDFBuilder.makePDF(snapshot: reportSnapshot(result))
            sharePayload = DutySharePayload(items: [url])
            HapticFeedback.success()
        } catch {
            HapticFeedback.error()
        }
    }

    private func printPDF(_ result: DutyCalculationResult) {
        do {
            let url = try DutyReportPDFBuilder.makePDF(snapshot: reportSnapshot(result))
            let controller = UIPrintInteractionController.shared
            let info = UIPrintInfo(dictionary: nil)
            info.outputType = .general
            info.jobName = LanguageManager.shared.string(.dutyReportTitle)
            controller.printInfo = info
            controller.printingItem = url
            controller.present(animated: true)
        } catch {
            HapticFeedback.error()
        }
    }
}

private struct DutySharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

#if canImport(UIKit)
private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct DutyReportSnapshot {
    let title: String
    let rows: [(String, String)]
    let totalLabel: String
    let totalValue: String
    let note: String
    let footer: String
    let isRTL: Bool
}

private enum DutyReportPDFBuilder {
    static func makePDF(snapshot: DutyReportSnapshot) throws -> URL {
        let fileName = "Customs-Toolkit-Duty-\(Int(Date().timeIntervalSince1970)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        let pageBounds = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4 points
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)

        try renderer.writePDF(to: url) { context in
            context.beginPage()
            let cg = context.cgContext

            let navy = UIColor(red: 7/255, green: 38/255, blue: 74/255, alpha: 1)
            let blue = UIColor(red: 15/255, green: 76/255, blue: 129/255, alpha: 1)
            let gold = UIColor(red: 220/255, green: 169/255, blue: 55/255, alpha: 1)
            let text = UIColor(red: 30/255, green: 41/255, blue: 59/255, alpha: 1)
            let secondary = UIColor(red: 100/255, green: 116/255, blue: 139/255, alpha: 1)
            let soft = UIColor(red: 247/255, green: 249/255, blue: 252/255, alpha: 1)

            cg.setFillColor(UIColor.white.cgColor)
            cg.fill(pageBounds)

            // Header
            let header = CGRect(x: 0, y: 0, width: pageBounds.width, height: 130)
            cg.setFillColor(navy.cgColor)
            cg.fill(header)
            cg.setFillColor(gold.cgColor)
            cg.fill(CGRect(x: 44, y: 112, width: 86, height: 4))

            drawText(
                "CUSTOMS TOOLKIT",
                in: CGRect(x: 44, y: 28, width: 507, height: 24),
                font: .systemFont(ofSize: 12, weight: .bold),
                color: gold,
                alignment: snapshot.isRTL ? .right : .left
            )
            drawText(
                snapshot.title,
                in: CGRect(x: 44, y: 58, width: 507, height: 44),
                font: .systemFont(ofSize: 25, weight: .bold),
                color: .white,
                alignment: snapshot.isRTL ? .right : .left
            )

            let formatter = DateFormatter()
            formatter.locale = snapshot.isRTL ? Locale(identifier: "ar_OM") : Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "dd MMM yyyy • HH:mm"
            drawText(
                formatter.string(from: Date()),
                in: CGRect(x: 44, y: 142, width: 507, height: 22),
                font: .systemFont(ofSize: 10, weight: .medium),
                color: secondary,
                alignment: snapshot.isRTL ? .right : .left
            )

            var y: CGFloat = 180
            let x: CGFloat = 44
            let width: CGFloat = 507
            let rowHeight: CGFloat = 39

            cg.setFillColor(soft.cgColor)
            let rowsBoxHeight = CGFloat(snapshot.rows.count) * rowHeight + 20
            let rowsBox = CGRect(x: x, y: y, width: width, height: rowsBoxHeight)
            let path = UIBezierPath(roundedRect: rowsBox, cornerRadius: 14)
            cg.addPath(path.cgPath)
            cg.fillPath()

            y += 10
            for (index, row) in snapshot.rows.enumerated() {
                let labelRect: CGRect
                let valueRect: CGRect
                if snapshot.isRTL {
                    valueRect = CGRect(x: x + 16, y: y, width: 218, height: rowHeight)
                    labelRect = CGRect(x: x + 246, y: y, width: 245, height: rowHeight)
                } else {
                    labelRect = CGRect(x: x + 16, y: y, width: 245, height: rowHeight)
                    valueRect = CGRect(x: x + 273, y: y, width: 218, height: rowHeight)
                }

                drawText(row.0, in: labelRect, font: .systemFont(ofSize: 11, weight: .medium), color: secondary, alignment: snapshot.isRTL ? .right : .left)
                drawText(row.1.replacingOccurrences(of: "\u{200E}", with: ""), in: valueRect, font: .monospacedSystemFont(ofSize: 12, weight: .semibold), color: text, alignment: snapshot.isRTL ? .left : .right)

                if index < snapshot.rows.count - 1 {
                    cg.setStrokeColor(UIColor(red: 226/255, green: 232/255, blue: 240/255, alpha: 1).cgColor)
                    cg.setLineWidth(0.7)
                    cg.move(to: CGPoint(x: x + 16, y: y + rowHeight - 2))
                    cg.addLine(to: CGPoint(x: x + width - 16, y: y + rowHeight - 2))
                    cg.strokePath()
                }
                y += rowHeight
            }

            y = rowsBox.maxY + 22
            let totalBox = CGRect(x: x, y: y, width: width, height: 82)
            let totalPath = UIBezierPath(roundedRect: totalBox, cornerRadius: 16)
            cg.setFillColor(navy.cgColor)
            cg.addPath(totalPath.cgPath)
            cg.fillPath()

            drawText(
                snapshot.totalLabel,
                in: CGRect(x: x + 18, y: y + 18, width: 180, height: 30),
                font: .systemFont(ofSize: 18, weight: .bold),
                color: .white,
                alignment: snapshot.isRTL ? .right : .left
            )
            drawText(
                snapshot.totalValue.replacingOccurrences(of: "\u{200E}", with: ""),
                in: CGRect(x: x + 205, y: y + 15, width: 284, height: 38),
                font: .monospacedSystemFont(ofSize: 22, weight: .bold),
                color: gold,
                alignment: snapshot.isRTL ? .left : .right
            )

            y = totalBox.maxY + 24
            cg.setFillColor(blue.withAlphaComponent(0.08).cgColor)
            let noteBox = CGRect(x: x, y: y, width: width, height: 58)
            let notePath = UIBezierPath(roundedRect: noteBox, cornerRadius: 12)
            cg.addPath(notePath.cgPath)
            cg.fillPath()
            drawText(
                snapshot.note,
                in: CGRect(x: x + 15, y: y + 12, width: width - 30, height: 35),
                font: .systemFont(ofSize: 9, weight: .regular),
                color: blue,
                alignment: snapshot.isRTL ? .right : .left
            )

            drawText(
                snapshot.footer,
                in: CGRect(x: 44, y: pageBounds.height - 52, width: 507, height: 20),
                font: .systemFont(ofSize: 9, weight: .medium),
                color: secondary,
                alignment: .center
            )
        }

        return url
    }

    private static func drawText(
        _ string: String,
        in rect: CGRect,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment
    ) {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineBreakMode = .byTruncatingTail
        (string as NSString).draw(
            in: rect,
            withAttributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: style
            ]
        )
    }
}
#endif
