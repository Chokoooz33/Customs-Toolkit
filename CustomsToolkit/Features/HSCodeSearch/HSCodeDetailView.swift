import SwiftUI

public struct HSCodeDetailView: View {
    let item: HSCodeItem

    @Environment(\.openURL) private var openURL
    @State private var copiedCode = false
    @State private var copiedArDesc = false
    @State private var copiedEnDesc = false
    @State private var pathExpanded = true
    @State private var showIndicatorHelp = false

    public init(item: HSCodeItem) {
        self.item = item
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.large) {
                headerCard
                descriptionSection
                classificationPathSection
                guidanceSection
                detailsSection
                permitSection
                tradeAgreementSection
                sourceSection
                actionsSection
                Spacer(minLength: AppSpacing.xxLarge)
            }
            .padding(AppSpacing.medium)
        }
        .background(AppColors.groupedBackground.ignoresSafeArea())
        .navigationTitle(item.formattedCode)
        .navigationBarTitleDisplayMode(.inline)
        .alert(isArabic ? "مؤشرات الاتفاقيات التجارية" : "Trade Agreement Indicators", isPresented: $showIndicatorHelp) {
            Button(isArabic ? "حسناً" : "OK", role: .cancel) { }
        } message: {
            Text(isArabic
                 ? "الحروف المعروضة هي مؤشرات من التعرفة الرسمية. لا تعني وحدها أن الشحنة مستحقة للإعفاء أو المعاملة التفضيلية؛ يجب التحقق من بلد المنشأ وقواعد المنشأ وشروط الاتفاقية."
                 : "The displayed letters are indicators from the official tariff. They do not, by themselves, confirm preferential treatment or an exemption; country of origin, rules of origin and agreement conditions must still be verified.")
        }
    }

    // MARK: - Primary header

    private var headerCard: some View {
        AppCard(padding: AppSpacing.large) {
            VStack(spacing: AppSpacing.small) {
                Text(item.formattedCode)
                    .font(AppTypography.technicalNumberLarge)
                    .foregroundColor(AppColors.brandPrimary)
                    .preserveTechnicalLTR()
                    .multilineTextAlignment(.center)

                HStack(spacing: 8) {
                    Text(primaryOfficialDescription)
                        .font(AppTypography.headline)
                        .foregroundColor(AppColors.textPrimary)
                    if let duty = item.dutyRate, !duty.isEmpty {
                        Text("•")
                            .foregroundColor(AppColors.textTertiary)
                        Text(duty)
                            .font(AppTypography.headline)
                            .foregroundColor(AppColors.brandPrimary)
                            .preserveTechnicalLTR()
                    }
                }
                .multilineTextAlignment(.center)

                Text(item.normalizedCode)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .preserveTechnicalLTR()

                statusDetailBadge(item.status)
                    .padding(.top, 2)

                Divider().padding(.vertical, AppSpacing.xSmall)

                HStack(spacing: AppSpacing.small) {
                    Button(action: copyCode) {
                        quickActionLabel(
                            copiedCode ? (isArabic ? "تم النسخ" : "Copied") : (isArabic ? "نسخ HS" : "Copy HS"),
                            systemImage: copiedCode ? "checkmark" : "doc.on.doc"
                        )
                    }

                    NavigationLink(destination: DutyCalculatorView(prefilledHSItem: item)) {
                        quickActionLabel(isArabic ? "حساب الرسوم" : "Calculate Duty", systemImage: "banknote.fill")
                    }
                }
            }
        }
    }

    // MARK: - Official description

    @ViewBuilder
    private var descriptionSection: some View {
        if hasDescription {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                AppSectionHeader(title: isArabic ? "الوصف الرسمي للبضاعة" : "Official Commodity Description")

                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.medium) {
                        if let ar = clean(item.descriptionArabic) {
                            descriptionRow(label: "العربية", value: ar, copied: copiedArDesc) {
                                ClipboardService.copy(ar)
                                HapticFeedback.success()
                                withAnimation { copiedArDesc = true }
                                resetLater { copiedArDesc = false }
                            }
                        }

                        if clean(item.descriptionArabic) != nil && clean(item.descriptionEnglish) != nil { Divider() }

                        if let en = clean(item.descriptionEnglish) {
                            descriptionRow(label: "English", value: en, copied: copiedEnDesc) {
                                ClipboardService.copy(en)
                                HapticFeedback.success()
                                withAnimation { copiedEnDesc = true }
                                resetLater { copiedEnDesc = false }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Classification Path

    private var classificationPathSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { pathExpanded.toggle() }
            } label: {
                HStack {
                    AppSectionHeader(title: isArabic ? "التسلسل الجمركي | Classification Path" : "Classification Path | التسلسل الجمركي")
                    Spacer()
                    Image(systemName: pathExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(AppColors.brandPrimary)
                }
            }
            .buttonStyle(.plain)

            if pathExpanded {
                AppCard {
                    VStack(alignment: .leading, spacing: 0) {
                        classificationNode(
                            badge: isArabic ? "الفصل" : "Chapter",
                            code: chapterCode,
                            title: context.chapterTitle
                        )
                        pathConnector
                        classificationNode(
                            badge: isArabic ? "البند" : "Heading",
                            code: headingCode,
                            title: context.headingTitle
                        )
                        if let subheadingTitle = context.subheadingTitle, !subheadingTitle.isEmpty {
                            pathConnector
                            classificationNode(
                                badge: isArabic ? "البند الفرعي" : "Subheading",
                                code: subheadingCode,
                                title: subheadingTitle
                            )
                        }
                        pathConnector
                        classificationNode(
                            badge: "HS",
                            code: item.formattedCode,
                            title: bilingualLeafDescription,
                            isFinal: true
                        )
                    }
                }
            }
        }
    }

    private func classificationNode(badge: String, code: String, title: String?, isFinal: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(badge)
                    .font(AppTypography.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(isFinal ? .white : AppColors.brandPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isFinal ? AppColors.brandPrimary : AppColors.brandPrimary.opacity(0.11))
                    .clipShape(Capsule())

                Text(code)
                    .font(isFinal ? AppTypography.headline : AppTypography.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(isFinal ? AppColors.brandPrimary : AppColors.textPrimary)
                    .preserveTechnicalLTR()
            }

            if let title, !title.isEmpty {
                Text(title)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !isFinal {
                Text(isArabic ? "الوصف الأعلى غير مخزن في قاعدة البيانات الحالية؛ لا يتم تخمينه." : "The parent description is not stored in the current dataset; it is not guessed.")
                    .font(AppTypography.caption2)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private var pathConnector: some View {
        HStack {
            Image(systemName: "arrow.down")
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Guidance

    private var guidanceSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            AppSectionHeader(title: isArabic ? "الشرح الجمركي | Classification Guidance" : "Classification Guidance | الشرح الجمركي")

            AppCard {
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    HStack(alignment: .top, spacing: AppSpacing.small) {
                        Image(systemName: "book.closed.fill")
                            .foregroundColor(AppColors.brandPrimary)
                        Text(guidanceText)
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(alignment: .top, spacing: 7) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .foregroundColor(AppColors.warning)
                        Text(isArabic
                             ? "هذا الشرح يفسر فقط النص والتسلسل الرسمي المتاحين في تعرفة عُمان 2026. لا يثبت أن سلعة معينة تقع تحت هذا الرمز دون مطابقة مواصفاتها والملاحظات القانونية وقواعد التصنيف."
                             : "This guidance only explains the official wording and hierarchy available in Oman Tariff 2026. It does not prove that a specific product falls under this code without matching its specifications, legal notes and classification rules.")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Divider()

                    HStack(spacing: AppSpacing.small) {
                        Button { openImageSearch() } label: {
                            compactLinkLabel(isArabic ? "صور توضيحية" : "Image Examples", "photo.on.rectangle")
                        }
                        Button { openWebSearch() } label: {
                            compactLinkLabel(isArabic ? "بحث على الويب" : "Web Search", "magnifyingglass")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Details / permit / agreements / source

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            AppSectionHeader(title: LanguageManager.shared.string(.details))
            AppCard {
                VStack(spacing: AppSpacing.small) {
                    detailRow(isArabic ? "نسبة الرسم الجمركي" : "Duty Rate", item.dutyRate, emphasized: true)
                    Divider()
                    detailRow(isArabic ? "الفصل" : "Chapter", chapterCode)
                    Divider()
                    detailRow(isArabic ? "البند الجمركي" : "Heading", headingCode)
                    Divider()
                    detailRow(isArabic ? "البند الفرعي" : "Subheading", subheadingCode)
                    if let procedure = clean(item.procedure) {
                        Divider()
                        detailRow(isArabic ? "الإجراء" : "Procedure", procedure)
                    }
                }
            }
        }
    }

    private var permitSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            AppSectionHeader(title: LanguageManager.shared.string(.permitTitle))
            AppCard {
                VStack(spacing: AppSpacing.small) {
                    HStack(spacing: AppSpacing.small) {
                        Image(systemName: item.status == .prohibited ? "nosign" : "checkmark.shield.fill")
                            .foregroundStyle(item.status == .prohibited ? AppColors.error : AppColors.warning)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LanguageManager.shared.string(.permitRequirement))
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                            Text(item.status == .prohibited
                                 ? LanguageManager.shared.string(.permitProhibited)
                                 : LanguageManager.shared.string(.permitVerificationRequired))
                                .font(AppTypography.headline)
                                .foregroundStyle(item.status == .prohibited ? AppColors.error : AppColors.textPrimary)
                        }
                        Spacer()
                    }
                    Divider()
                    NavigationLink(destination: PermitRequirementWebView(hsCode: item.normalizedCode)) {
                        navigationRow(LanguageManager.shared.string(.permitCheckAction), systemImage: "safari")
                    }.buttonStyle(.plain)
                    Divider()
                    NavigationLink(destination: DutyCalculatorView(prefilledHSItem: item)) {
                        navigationRow(LanguageManager.shared.string(.dutyCalculateForHS), systemImage: "banknote.fill")
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var tradeAgreementSection: some View {
        if hasTradeAgreements {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                HStack {
                    AppSectionHeader(title: LanguageManager.shared.string(.tradeAgreements))
                    Spacer()
                    Button { showIndicatorHelp = true } label: {
                        Label(isArabic ? "ما معنى المؤشر؟" : "Indicator meaning", systemImage: "info.circle")
                            .font(AppTypography.caption2)
                            .foregroundColor(AppColors.brandPrimary)
                    }
                }
                AppCard {
                    VStack(spacing: AppSpacing.small) {
                        agreementRow(LanguageManager.shared.string(.indicatorInd), item.indIndicator)
                        agreementDividerIfNeeded(after: item.indIndicator, before: item.eftaIndicator)
                        agreementRow(LanguageManager.shared.string(.indicatorEfta), item.eftaIndicator)
                        agreementDividerIfNeeded(after: item.eftaIndicator, before: item.sgIndicator)
                        agreementRow(LanguageManager.shared.string(.indicatorSg), item.sgIndicator)
                        agreementDividerIfNeeded(after: item.sgIndicator, before: item.usaIndicator)
                        agreementRow(LanguageManager.shared.string(.indicatorUsa), item.usaIndicator)
                    }
                }
            }
        }
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            AppSectionHeader(title: LanguageManager.shared.string(.sourceReference))
            AppCard {
                VStack(spacing: AppSpacing.small) {
                    detailRow(LanguageManager.shared.string(.officialTariffSource), AppConfig.omanCustomsTariffSource)
                    if let page = item.sourcePage {
                        Divider()
                        detailRow(LanguageManager.shared.string(.sourcePage), "p. \(page)")
                    }
                    Divider()
                    Button { openOfficialSource() } label: {
                        navigationRow(isArabic ? "فتح بوابة جمارك عُمان الرسمية" : "Open Oman Customs official portal", systemImage: "safari")
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            AppSectionHeader(title: isArabic ? "الإجراءات" : "Actions")
            AppCard {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.small) {
                    actionTile(isArabic ? "نسخ HS" : "Copy HS", "doc.on.doc", action: copyCode)
                    actionTile(isArabic ? "صور توضيحية" : "Image Examples", "photo.on.rectangle", action: openImageSearch)
                    NavigationLink(destination: DutyCalculatorView(prefilledHSItem: item)) {
                        actionTileContent(isArabic ? "حساب الرسوم" : "Calculate Duty", "banknote.fill")
                    }.buttonStyle(.plain)
                    Button(action: openOfficialSource) {
                        actionTileContent(isArabic ? "المصدر الرسمي" : "Official Source", "safari")
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Helpers

    private var isArabic: Bool { LanguageManager.shared.currentLanguage == .arabic }
    private var hasDescription: Bool { clean(item.descriptionArabic) != nil || clean(item.descriptionEnglish) != nil }
    private var chapterCode: String { item.chapter ?? String(item.normalizedCode.prefix(2)) }
    private var headingCode: String { item.heading ?? String(item.normalizedCode.prefix(4)) }
    private var subheadingCode: String {
        let p = String(item.normalizedCode.prefix(min(6, item.normalizedCode.count)))
        guard p.count == 6 else { return p }
        return String(p.prefix(4)) + "." + String(p.suffix(2))
    }

    private var context: OfficialTariffContext {
        OfficialTariffContext.forItem(item, arabic: isArabic)
    }

    private var primaryOfficialDescription: String {
        if isArabic, let ar = clean(item.descriptionArabic) { return ar }
        if let en = clean(item.descriptionEnglish) { return en }
        return clean(item.descriptionArabic) ?? item.formattedCode
    }

    private var bilingualLeafDescription: String? {
        let ar = clean(item.descriptionArabic)
        let en = clean(item.descriptionEnglish)
        switch (ar, en) {
        case let (a?, e?) where a.lowercased() != e.lowercased(): return "\(a) | \(e)"
        case let (a?, _): return a
        case let (_, e?): return e
        default: return nil
        }
    }

    private var guidanceText: String {
        let isOther = (clean(item.descriptionEnglish)?.lowercased() == "other") || (clean(item.descriptionArabic) == "غيرها")
        if isOther {
            if let sub = context.subheadingTitle, let heading = context.headingTitle {
                return isArabic
                    ? "وصف هذا الرمز هو «غيرها». لذلك لا تُفهم دلالته من الكلمة وحدها؛ فهو يقع تحت \(sub)، ضمن \(heading). يجب مطابقة مواصفات السلعة مع هذا التسلسل والبنود الأكثر تحديداً قبله."
                    : "This tariff line is described as “Other”. Its scope cannot be understood from that word alone; it sits under \(sub), within \(heading). The product specifications must be matched against this hierarchy and any more specific preceding lines."
            }
            return isArabic
                ? "وصف هذا الرمز هو «غيرها». لا يتم تفسيره كفئة مستقلة؛ يجب قراءته مع البند \(headingCode) والبند الفرعي \(subheadingCode) ومطابقة مواصفات السلعة مع النص الرسمي."
                : "This tariff line is described as “Other”. It is not interpreted as a standalone category; read it together with heading \(headingCode) and subheading \(subheadingCode), then match the product specifications to the official wording."
        }

        if let desc = isArabic ? clean(item.descriptionArabic) : clean(item.descriptionEnglish) {
            return isArabic
                ? "الوصف الرسمي لهذا الرمز هو: «\(desc)». يستخدم هذا القسم لتوضيح موقع الرمز داخل التسلسل الجمركي فقط، دون إضافة أصناف أو استخدامات غير واردة في المصدر الرسمي."
                : "The official description of this code is: “\(desc)”. This section only clarifies the code's place in the tariff hierarchy and does not add products or uses that are not stated in the official source."
        }
        return isArabic ? "لا يوجد وصف رسمي كافٍ في قاعدة البيانات الحالية، لذلك لا يتم إنشاء شرح تخميني." : "The current dataset does not contain enough official description, so no speculative explanation is generated."
    }

    private var hasTradeAgreements: Bool {
        [item.indIndicator, item.eftaIndicator, item.sgIndicator, item.usaIndicator].contains { clean($0) != nil }
    }

    private func clean(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func copyCode() {
        ClipboardService.copy(item.normalizedCode)
        HapticFeedback.success()
        withAnimation { copiedCode = true }
        resetLater { copiedCode = false }
    }

    private func resetLater(_ block: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { block() } }
    }

    private func searchText() -> String {
        var parts = ["HS", item.normalizedCode]
        if let title = context.headingTitle { parts.append(title) }
        if let en = clean(item.descriptionEnglish), en.lowercased() != "other" { parts.append(en) }
        return parts.joined(separator: " ")
    }

    private func openImageSearch() {
        var c = URLComponents(string: "https://www.google.com/search")!
        c.queryItems = [URLQueryItem(name: "tbm", value: "isch"), URLQueryItem(name: "q", value: searchText())]
        if let url = c.url { openURL(url) }
    }

    private func openWebSearch() {
        var c = URLComponents(string: "https://www.google.com/search")!
        c.queryItems = [URLQueryItem(name: "q", value: searchText())]
        if let url = c.url { openURL(url) }
    }

    private func openOfficialSource() {
        if let url = URL(string: AppConfig.omanHSRequirementsURL) { openURL(url) }
    }

    private func quickActionLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(AppTypography.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(AppColors.brandPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(AppColors.brandPrimary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
    }

    private func compactLinkLabel(_ title: String, _ image: String) -> some View {
        Label(title, systemImage: image)
            .font(AppTypography.caption)
            .fontWeight(.semibold)
            .foregroundColor(AppColors.brandPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(AppColors.brandPrimary.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
    }

    private func descriptionRow(label: String, value: String, copied: Bool, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(AppTypography.caption2).foregroundColor(AppColors.textTertiary)
                Spacer()
                Button(action: action) {
                    Label(copied ? (isArabic ? "تم النسخ" : "Copied") : (isArabic ? "نسخ الوصف" : "Copy description"), systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(AppTypography.caption2)
                        .foregroundColor(AppColors.brandPrimary)
                }
            }
            Text(value)
                .font(AppTypography.body)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func detailRow(_ label: String, _ value: String?, emphasized: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(AppTypography.subheadline).foregroundColor(AppColors.textSecondary)
            Spacer()
            Text(value ?? "—")
                .font(emphasized ? AppTypography.headline : AppTypography.subheadline)
                .foregroundColor(emphasized ? AppColors.brandPrimary : AppColors.textPrimary)
                .multilineTextAlignment(.trailing)
                .preserveTechnicalLTR()
        }
    }

    private func navigationRow(_ title: String, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage).font(AppTypography.subheadline).fontWeight(.semibold)
            Spacer()
            Image(systemName: "chevron.forward").flipsForRightToLeftLayoutDirection(true)
        }.foregroundStyle(AppColors.brandPrimary)
    }

    @ViewBuilder private func agreementRow(_ label: String, _ value: String?) -> some View {
        if let value = clean(value) {
            HStack {
                Text(label).font(AppTypography.subheadline).foregroundColor(AppColors.textSecondary)
                Spacer()
                Text(value).font(AppTypography.subheadline).fontWeight(.semibold).foregroundColor(AppColors.textPrimary).preserveTechnicalLTR()
            }
        }
    }

    @ViewBuilder private func agreementDividerIfNeeded(after: String?, before: String?) -> some View {
        if clean(after) != nil && clean(before) != nil { Divider() }
    }

    private func actionTile(_ title: String, _ image: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { actionTileContent(title, image) }.buttonStyle(.plain)
    }

    private func actionTileContent(_ title: String, _ image: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: image).font(.title3)
            Text(title).font(AppTypography.caption).fontWeight(.semibold).multilineTextAlignment(.center)
        }
        .foregroundColor(AppColors.brandPrimary)
        .frame(maxWidth: .infinity, minHeight: 72)
        .background(AppColors.brandPrimary.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
    }

    @ViewBuilder
    private func statusDetailBadge(_ status: TariffStatus) -> some View {
        let content: (String, String, Color) = {
            switch status {
            case .normal: return ("checkmark.circle.fill", LanguageManager.shared.string(.statusNormal), AppColors.success)
            case .restricted: return ("exclamationmark.triangle.fill", LanguageManager.shared.string(.statusRestricted), AppColors.warning)
            case .prohibited: return ("nosign", LanguageManager.shared.string(.statusProhibited), AppColors.error)
            case .unknown: return ("questionmark.circle", LanguageManager.shared.string(.statusUnknown), AppColors.textTertiary)
            }
        }()
        HStack(spacing: 4) {
            Image(systemName: content.0)
            Text(content.1).font(AppTypography.caption)
        }
        .foregroundColor(content.2)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(content.2.opacity(0.12))
        .clipShape(Capsule())
    }
}

/// Official parent wording extracted from the supplied Oman Customs Tariff 2026.
/// No parent description is generated from general knowledge.
private struct OfficialTariffContext {
    let chapterTitle: String?
    let headingTitle: String?
    let subheadingTitle: String?

    static func forItem(_ item: HSCodeItem, arabic: Bool) -> OfficialTariffContext {
        func display(ar: String?, en: String?) -> String? {
            let arClean = ar?.trimmingCharacters(in: .whitespacesAndNewlines)
            let enClean = en?.trimmingCharacters(in: .whitespacesAndNewlines)
            if arabic {
                if let a = arClean, !a.isEmpty, let e = enClean, !e.isEmpty { return "\(a)\n\(e)" }
                if let a = arClean, !a.isEmpty { return a }
                return enClean
            } else {
                if let e = enClean, !e.isEmpty, let a = arClean, !a.isEmpty { return "\(e)\n\(a)" }
                if let e = enClean, !e.isEmpty { return e }
                return arClean
            }
        }

        return OfficialTariffContext(
            chapterTitle: display(ar: item.chapterDescriptionArabic, en: item.chapterDescriptionEnglish),
            headingTitle: display(ar: item.headingDescriptionArabic, en: item.headingDescriptionEnglish),
            subheadingTitle: (item.subheadingDescriptionArabic?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? display(ar: item.subheadingDescriptionArabic, en: item.subheadingDescriptionEnglish) : nil
        )
    }
}
