import SwiftUI

public struct CargoBoardView: View {
    @State private var store = CargoBoardStore.shared
    @State private var searchText = ""
    @State private var selectedFilter: CargoBoardFilter = .all

    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.large) {
                boardSummary
                filterStrip
                searchField

                if filteredShipments.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: AppSpacing.medium) {
                        ForEach(filteredShipments) { shipment in
                            NavigationLink {
                                ShipmentTrackingDetailView(shipmentID: shipment.id)
                            } label: {
                                CargoBoardShipmentCard(shipment: shipment)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer(minLength: AppSpacing.xxLarge)
            }
            .padding(AppSpacing.medium)
        }
        .background(AppColors.groupedBackground.ignoresSafeArea())
        .navigationTitle(LanguageManager.shared.string(.toolCargoBoard))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await store.refreshAll() }
                } label: {
                    if store.isRefreshing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .accessibilityLabel(LanguageManager.shared.string(.cargoBoardRefreshAll))
            }
        }
        .refreshable {
            await store.refreshAll()
        }
        .task {
            await store.refreshAll()
        }
    }

    private var filteredShipments: [CargoBoardShipment] {
        store.shipments.filter { shipment in
            let filterMatch = selectedFilter.matches(shipment.result.boardState)
            guard filterMatch else { return false }

            let query = AWBNormalizer.normalized(searchText)
            if !query.isEmpty {
                return shipment.result.awb.contains(query)
            }

            let textQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !textQuery.isEmpty else { return true }
            return (shipment.result.airline.airlineName ?? "").lowercased().contains(textQuery)
                || (shipment.result.airline.origin ?? "").lowercased().contains(textQuery)
                || (shipment.result.airline.destination ?? "").lowercased().contains(textQuery)
        }
    }

    private var boardSummary: some View {
        AppCard(padding: 0, cornerRadius: 24) {
            ZStack {
                LinearGradient(
                    colors: [AppColors.brandDeepNavy, AppColors.brandPrimary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(LanguageManager.shared.string(.cargoBoardActiveShipments))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.76))
                            Text("\(store.shipments.count)")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .preserveTechnicalLTR()
                        }
                        Spacer()
                        Image(systemName: "shippingbox.and.arrow.backward.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(AppColors.brandGold)
                    }

                    HStack(spacing: 8) {
                        summaryBadge(.cargoStateArrived, count: count(for: .arrived), color: AppColors.success)
                        summaryBadge(.cargoStatePartial, count: count(for: .partial), color: AppColors.warning)
                        summaryBadge(.cargoStateInTransit, count: count(for: .inTransit), color: Color.white.opacity(0.84))
                    }
                }
                .padding(AppSpacing.medium)
            }
        }
    }

    private func summaryBadge(_ key: LocalizedKey, count: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(count)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .preserveTechnicalLTR()
            Text(LanguageManager.shared.string(key))
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(color.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CargoBoardFilter.allCases) { filter in
                    Button {
                        HapticFeedback.selection()
                        selectedFilter = filter
                    } label: {
                        Text(filter.title)
                            .font(.system(size: 12, weight: selectedFilter == filter ? .bold : .semibold))
                            .foregroundStyle(selectedFilter == filter ? .white : AppColors.textSecondary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .background(selectedFilter == filter ? AppColors.brandPrimary : AppColors.cardBackground)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(AppColors.subtleBorder, lineWidth: selectedFilter == filter ? 0 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppColors.textTertiary)
            TextField(LanguageManager.shared.string(.cargoBoardSearchPlaceholder), text: $searchText)
                .font(AppTypography.body)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(AppColors.subtleBorder))
    }

    private var emptyState: some View {
        AppEmptyStateView(
            icon: "shippingbox",
            title: LanguageManager.shared.string(.cargoBoardEmptyTitle),
            description: LanguageManager.shared.string(.cargoBoardEmptyDescription)
        )
        .padding(.top, AppSpacing.large)
    }

    private func count(for state: CargoArrivalState) -> Int {
        store.shipments.filter { $0.result.boardState == state }.count
    }
}

private enum CargoBoardFilter: String, CaseIterable, Identifiable {
    case all
    case arrived
    case partial
    case inTransit
    case notArrived

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return LanguageManager.shared.string(.cargoBoardFilterAll)
        case .arrived: return LanguageManager.shared.string(.cargoStateArrived)
        case .partial: return LanguageManager.shared.string(.cargoStatePartial)
        case .inTransit: return LanguageManager.shared.string(.cargoStateInTransit)
        case .notArrived: return LanguageManager.shared.string(.cargoStateNotArrived)
        }
    }

    func matches(_ state: CargoArrivalState) -> Bool {
        switch self {
        case .all: return true
        case .arrived: return state == .arrived
        case .partial: return state == .partial
        case .inTransit: return state == .inTransit
        case .notArrived: return state == .notArrived
        }
    }
}

private struct CargoBoardShipmentCard: View {
    let shipment: CargoBoardShipment

    var body: some View {
        AppCard(cornerRadius: 20) {
            VStack(spacing: 11) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(AWBNormalizer.formatted(shipment.result.awb))
                            .font(AppTypography.technicalNumberMedium)
                            .foregroundStyle(AppColors.textPrimary)
                            .preserveTechnicalLTR()
                        Text(shipment.result.airline.airlineName ?? LanguageManager.shared.string(.trackingAirlineUnknown))
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    Spacer()
                    boardStatePill(shipment.result.boardState)
                }

                if let origin = shipment.result.airline.origin,
                   let destination = shipment.result.airline.destination {
                    HStack(spacing: 12) {
                        Text(origin)
                            .font(AppTypography.technicalNumberSmall)
                        Image(systemName: "arrow.right")
                            .foregroundStyle(AppColors.textTertiary)
                        Text(destination)
                            .font(AppTypography.technicalNumberSmall)
                        Spacer()
                    }
                    .foregroundStyle(AppColors.textPrimary)
                    .preserveTechnicalLTR()
                }

                HStack(spacing: 16) {
                    if let received = shipment.result.transom.receivedPieces {
                        infoChip(icon: "shippingbox.fill", text: "\(received) PCS")
                    } else if let pieces = shipment.result.airline.pieces {
                        infoChip(icon: "shippingbox.fill", text: "\(pieces) PCS")
                    }

                    if let weight = shipment.result.transom.weightKg ?? shipment.result.airline.weightKg {
                        infoChip(icon: "scalemass.fill", text: "\(NSDecimalNumber(decimal: weight).stringValue) KG")
                    }

                    Spacer(minLength: 0)

                    Text(timeText(shipment.result.updatedAt))
                        .font(AppTypography.caption2)
                        .foregroundStyle(AppColors.textTertiary)
                }

                if let short = shipment.result.transom.shortLandedPieces, short > 0 {
                    HStack(spacing: 7) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(LanguageManager.shared.string(.trackingShortLandCount, short))
                        Spacer()
                    }
                    .font(AppTypography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.warning)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(AppColors.warning.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    private func infoChip(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
            Text(text).preserveTechnicalLTR()
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(AppColors.textSecondary)
    }

    private func boardStatePill(_ state: CargoArrivalState) -> some View {
        let title: String
        let color: Color
        switch state {
        case .arrived:
            title = LanguageManager.shared.string(.cargoStateArrived)
            color = AppColors.success
        case .partial:
            title = LanguageManager.shared.string(.cargoStatePartial)
            color = AppColors.warning
        case .inTransit:
            title = LanguageManager.shared.string(.cargoStateInTransit)
            color = AppColors.brandPrimary
        case .notArrived:
            title = LanguageManager.shared.string(.cargoStateNotArrived)
            color = AppColors.textSecondary
        case .unknown:
            title = LanguageManager.shared.string(.cargoStateUnknown)
            color = AppColors.textTertiary
        }

        return Text(title)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color.opacity(0.10))
            .clipShape(Capsule())
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = LanguageManager.shared.currentLanguage.locale
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

struct ShipmentTrackingDetailView: View {
    @State private var store = CargoBoardStore.shared
    @State private var selectedTab: ShipmentDetailTab = .updates
    @State private var selectedSource: ShipmentEventSourceFilter = .all

    private let shipmentID: UUID?
    private let directResult: AirCargoTrackingResult?

    init(shipmentID: UUID) {
        self.shipmentID = shipmentID
        self.directResult = nil
    }

    init(result: AirCargoTrackingResult) {
        self.shipmentID = nil
        self.directResult = result
    }

    private var shipment: CargoBoardShipment? {
        guard let shipmentID else { return nil }
        return store.shipments.first { $0.id == shipmentID }
    }

    private var result: AirCargoTrackingResult? {
        shipment?.result ?? directResult
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            if let result {
                VStack(spacing: AppSpacing.medium) {
                    shipmentHeader(result)
                    detailTabs

                    switch selectedTab {
                    case .updates:
                        updatesTab(result)
                    case .flight:
                        flightTab(result)
                    case .shipment:
                        shipmentTab(result)
                    }

                    sourceLinks(result)

                    if let shipmentID {
                        AppButton(t("تحديث هذه الشحنة", "Refresh this shipment"), icon: "arrow.clockwise", isLoading: store.isRefreshing) {
                            Task { await store.refresh(id: shipmentID) }
                        }

                        AppButton(LanguageManager.shared.string(.cargoBoardRemoveShipment), icon: "trash", style: .destructive) {
                            store.remove(id: shipmentID)
                        }
                    }
                }
                .padding(AppSpacing.medium)
            }
        }
        .background(AppColors.groupedBackground.ignoresSafeArea())
        .navigationTitle(t("تفاصيل الشحنة", "Shipment Details"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private func shipmentHeader(_ result: AirCargoTrackingResult) -> some View {
        let events = sourcedEvents(result)
        let current = events.first
        let route = routeCodes(result)
        let pieces = result.transom.receivedPieces ?? result.airline.pieces
        let weight = result.transom.weightKg ?? result.airline.weightKg

        return AppCard(padding: 0, cornerRadius: 24) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AppColors.brandPrimary.opacity(0.10))
                                .frame(width: 54, height: 54)
                            Image(systemName: "airplane")
                                .font(.system(size: 23, weight: .bold))
                                .foregroundStyle(AppColors.brandPrimary)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(AWBNormalizer.formatted(result.awb))
                                .font(AppTypography.technicalNumberMedium)
                                .foregroundStyle(AppColors.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.68)
                                .allowsTightening(true)
                                .layoutPriority(2)
                                .preserveTechnicalLTR()
                            Text(result.airline.airlineName ?? LanguageManager.shared.string(.trackingAirlineUnknown))
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                            if let current {
                                Text(simplifiedTitle(current.event))
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(statusColor(current.event))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(statusColor(current.event).opacity(0.10))
                                    .clipShape(Capsule())

                                Text(t("آخر تحديث — \(compactSourceTitle(current.sourceLabel))", "Latest — \(compactSourceTitle(current.sourceLabel))"))
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(AppColors.textTertiary)
                                    .lineLimit(1)
                            } else if let status = result.transom.status ?? result.airline.status {
                                Text(status)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }

                        Spacer(minLength: 0)

                        VStack(alignment: .trailing, spacing: 7) {
                            Text(t("مصادر التتبع", "Tracking Sources"))
                                .font(AppTypography.caption2)
                                .foregroundStyle(AppColors.textSecondary)
                            sourceStatusLine(
                                title: compactSourceTitle(airlineSourceLabel(result.airline, includeCarrierWhenAggregated: false)),
                                state: result.airline.sourceState,
                                icon: "airplane"
                            )
                            sourceStatusLine(title: "Transom", state: result.transom.sourceState, icon: "building.2.fill")
                        }
                    }

                    if !route.isEmpty {
                        HStack(spacing: 7) {
                            ForEach(Array(route.enumerated()), id: \.offset) { index, code in
                                Text(code)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppColors.textPrimary)
                                    .preserveTechnicalLTR()
                                if index < route.count - 1 {
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(AppColors.textTertiary)
                                }
                            }
                            Spacer()
                        }
                        // Airport routes are technical left-to-right data even when the app UI is Arabic.
                        // Keeping this row LTR prevents LHR → MCT from being visually reversed to MCT → LHR.
                        .environment(\.layoutDirection, .leftToRight)
                    }

                    HStack(spacing: 14) {
                        if let pieces {
                            compactInfo(icon: "shippingbox.fill", value: "\(pieces) \(t("قطعة", "PCS"))")
                        }
                        if let weight {
                            compactInfo(icon: "scalemass.fill", value: "\(NSDecimalNumber(decimal: weight).stringValue) KG")
                        }
                        Spacer(minLength: 0)
                        if let timestamp = current?.event.timestamp {
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(t("آخر تحديث", "Latest event"))
                                    .font(AppTypography.caption2)
                                    .foregroundStyle(AppColors.textTertiary)
                                Text(timestamp)
                                    .font(AppTypography.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(AppColors.textSecondary)
                                    .preserveTechnicalLTR()
                            }
                        }
                    }
                }
                .padding(AppSpacing.medium)
            }
        }
    }

    private func sourceStatusLine(title: String, state: TrackingSourceState, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: state == .live ? "checkmark.circle.fill" : (state == .unavailable ? "xmark.circle.fill" : "clock.fill"))
                .foregroundStyle(state == .live ? AppColors.success : (state == .unavailable ? AppColors.error : AppColors.warning))
            Image(systemName: icon)
                .foregroundStyle(AppColors.textSecondary)
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .allowsTightening(true)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func airlineSourceLabel(_ snapshot: AirlineTrackingSnapshot, includeCarrierWhenAggregated: Bool) -> String {
        let carrier = snapshot.airlineName ?? t("شركة الطيران", "Airline")
        guard snapshot.dataSourceKind == .aggregator else { return carrier }
        let source = snapshot.dataSourceName ?? "Track-Trace"
        return includeCarrierWhenAggregated ? "\(carrier) • \(source)" : source
    }

    private func compactSourceTitle(_ title: String) -> String {
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = normalized.lowercased()
        if lower.contains("track-trace") || lower.contains("delivery tracker") {
            return normalized
                .replacingOccurrences(of: " Cargo", with: "", options: [.caseInsensitive])
                .replacingOccurrences(of: "SkyCargo", with: "", options: [.caseInsensitive])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if lower.contains("oman air") { return "Oman Air" }
        if lower.contains("qatar airways") { return "Qatar Airways" }
        if lower.contains("emirates") { return "Emirates" }
        if lower.contains("turkish") { return "Turkish" }
        if lower.contains("transom") { return "Transom" }
        if lower.contains("saudia") { return "Saudia" }
        if lower.contains("etihad") { return "Etihad" }
        if lower.contains("lufthansa") { return "Lufthansa" }
        if lower.contains("cargolux") { return "Cargolux" }
        if lower.contains("ethiopian") { return "Ethiopian" }
        if lower.contains("gulf air") { return "Gulf Air" }
        if lower.contains("cathay") { return "Cathay" }
        if lower.contains("singapore") { return "Singapore" }
        if lower.contains("air france") { return "Air France" }
        if lower.contains("klm") { return "KLM" }
        if lower.contains("british airways") { return "British Airways" }
        if lower.contains("air india") { return "Air India" }
        if lower.contains("kuwait") { return "Kuwait Airways" }
        if lower.contains("air arabia") { return "Air Arabia" }
        if lower.contains("salamair") || lower.contains("salam air") { return "SalamAir" }
        return normalized
            .replacingOccurrences(of: " Cargo", with: "", options: [.caseInsensitive])
            .replacingOccurrences(of: "SkyCargo", with: "", options: [.caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func compactInfo(icon: String, value: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppColors.textTertiary)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
                .preserveTechnicalLTR()
        }
    }

    // MARK: - Tabs

    private var detailTabs: some View {
        HStack(spacing: 6) {
            ForEach(ShipmentDetailTab.allCases) { tab in
                Button {
                    HapticFeedback.selection()
                    selectedTab = tab
                } label: {
                    VStack(spacing: 7) {
                        HStack(spacing: 5) {
                            Image(systemName: tab.icon)
                            Text(tab.title)
                                .lineLimit(1)
                        }
                        .font(.system(size: 12, weight: selectedTab == tab ? .bold : .semibold))
                        .foregroundStyle(selectedTab == tab ? AppColors.brandPrimary : AppColors.textSecondary)

                        Capsule()
                            .fill(selectedTab == tab ? AppColors.brandPrimary : Color.clear)
                            .frame(height: 3)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(AppColors.subtleBorder))
    }

    // MARK: - Updates

    @ViewBuilder
    private func updatesTab(_ result: AirCargoTrackingResult) -> some View {
        let all = sourcedEvents(result)
        let visible = all.filter { selectedSource.matches($0.source) }

        VStack(spacing: AppSpacing.medium) {
            eventSourceFilter(result)

            if visible.isEmpty {
                AppCard(cornerRadius: 20) {
                    VStack(spacing: 9) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(AppColors.textTertiary)
                        Text(t("لا توجد أحداث تفصيلية من هذا المصدر حتى الآن", "No detailed events are available from this source yet"))
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
            } else {
                AppCard(cornerRadius: 22) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t("جميع التحديثات", "All Updates"))
                                    .font(AppTypography.headline)
                                Text(t("\(visible.count) حدث موثّق من المصدر", "\(visible.count) verified source events"))
                                    .font(AppTypography.caption2)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(AppColors.brandPrimary)
                        }
                        .padding(.bottom, 12)

                        ForEach(Array(visible.enumerated()), id: \.offset) { index, item in
                            trackingEventRow(item, isCurrent: index == 0, showConnector: index < visible.count - 1)
                        }
                    }
                }
            }

            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(AppColors.success)
                Text(t(
                    "العنوان العربي لتسهيل الفهم، والنص الإنجليزي أسفله هو الحدث كما ورد من مصدر التتبع. لا يتم إنشاء أحداث غير موجودة في المصدر.",
                    "The simplified label helps readability. The source event wording is preserved below it, and no milestone is invented by the app."
                ))
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .padding(12)
            .background(AppColors.success.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
    }

    private func eventSourceFilter(_ result: AirCargoTrackingResult) -> some View {
        HStack(spacing: 7) {
            ForEach(ShipmentEventSourceFilter.allCases) { filter in
                let enabled = filter != .airline || result.airline.sourceState == .live || !(result.airline.recentEvents ?? []).isEmpty
                let transomEnabled = filter != .transom || result.transom.sourceState == .live || !(result.transom.recentEvents ?? []).isEmpty
                Button {
                    selectedSource = filter
                } label: {
                    Text(filter.title)
                        .font(.system(size: 11, weight: selectedSource == filter ? .bold : .semibold))
                        .foregroundStyle(selectedSource == filter ? .white : AppColors.textSecondary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(selectedSource == filter ? AppColors.brandPrimary : AppColors.cardBackground)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppColors.subtleBorder, lineWidth: selectedSource == filter ? 0 : 1))
                }
                .buttonStyle(.plain)
                .disabled(!(enabled && transomEnabled))
                .opacity((enabled && transomEnabled) ? 1 : 0.45)
            }
        }
    }

    private func trackingEventRow(_ item: SourcedTrackingEvent, isCurrent: Bool, showConnector: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(isCurrent ? statusColor(item.event) : AppColors.brandPrimary)
                        .frame(width: 34, height: 34)
                    Image(systemName: eventIcon(item.event))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                if showConnector {
                    Rectangle()
                        .fill(AppColors.subtleBorder)
                        .frame(width: 2, height: 62)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(simplifiedTitle(item.event))
                        .font(.system(size: 14, weight: isCurrent ? .bold : .semibold))
                        .foregroundStyle(isCurrent ? statusColor(item.event) : AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    if isCurrent {
                        Text(t("الحالي", "CURRENT"))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(AppColors.success)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(AppColors.success.opacity(0.10))
                            .clipShape(Capsule())
                    }
                }

                if LanguageManager.shared.currentLanguage == .arabic,
                   simplifiedTitle(item.event) != item.event.title {
                    Text(item.event.title)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .preserveTechnicalLTR()
                }

                HStack(spacing: 7) {
                    sourceBadge(item)
                    if let code = item.event.code, !code.isEmpty {
                        miniBadge(code)
                    }
                    if let flight = item.event.flightNumber ?? flightFromTitle(item.event.title) {
                        miniBadge(flight)
                    }
                }

                if let meta = eventMeta(item.event) {
                    Text(meta)
                        .font(AppTypography.caption2)
                        .foregroundStyle(AppColors.textTertiary)
                        .preserveTechnicalLTR()
                }
            }
            .padding(.bottom, showConnector ? 8 : 0)
        }
    }

    private func sourceBadge(_ item: SourcedTrackingEvent) -> some View {
        Text(item.sourceLabel)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(item.source == .transom ? AppColors.warning : AppColors.brandPrimary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background((item.source == .transom ? AppColors.warning : AppColors.brandPrimary).opacity(0.08))
            .clipShape(Capsule())
    }

    private func miniBadge(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(AppColors.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(AppColors.innerCardBackground)
            .clipShape(Capsule())
            .preserveTechnicalLTR()
    }

    // MARK: - Flight details

    @ViewBuilder
    private func flightTab(_ result: AirCargoTrackingResult) -> some View {
        let legs = flightLegs(result)
        VStack(spacing: AppSpacing.medium) {
            if !routeCodes(result).isEmpty {
                AppCard(cornerRadius: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(t("مسار الشحنة", "Shipment Route"))
                            .font(AppTypography.headline)
                        Text(routeCodes(result).joined(separator: "  →  "))
                            .font(AppTypography.technicalNumberMedium)
                            .foregroundStyle(AppColors.brandPrimary)
                            .preserveTechnicalLTR()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if legs.isEmpty {
                AppCard(cornerRadius: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(t("تفاصيل الرحلة", "Flight Details"))
                            .font(AppTypography.headline)
                        detailRow(t("رقم الرحلة", "Flight"), result.airline.flightNumber)
                        detailRow(t("المغادرة", "Departure"), result.airline.departure)
                        detailRow(t("الوصول", "Arrival"), result.airline.arrival)
                        if result.airline.flightNumber == nil && result.airline.departure == nil && result.airline.arrival == nil {
                            Text(t("شركة الطيران لم توفر تفاصيل رحلة إضافية في البيانات التي تم قراءتها.", "The airline did not expose additional flight details in the captured tracking data."))
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                }
            } else {
                ForEach(legs) { leg in
                    AppCard(cornerRadius: 20) {
                        VStack(alignment: .leading, spacing: 11) {
                            HStack {
                                Image(systemName: "airplane")
                                    .foregroundStyle(AppColors.brandPrimary)
                                Text(leg.flightNumber)
                                    .font(AppTypography.technicalNumberMedium)
                                    .preserveTechnicalLTR()
                                Spacer()
                                Text(leg.sourceLabel)
                                    .font(AppTypography.caption2)
                                    .foregroundStyle(AppColors.textSecondary)
                            }

                            if leg.origin != nil || leg.destination != nil {
                                Text([leg.origin, leg.destination].compactMap { $0 }.joined(separator: "  →  "))
                                    .font(AppTypography.technicalNumberSmall)
                                    .foregroundStyle(AppColors.textPrimary)
                                    .preserveTechnicalLTR()
                            }
                            detailRow(t("المغادرة", "Departure"), leg.departure)
                            detailRow(t("الوصول", "Arrival"), leg.arrival)
                        }
                    }
                }
            }

            if result.transom.sourceState == .live,
               result.transom.flightNumber != nil || result.transom.flightDate != nil {
                AppCard(cornerRadius: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "building.2.fill")
                                .foregroundStyle(AppColors.warning)
                            Text(t("تأكيد Transom", "Transom Confirmation"))
                                .font(AppTypography.headline)
                            Spacer()
                        }
                        detailRow(t("الرحلة", "Flight"), result.transom.flightNumber)
                        detailRow(t("تاريخ الرحلة", "Flight Date"), result.transom.flightDate)
                        detailRow(t("المسار", "Route"), routeText(origin: result.transom.origin, destination: result.transom.destination))
                    }
                }
            }
        }
    }

    // MARK: - Shipment details

    private func shipmentTab(_ result: AirCargoTrackingResult) -> some View {
        VStack(spacing: AppSpacing.medium) {
            AppCard(cornerRadius: 20) {
                VStack(alignment: .leading, spacing: 11) {
                    sectionTitle(icon: "shippingbox.fill", title: t("بيانات الشحنة", "Shipment Information"))
                    detailRow("AWB", AWBNormalizer.formatted(result.awb))
                    detailRow(t("شركة الطيران", "Airline"), result.airline.airlineName)
                    detailRow(t("المنشأ", "Origin"), result.airline.origin ?? result.transom.origin)
                    detailRow(t("الوجهة", "Destination"), result.airline.destination ?? result.transom.destination)
                    detailRow(t("عدد القطع", "Pieces"), result.airline.pieces.map(String.init))
                    detailRow(t("الوزن", "Weight"), result.airline.weightKg.map { "\(NSDecimalNumber(decimal: $0).stringValue) KG" })
                    detailRow(t("حالة شركة الطيران", "Airline Status"), result.airline.status)
                    detailRow(t("آخر حدث رسمي", "Latest Airline Event"), result.airline.lastEvent)
                }
            }

            AppCard(cornerRadius: 20) {
                VStack(alignment: .leading, spacing: 11) {
                    sectionTitle(icon: "building.2.fill", title: "Transom Cargo")
                    detailRow(t("حالة الوصول", "Arrival Status"), stateText(result.transom.arrivalState))
                    detailRow(t("القطع المستلمة", "Received Pieces"), receivedText(result.transom))
                    detailRow(t("القطع الناقصة", "Short Landed"), result.transom.shortLandedPieces.map(String.init))
                    detailRow(t("الوزن", "Weight"), result.transom.weightKg.map { "\(NSDecimalNumber(decimal: $0).stringValue) KG" })
                    detailRow(t("الرحلة", "Flight"), result.transom.flightNumber)
                    detailRow(t("تاريخ الرحلة", "Flight Date"), result.transom.flightDate)
                    detailRow(t("المسار", "Route"), routeText(origin: result.transom.origin, destination: result.transom.destination))
                    detailRow(t("استيراد/تصدير", "Import / Export"), result.transom.importExport)
                    detailRow(t("الوكيل", "Agent"), result.transom.agent)
                    detailRow(t("حالة Transom", "Transom Status"), result.transom.status)
                    detailRow(t("آخر حدث Transom", "Latest Transom Event"), result.transom.lastEvent)
                }
            }
        }
    }

    private func sectionTitle(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(AppColors.brandPrimary)
            Text(title)
                .font(AppTypography.headline)
            Spacer()
        }
    }

    @ViewBuilder
    private func detailRow(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(label)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
                Text(value)
                    .font(AppTypography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.trailing)
                    .preserveTechnicalLTR()
            }
            Divider()
        }
    }

    // MARK: - Source actions

    @ViewBuilder
    private func sourceLinks(_ result: AirCargoTrackingResult) -> some View {
        if result.airline.sourceURL != nil || result.transom.sourceURL != nil {
            AppCard(cornerRadius: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(t("مصادر التتبع", "Tracking Sources"))
                        .font(AppTypography.headline)
                    if let url = result.airline.sourceURL {
                        Link(destination: url) {
                            sourceLinkRow(icon: "airplane", title: airlineSourceLabel(result.airline, includeCarrierWhenAggregated: true))
                        }
                    }
                    if let url = result.transom.sourceURL {
                        Link(destination: url) {
                            sourceLinkRow(icon: "building.2.fill", title: "Transom Cargo")
                        }
                    }
                }
            }
        }
    }

    private func sourceLinkRow(icon: String, title: String) -> some View {
        HStack {
            Image(systemName: icon)
            Text(title)
            Spacer()
            Text(t("فتح المصدر", "Open Source"))
                .font(AppTypography.caption)
            Image(systemName: "arrow.up.right")
        }
        .font(AppTypography.subheadline)
        .fontWeight(.semibold)
        .foregroundStyle(AppColors.brandPrimary)
        .padding(.vertical, 4)
    }

    // MARK: - Event and route helpers

    private func sourcedEvents(_ result: AirCargoTrackingResult) -> [SourcedTrackingEvent] {
        var items: [SourcedTrackingEvent] = []
        let airlineName = airlineSourceLabel(result.airline, includeCarrierWhenAggregated: true)

        let airlineEvents: [TrackingEvent] = {
            if let events = result.airline.recentEvents, !events.isEmpty { return events }
            if let fallback = result.airline.lastEvent, !fallback.isEmpty { return [TrackingEvent(title: fallback)] }
            return []
        }()
        items += airlineEvents.enumerated().map {
            SourcedTrackingEvent(source: .airline, sourceLabel: airlineName, event: $0.element, sourceOrder: $0.offset)
        }

        let transomEvents: [TrackingEvent] = {
            if let events = result.transom.recentEvents, !events.isEmpty { return events }
            if let fallback = result.transom.lastEvent, !fallback.isEmpty { return [TrackingEvent(title: fallback)] }
            return []
        }()
        items += transomEvents.enumerated().map {
            SourcedTrackingEvent(source: .transom, sourceLabel: "Transom Cargo", event: $0.element, sourceOrder: $0.offset)
        }

        return items.sorted { lhs, rhs in
            let ld = parsedEventDate(lhs.event.timestamp)
            let rd = parsedEventDate(rhs.event.timestamp)
            if let ld, let rd, ld != rd { return ld > rd }
            if ld != nil && rd == nil { return true }
            if ld == nil && rd != nil { return false }
            if lhs.source == rhs.source { return lhs.sourceOrder < rhs.sourceOrder }
            return lhs.source == .airline
        }
    }

    private func routeCodes(_ result: AirCargoTrackingResult) -> [String] {
        var values: [String] = []
        func append(_ code: String?) {
            guard let code = code?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                  code.count == 3, !values.contains(code) else { return }
            values.append(code)
        }

        append(result.airline.origin ?? result.transom.origin)
        let airlineEvents = result.airline.recentEvents ?? []
        for event in airlineEvents.reversed() { append(event.location) }
        append(result.airline.destination ?? result.transom.destination)
        return values
    }

    private func flightLegs(_ result: AirCargoTrackingResult) -> [ShipmentFlightLeg] {
        let airlineName = airlineSourceLabel(result.airline, includeCarrierWhenAggregated: true)
        let events = result.airline.recentEvents ?? []
        var order: [String] = []
        var groups: [String: [TrackingEvent]] = [:]

        for event in events.reversed() {
            guard let flight = event.flightNumber ?? flightFromTitle(event.title), !flight.isEmpty else { continue }
            if groups[flight] == nil { order.append(flight) }
            groups[flight, default: []].append(event)
        }

        var legs = order.compactMap { flight -> ShipmentFlightLeg? in
            guard let group = groups[flight] else { return nil }
            let departureEvent = group.first(where: { eventKind($0) == .departed })
            let arrivalEvent = group.last(where: { let kind = eventKind($0); return kind == .arrived || kind == .received })
            let origin = departureEvent?.location
            let destination = arrivalEvent?.location
            return ShipmentFlightLeg(
                flightNumber: flight,
                origin: origin,
                destination: destination,
                departure: departureEvent?.timestamp,
                arrival: arrivalEvent?.timestamp,
                sourceLabel: airlineName
            )
        }

        if legs.isEmpty, let flight = result.airline.flightNumber {
            legs = [ShipmentFlightLeg(
                flightNumber: flight,
                origin: result.airline.origin,
                destination: result.airline.destination,
                departure: result.airline.departure,
                arrival: result.airline.arrival,
                sourceLabel: airlineName
            )]
        }
        return legs
    }

    private func eventMeta(_ event: TrackingEvent) -> String? {
        let values = [event.location, event.timestamp].compactMap { value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        return values.isEmpty ? nil : values.joined(separator: " • ")
    }

    private func simplifiedTitle(_ event: TrackingEvent) -> String {
        guard LanguageManager.shared.currentLanguage == .arabic else { return event.title }
        let lower = event.title.lowercased()

        if lower.contains("notified consignee") || lower.contains("consignee notified") { return "تم إشعار المستلم" }
        if lower.contains("shipment notified for delivery") { return "تم إشعار الشحنة للتسليم" }
        if lower.contains("shipment ready for delivery") || lower.contains("ready for collection") { return "الشحنة جاهزة للتسليم" }
        if lower.contains("received at destination") { return "تم استلام الشحنة في الوجهة" }
        if lower.contains("shipment received from flight") { return "تم استلام الشحنة من الرحلة" }
        if lower.contains("received in"), let location = event.location { return "تم استلام الشحنة في \(location)" }
        if lower.contains("flight arrival") { return "وصلت الرحلة" }
        if lower.contains("arrived"), let location = event.location { return "وصلت الشحنة إلى \(location)" }
        if lower.contains("arrived") { return "وصلت الشحنة" }
        if lower.contains("departed"), let location = event.location { return "غادرت الشحنة من \(location)" }
        if lower.contains("departed") { return "غادرت الشحنة" }
        if lower.contains("document released") { return "تم الإفراج عن مستندات الشحنة" }
        if lower.contains("customs released") { return "تم الإفراج الجمركي" }
        if lower.contains("delivered") { return "تم تسليم الشحنة" }
        if lower.contains("accepted") { return "تم قبول الشحنة من الناقل" }
        if lower.contains("manifested") { return "تم تسجيل الشحنة على الرحلة" }
        if lower.contains("booked") { return "تم حجز الشحنة" }
        if lower.contains("in transit") { return "الشحنة قيد النقل" }

        switch event.code?.uppercased() {
        case "NFD": return "تم إشعار الشحنة للتسليم"
        case "NTF": return "تم إشعار المستلم"
        case "BRK": return "تم تفريغ الشحنة من وحدة التحميل"
        case "MAN": return "تم تسجيل الشحنة على الرحلة"
        case "RFD": return "الشحنة جاهزة للتسليم"
        case "RCF": return "تم استلام الشحنة"
        case "DLV": return "تم تسليم الشحنة"
        case "DOC": return "تم الإفراج عن مستندات الشحنة"
        case "ARR": return "وصلت الشحنة"
        case "DEP": return "غادرت الشحنة"
        case "RCS": return "تم قبول الشحنة من الناقل"
        case "BKD": return "تم حجز الشحنة"
        case "TRN": return "الشحنة قيد النقل"
        default: return event.title
        }
    }

    private func statusColor(_ event: TrackingEvent) -> Color {
        let lower = event.title.lowercased()
        if event.code?.uppercased() == "DLV" || lower.contains("delivered") { return AppColors.success }
        if event.code?.uppercased() == "NFD" || event.code?.uppercased() == "RFD" || lower.contains("ready for delivery") || lower.contains("notified consignee") { return AppColors.success }
        if event.code?.uppercased() == "DOC" || lower.contains("document released") { return AppColors.warning }
        return AppColors.brandPrimary
    }

    private func eventIcon(_ event: TrackingEvent) -> String {
        switch eventKind(event) {
        case .delivered: return "checkmark"
        case .ready: return "bell.fill"
        case .arrived: return "airplane.arrival"
        case .departed: return "airplane.departure"
        case .received: return "shippingbox.fill"
        case .released: return "doc.text.fill"
        case .accepted: return "checkmark.circle.fill"
        case .booked: return "calendar.badge.checkmark"
        case .transit: return "arrow.triangle.swap"
        case .other: return "circle.fill"
        }
    }

    private func eventKind(_ event: TrackingEvent) -> ShipmentEventKind {
        let code = event.code?.uppercased()
        let lower = event.title.lowercased()
        if code == "DLV" || lower.contains("delivered") { return .delivered }
        if code == "NFD" || code == "RFD" || lower.contains("ready for delivery") || lower.contains("notified consignee") { return .ready }
        if code == "DOC" || code == "REL" || lower.contains("released") { return .released }
        if code == "ARR" || lower.contains("arrived") || lower.contains("flight arrival") { return .arrived }
        if code == "DEP" || lower.contains("departed") { return .departed }
        if code == "RCF" || lower.contains("received") { return .received }
        if code == "RCS" || lower.contains("accepted") { return .accepted }
        if code == "BKD" || lower.contains("booked") { return .booked }
        if code == "TRN" || lower.contains("transit") { return .transit }
        return .other
    }

    private func flightFromTitle(_ title: String) -> String? {
        let pattern = #"\b[A-Z]{2}\s*[- ]?\d{3,4}\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(title.startIndex..<title.endIndex, in: title)
        guard let match = regex.matches(in: title, range: range).last,
              let swiftRange = Range(match.range, in: title) else { return nil }
        return title[swiftRange]
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .uppercased()
    }

    private func parsedEventDate(_ value: String?) -> Date? {
        TrackingEventTimestamp.parse(value)
    }

    private func routeText(origin: String?, destination: String?) -> String? {
        guard let origin, let destination, !origin.isEmpty, !destination.isEmpty else { return nil }
        return "\(origin) → \(destination)"
    }

    private func receivedText(_ snapshot: TransomTrackingSnapshot) -> String? {
        if let received = snapshot.receivedPieces, let expected = snapshot.expectedPieces {
            return "\(received) / \(expected)"
        }
        return snapshot.receivedPieces.map(String.init)
    }

    private func stateText(_ state: CargoArrivalState) -> String {
        switch state {
        case .arrived: return LanguageManager.shared.string(.cargoStateArrived)
        case .partial: return LanguageManager.shared.string(.cargoStatePartial)
        case .inTransit: return LanguageManager.shared.string(.cargoStateInTransit)
        case .notArrived: return LanguageManager.shared.string(.cargoStateNotArrived)
        case .unknown: return LanguageManager.shared.string(.cargoStateUnknown)
        }
    }

    private func t(_ ar: String, _ en: String) -> String {
        LanguageManager.shared.currentLanguage == .arabic ? ar : en
    }
}

private enum ShipmentDetailTab: String, CaseIterable, Identifiable {
    case updates
    case flight
    case shipment

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .updates: return "clock.arrow.circlepath"
        case .flight: return "airplane"
        case .shipment: return "shippingbox"
        }
    }
    var title: String {
        let ar = LanguageManager.shared.currentLanguage == .arabic
        switch self {
        case .updates: return ar ? "التحديثات" : "Updates"
        case .flight: return ar ? "تفاصيل الرحلة" : "Flight Details"
        case .shipment: return ar ? "تفاصيل الشحنة" : "Shipment Details"
        }
    }
}

private enum ShipmentEventSource: String {
    case airline
    case transom
}

private enum ShipmentEventSourceFilter: String, CaseIterable, Identifiable {
    case all
    case airline
    case transom

    var id: String { rawValue }
    var title: String {
        let ar = LanguageManager.shared.currentLanguage == .arabic
        switch self {
        case .all: return ar ? "الكل" : "All"
        case .airline: return ar ? "شركة الطيران" : "Airline"
        case .transom: return "Transom"
        }
    }
    func matches(_ source: ShipmentEventSource) -> Bool {
        switch self {
        case .all: return true
        case .airline: return source == .airline
        case .transom: return source == .transom
        }
    }
}

private struct SourcedTrackingEvent: Identifiable {
    let source: ShipmentEventSource
    let sourceLabel: String
    let event: TrackingEvent
    let sourceOrder: Int
    var id: String {
        [source.rawValue, String(sourceOrder), event.code ?? "", event.title, event.location ?? "", event.timestamp ?? ""].joined(separator: "|")
    }
}

private struct ShipmentFlightLeg: Identifiable {
    let flightNumber: String
    let origin: String?
    let destination: String?
    let departure: String?
    let arrival: String?
    let sourceLabel: String
    var id: String { [flightNumber, origin ?? "", destination ?? "", departure ?? "", arrival ?? ""].joined(separator: "|") }
}

private enum ShipmentEventKind {
    case delivered
    case ready
    case arrived
    case departed
    case received
    case released
    case accepted
    case booked
    case transit
    case other
}
