import SwiftUI

public struct AirCargoTrackingView: View {
    @State private var viewModel = AirCargoTrackingViewModel()
    @FocusState private var isAWBFocused: Bool

    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.large) {
                trackingEntryCard

                if let errorKey = viewModel.errorKey {
                    inlineError(LanguageManager.shared.string(errorKey))
                }

                if let result = viewModel.result {
                    resultHeader(result)
                    if viewModel.isUpdatingSecondarySource {
                        progressiveUpdateNotice
                    }
                    trackingSummaryCard(result)
                    trackingPreview(result)
                    NavigationLink {
                        ShipmentTrackingDetailView(result: result)
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: "list.bullet.rectangle.portrait.fill")
                            Text(LanguageManager.shared.currentLanguage == .arabic ? "عرض تفاصيل الشحنة" : "View Shipment Details")
                            Spacer()
                            Image(systemName: "chevron.forward")
                        }
                        .font(AppTypography.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(AppColors.brandPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    shortLandNoticeIfNeeded(result)
                    boardAction(result)
                }

                Spacer(minLength: AppSpacing.xxLarge)
            }
            .padding(AppSpacing.medium)
        }
        .background(AppColors.groupedBackground.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnBackgroundTap()
        .navigationTitle(LanguageManager.shared.string(.toolAirCargoTracking))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var trackingEntryCard: some View {
        AppCard(cornerRadius: 24) {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AppColors.brandPrimary.opacity(0.10))
                            .frame(width: 46, height: 46)
                        Image(systemName: "airplane.circle.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(AppColors.brandPrimary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(LanguageManager.shared.string(.trackingAWBTitle))
                            .font(AppTypography.headline)
                            .foregroundStyle(AppColors.textPrimary)
                        Text(LanguageManager.shared.string(.trackingTwoSourcesHint))
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer()
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text(LanguageManager.shared.string(.trackingAWBNumber))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)

                    HStack(spacing: 8) {
                        Image(systemName: "shippingbox.fill")
                            .foregroundStyle(AppColors.brandPrimary)

                        TextField(
                            LanguageManager.shared.string(.trackingAWBPlaceholder),
                            text: Binding(
                                get: { viewModel.formattedAWB },
                                set: { viewModel.setAWBInput($0) }
                            )
                        )
                        .font(AppTypography.technicalNumberMedium)
                        .keyboardType(.numberPad)
                        .textContentType(.none)
                        .autocorrectionDisabled()
                        .focused($isAWBFocused)
                        .preserveTechnicalLTR()

                        if !viewModel.awbInput.isEmpty {
                            Button {
                                viewModel.clearAWB()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(AppColors.textTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(AppColors.innerCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Text(LanguageManager.shared.string(.trackingAWBAutoFormatHint))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)

                    if let source = AirlineDirectory.source(forAWB: viewModel.awbInput), AWBNormalizer.normalized(viewModel.awbInput).count >= 3 {
                        HStack(spacing: 6) {
                            Image(systemName: "airplane")
                            Text(source.name)
                            if let code = source.iataCode {
                                Text("• \(code)")
                                    .preserveTechnicalLTR()
                            }
                            Spacer()
                        }
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.brandPrimary)
                    }
                }

                AppButton(
                    LanguageManager.shared.string(.trackingTrackShipment),
                    icon: "magnifyingglass",
                    isLoading: viewModel.isLoading
                ) {
                    isAWBFocused = false
                    Task { await viewModel.track() }
                }
                .opacity(viewModel.canTrack || viewModel.isLoading ? 1 : 0.55)
            }
        }
    }

    private var progressiveUpdateNotice: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text(LanguageManager.shared.string(.trackingUpdatingSecondSource))
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 2)
        .accessibilityElement(children: .combine)
    }

    private func resultHeader(_ result: AirCargoTrackingResult) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(LanguageManager.shared.string(.trackingResultsTitle))
                    .font(AppTypography.title3)
                    .foregroundStyle(AppColors.textPrimary)
                Text(AWBNormalizer.formatted(result.awb))
                    .font(AppTypography.technicalNumberLarge)
                    .foregroundStyle(AppColors.brandDeepNavy)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .allowsTightening(true)
                    .layoutPriority(1)
                    .preserveTechnicalLTR()
            }
            Spacer()
            if let latest = mergedPreviewEvents(result).first?.event {
                Text(compactEventTitle(latest))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppColors.success)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(AppColors.success.opacity(0.10))
                    .clipShape(Capsule())
            }
        }
    }


    private func trackingSummaryCard(_ result: AirCargoTrackingResult) -> some View {
        let airlineRoute = routeText(origin: result.airline.origin, destination: result.airline.destination)
        let transomRoute = routeText(origin: result.transom.origin, destination: result.transom.destination)
        let route = airlineRoute ?? transomRoute
        let pieces = result.transom.receivedPieces ?? result.airline.pieces
        let weight = result.transom.weightKg ?? result.airline.weightKg
        let latest = mergedPreviewEvents(result).first?.event

        return AppCard(cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(AppColors.brandPrimary.opacity(0.10))
                            .frame(width: 50, height: 50)
                        Image(systemName: "airplane")
                            .font(.system(size: 21, weight: .bold))
                            .foregroundStyle(AppColors.brandPrimary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.airline.airlineName ?? LanguageManager.shared.string(.trackingAirlineUnknown))
                            .font(AppTypography.headline)
                            .foregroundStyle(AppColors.textPrimary)
                        if let latest {
                            Text(compactEventTitle(latest))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(AppColors.success)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppColors.success.opacity(0.10))
                                .clipShape(Capsule())
                        } else if let status = result.transom.status ?? result.airline.status {
                            Text(status)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    Spacer()
                }

                if let route {
                    HStack(spacing: 7) {
                        Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                            .foregroundStyle(AppColors.textTertiary)
                        Text(route)
                            .font(AppTypography.technicalNumberSmall)
                            .fontWeight(.bold)
                            .preserveTechnicalLTR()
                        Spacer()
                    }
                }

                HStack(spacing: 14) {
                    if let pieces {
                        summaryInfo(icon: "shippingbox.fill", value: "\(pieces) PCS")
                    }
                    if let weight {
                        summaryInfo(icon: "scalemass.fill", value: "\(NSDecimalNumber(decimal: weight).stringValue) KG")
                    }
                    Spacer()
                }

                Divider()

                HStack(spacing: 10) {
                    sourceMiniStatus(
                        title: airlineSourceLabel(result.airline, includeCarrierWhenAggregated: false),
                        state: result.airline.sourceState,
                        icon: "airplane"
                    )
                    sourceMiniStatus(title: "Transom Cargo", state: result.transom.sourceState, icon: "building.2.fill")
                    Spacer()
                }
            }
        }
    }

    @ViewBuilder
    private func trackingPreview(_ result: AirCargoTrackingResult) -> some View {
        let events = Array(mergedPreviewEvents(result).prefix(3))
        if !events.isEmpty {
            AppCard(cornerRadius: 22) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(LanguageManager.shared.currentLanguage == .arabic ? "آخر 3 تحديثات" : "Latest 3 Updates")
                            .font(AppTypography.headline)
                        Spacer()
                        Text(LanguageManager.shared.currentLanguage == .arabic ? "كل الأحداث داخل التفاصيل" : "All events in details")
                            .font(AppTypography.caption2)
                            .foregroundStyle(AppColors.textTertiary)
                    }

                    ForEach(Array(events.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .top, spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(index == 0 ? AppColors.success.opacity(0.14) : AppColors.brandPrimary.opacity(0.09))
                                    .frame(width: 30, height: 30)
                                Image(systemName: previewEventIcon(item.event))
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(index == 0 ? AppColors.success : AppColors.brandPrimary)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(compactEventTitle(item.event))
                                    .font(AppTypography.caption)
                                    .fontWeight(index == 0 ? .bold : .semibold)
                                    .foregroundStyle(AppColors.textPrimary)
                                if LanguageManager.shared.currentLanguage == .arabic,
                                   compactEventTitle(item.event) != item.event.title {
                                    Text(item.event.title)
                                        .font(AppTypography.caption2)
                                        .foregroundStyle(AppColors.textSecondary)
                                        .preserveTechnicalLTR()
                                }
                                let meta = [item.event.location, item.event.timestamp].compactMap { $0 }.filter { !$0.isEmpty }
                                if !meta.isEmpty {
                                    Text(meta.joined(separator: " • "))
                                        .font(AppTypography.caption2)
                                        .foregroundStyle(AppColors.textTertiary)
                                        .preserveTechnicalLTR()
                                }
                            }
                            Spacer()
                            Text(item.sourceLabel)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(item.isTransom ? AppColors.warning : AppColors.brandPrimary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background((item.isTransom ? AppColors.warning : AppColors.brandPrimary).opacity(0.08))
                                .clipShape(Capsule())
                        }
                        if index < events.count - 1 { Divider() }
                    }
                }
            }
        }
    }

    private func mergedPreviewEvents(_ result: AirCargoTrackingResult) -> [(event: TrackingEvent, sourceLabel: String, isTransom: Bool)] {
        var items: [(TrackingEvent, String, Bool)] = []
        let airlineName = airlineSourceLabel(result.airline, includeCarrierWhenAggregated: true)
        if let events = result.airline.recentEvents, !events.isEmpty {
            items += events.map { ($0, airlineName, false) }
        } else if let fallback = result.airline.lastEvent, !fallback.isEmpty {
            items.append((TrackingEvent(title: fallback), airlineName, false))
        }
        if let events = result.transom.recentEvents, !events.isEmpty {
            items += events.map { ($0, "Transom", true) }
        } else if let fallback = result.transom.lastEvent, !fallback.isEmpty {
            items.append((TrackingEvent(title: fallback), "Transom", true))
        }
        return items.sorted { lhs, rhs in
            let l = previewDate(lhs.0.timestamp)
            let r = previewDate(rhs.0.timestamp)
            if let l, let r, l != r { return l > r }
            if l != nil && r == nil { return true }
            if l == nil && r != nil { return false }
            return !lhs.2 && rhs.2
        }
    }

    private func sourceMiniStatus(title: String, state: TrackingSourceState, icon: String) -> some View {
        let color: Color = state == .live ? AppColors.success : (state == .unavailable ? AppColors.error : AppColors.warning)
        return HStack(spacing: 5) {
            Image(systemName: state == .live ? "checkmark.circle.fill" : "clock.fill")
                .foregroundStyle(color)
            Image(systemName: icon)
                .foregroundStyle(AppColors.textTertiary)
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)
        }
    }

    private func summaryInfo(icon: String, value: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(AppColors.textTertiary)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
                .preserveTechnicalLTR()
        }
    }

    private func compactEventTitle(_ event: TrackingEvent) -> String {
        guard LanguageManager.shared.currentLanguage == .arabic else { return event.title }
        let lower = event.title.lowercased()
        if lower.contains("notified consignee") || lower.contains("consignee notified") { return "تم إشعار المستلم" }
        if lower.contains("shipment notified for delivery") { return "تم إشعار الشحنة للتسليم" }
        if lower.contains("ready for delivery") || lower.contains("ready for collection") { return "الشحنة جاهزة للتسليم" }
        if lower.contains("received at destination") { return "تم استلام الشحنة في الوجهة" }
        if lower.contains("shipment received from flight") { return "تم استلام الشحنة من الرحلة" }
        if lower.contains("received in"), let location = event.location { return "تم استلام الشحنة في \(location)" }
        if lower.contains("arrived"), let location = event.location { return "وصلت الشحنة إلى \(location)" }
        if lower.contains("departed"), let location = event.location { return "غادرت الشحنة من \(location)" }
        if lower.contains("document released") { return "تم الإفراج عن مستندات الشحنة" }
        if lower.contains("delivered") { return "تم تسليم الشحنة" }
        if lower.contains("accepted") { return "تم قبول الشحنة من الناقل" }
        if lower.contains("booked") { return "تم حجز الشحنة" }
        if lower.contains("transit") { return "الشحنة قيد النقل" }
        return localizedEventTitle(event)
    }

    private func previewEventIcon(_ event: TrackingEvent) -> String {
        let lower = event.title.lowercased()
        if lower.contains("delivered") { return "checkmark" }
        if lower.contains("notified") || lower.contains("ready for delivery") { return "bell.fill" }
        if lower.contains("arriv") { return "airplane.arrival" }
        if lower.contains("depart") { return "airplane.departure" }
        if lower.contains("received") { return "shippingbox.fill" }
        if lower.contains("released") { return "doc.text.fill" }
        return "circle.fill"
    }

    private func previewDate(_ value: String?) -> Date? {
        TrackingEventTimestamp.parse(value)
    }

    private func airlineSourceLabel(_ snapshot: AirlineTrackingSnapshot, includeCarrierWhenAggregated: Bool) -> String {
        let carrier = snapshot.airlineName ?? (LanguageManager.shared.currentLanguage == .arabic ? "شركة الطيران" : "Airline")
        guard snapshot.dataSourceKind == .aggregator else { return carrier }
        let source = snapshot.dataSourceName ?? "Track-Trace"
        return includeCarrierWhenAggregated ? "\(carrier) • \(source)" : source
    }

    private func airlineCard(_ snapshot: AirlineTrackingSnapshot) -> some View {
        sourceCard(
            icon: "airplane",
            title: snapshot.airlineName ?? LanguageManager.shared.string(.trackingAirlineSource),
            subtitle: snapshot.dataSourceKind == .aggregator
                ? (LanguageManager.shared.currentLanguage == .arabic ? "البيانات عبر \(snapshot.dataSourceName ?? "Track-Trace")" : "Data via \(snapshot.dataSourceName ?? "Track-Trace")")
                : LanguageManager.shared.string(.trackingAirlineSource),
            sourceState: snapshot.sourceState,
            sourceURL: snapshot.sourceURL,
            openSourceText: snapshot.dataSourceKind == .aggregator
                ? (LanguageManager.shared.currentLanguage == .arabic ? "فتح مصدر التتبع" : "Open tracking source")
                : LanguageManager.shared.string(.trackingOpenOfficialSource)
        ) {
            trackingRows([
                (.trackingFlight, snapshot.flightNumber),
                (.trackingRoute, routeText(origin: snapshot.origin, destination: snapshot.destination)),
                (.trackingDeparture, snapshot.departure),
                (.trackingArrival, snapshot.arrival),
                (.trackingPieces, snapshot.pieces.map(String.init)),
                (.trackingWeight, decimalWeight(snapshot.weightKg)),
                (.trackingStatus, snapshot.status)
            ])
            recentEventsSection(snapshot.recentEvents, fallback: snapshot.lastEvent)
        }
    }

    private func transomCard(_ snapshot: TransomTrackingSnapshot) -> some View {
        sourceCard(
            icon: "building.2.fill",
            title: "Transom Cargo",
            subtitle: LanguageManager.shared.string(.trackingAirportConfirmation),
            sourceState: snapshot.sourceState,
            sourceURL: snapshot.sourceURL,
            openSourceText: LanguageManager.shared.string(.trackingOpenOfficialSource)
        ) {
            trackingRows([
                (.trackingArrivalStatus, localizedState(snapshot.arrivalState)),
                (.trackingReceivedPieces, receivedPiecesText(snapshot)),
                (.trackingWeight, decimalWeight(snapshot.weightKg)),
                (.trackingFlight, snapshot.flightNumber),
                (.trackingFlightDate, snapshot.flightDate),
                (.trackingRoute, routeText(origin: snapshot.origin, destination: snapshot.destination)),
                (.trackingStatus, snapshot.status),
                (.trackingShortLanded, snapshot.shortLandedPieces.map { "\($0)" })
            ])
            recentEventsSection(snapshot.recentEvents, fallback: snapshot.lastEvent)
        }
    }

    @ViewBuilder
    private func sourceCard<Content: View>(
        icon: String,
        title: String,
        subtitle: String,
        sourceState: TrackingSourceState,
        sourceURL: URL?,
        openSourceText: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        AppCard(cornerRadius: 22) {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppColors.brandPrimary.opacity(0.09))
                            .frame(width: 42, height: 42)
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AppColors.brandPrimary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(AppTypography.headline)
                            .foregroundStyle(AppColors.textPrimary)
                        Text(subtitle)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer()
                    sourceStateBadge(sourceState)
                }

                if sourceState == .live {
                    content()
                } else {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "link.badge.plus")
                            .foregroundStyle(AppColors.warning)
                        Text(LanguageManager.shared.string(.trackingSourceConnectorPending))
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.innerCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if let sourceURL {
                    Link(destination: sourceURL) {
                        HStack {
                            Image(systemName: "safari.fill")
                            Text(openSourceText)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .font(AppTypography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.brandPrimary)
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func trackingRows(_ rows: [(LocalizedKey, String?)]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if let value = row.1, !value.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(LanguageManager.shared.string(row.0))
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
                    .padding(.vertical, 8)

                    if index < rows.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func recentEventsSection(_ events: [TrackingEvent]?, fallback: String?) -> some View {
        let items = displayEvents(events, fallback: fallback)
        if !items.isEmpty {
            Divider()
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 10) {
                Text(LanguageManager.shared.string(.trackingRecentEvents))
                    .font(AppTypography.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(AppColors.textPrimary)

                ForEach(Array(items.enumerated()), id: \.offset) { index, event in
                    HStack(alignment: .top, spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(AppColors.brandPrimary.opacity(index == 0 ? 0.14 : 0.08))
                                .frame(width: 26, height: 26)
                            Text("\(index + 1)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AppColors.brandPrimary)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                if let code = event.code, !code.isEmpty {
                                    Text(code)
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundStyle(AppColors.brandPrimary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(AppColors.brandPrimary.opacity(0.08))
                                        .clipShape(Capsule())
                                }
                                Text(localizedEventTitle(event))
                                    .font(AppTypography.caption)
                                    .fontWeight(index == 0 ? .bold : .semibold)
                                    .foregroundStyle(AppColors.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            if let meta = eventMeta(event) {
                                Text(meta)
                                    .font(AppTypography.caption2)
                                    .foregroundStyle(AppColors.textSecondary)
                                    .preserveTechnicalLTR()
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.innerCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func displayEvents(_ events: [TrackingEvent]?, fallback: String?) -> [TrackingEvent] {
        if let events, !events.isEmpty { return Array(events.prefix(3)) }
        guard let fallback, !fallback.isEmpty else { return [] }
        return [TrackingEvent(title: fallback)]
    }

    private func eventMeta(_ event: TrackingEvent) -> String? {
        let values = [event.location, event.timestamp].compactMap { value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        return values.isEmpty ? nil : values.joined(separator: " • ")
    }

    private func localizedEventTitle(_ event: TrackingEvent) -> String {
        guard LanguageManager.shared.currentLanguage == .arabic else { return event.title }
        let lower = event.title.lowercased()
        switch event.code?.uppercased() {
        case "NFD": return "تم إشعار الشحنة للتسليم"
        case "NTF": return "تم إشعار المستلم"
        case "BRK": return "تم تفريغ الشحنة من وحدة التحميل"
        case "MAN": return "تم تسجيل الشحنة على الرحلة"
        case "RCF": return "استلام الشحنة من الرحلة"
        case "DLV": return "تم التسليم"
        case "RFD": return "جاهزة للتسليم"
        case "DOC": return "تم الإفراج عن المستندات"
        case "ARR": return "وصلت"
        case "DEP": return "غادرت"
        case "RCS": return "تم استلام الشحنة"
        case "BKD": return "تم الحجز"
        case "TRN": return "قيد النقل"
        default:
            if lower.contains("ready for delivery") { return "جاهزة للتسليم" }
            if lower.contains("document released") { return "تم الإفراج عن المستندات" }
            if lower.contains("received from flight") { return "استلام الشحنة من الرحلة" }
            if lower.contains("notified consignee") || lower.contains("consignee notified") { return "تم إشعار المستلم" }
            if lower.contains("received in") { return "تم استلام الشحنة في المحطة" }
            if lower.contains("received at destination") { return "تم استلام الشحنة في الوجهة" }
            if lower.contains("arriv") { return "وصلت" }
            if lower.contains("depart") { return "غادرت" }
            if lower.contains("deliver") { return "تم التسليم" }
            if lower.contains("accepted") { return "تم استلام الشحنة" }
            if lower.contains("broken down") { return "تم تفريغ الشحنة من وحدة التحميل" }
            if lower.contains("manifested") { return "تم تسجيل الشحنة على الرحلة" }
            if lower.contains("booked") { return "تم الحجز" }
            return event.title
        }
    }

    @ViewBuilder
    private func shortLandNoticeIfNeeded(_ result: AirCargoTrackingResult) -> some View {
        if let short = result.transom.shortLandedPieces, short > 0 {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppColors.warning)
                VStack(alignment: .leading, spacing: 2) {
                    Text(LanguageManager.shared.string(.trackingShortLandDetected))
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.textPrimary)
                    Text(LanguageManager.shared.string(.trackingShortLandCount, short))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
            }
            .padding(AppSpacing.medium)
            .background(AppColors.warning.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func boardAction(_ result: AirCargoTrackingResult) -> some View {
        AppButton(
            viewModel.isOnBoard
                ? LanguageManager.shared.string(.trackingAlreadyOnBoard)
                : LanguageManager.shared.string(.trackingAddToBoard),
            icon: viewModel.isOnBoard ? "checkmark.circle.fill" : "plus.circle.fill",
            style: viewModel.isOnBoard ? .secondary : .primary
        ) {
            if !viewModel.isOnBoard {
                viewModel.addToBoard()
            }
        }
    }

    private func inlineError(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(AppColors.error)
            Text(text)
                .font(AppTypography.subheadline)
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
        }
        .padding(AppSpacing.medium)
        .background(AppColors.error.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func sourceStateBadge(_ state: TrackingSourceState) -> some View {
        let title: String
        let color: Color
        switch state {
        case .live:
            title = LanguageManager.shared.string(.trackingLive)
            color = AppColors.success
        case .sourceOnly:
            title = LanguageManager.shared.string(.trackingSourceReady)
            color = AppColors.warning
        case .unavailable:
            title = LanguageManager.shared.string(.trackingUnavailable)
            color = AppColors.error
        }

        return Text(title)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color.opacity(0.11))
            .clipShape(Capsule())
    }

    private func statusPill(_ state: CargoArrivalState) -> some View {
        let title = localizedState(state)
        let color: Color
        switch state {
        case .arrived: color = AppColors.success
        case .partial: color = AppColors.warning
        case .inTransit: color = AppColors.brandPrimary
        case .notArrived: color = AppColors.textSecondary
        case .unknown: color = AppColors.textTertiary
        }

        return Text(title)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(color.opacity(0.10))
            .clipShape(Capsule())
    }

    private func localizedState(_ state: CargoArrivalState) -> String {
        switch state {
        case .arrived: return LanguageManager.shared.string(.cargoStateArrived)
        case .partial: return LanguageManager.shared.string(.cargoStatePartial)
        case .inTransit: return LanguageManager.shared.string(.cargoStateInTransit)
        case .notArrived: return LanguageManager.shared.string(.cargoStateNotArrived)
        case .unknown: return LanguageManager.shared.string(.cargoStateUnknown)
        }
    }

    private func routeText(origin: String?, destination: String?) -> String? {
        guard let origin, let destination, !origin.isEmpty, !destination.isEmpty else { return nil }
        return "\(origin) → \(destination)"
    }

    private func receivedPiecesText(_ snapshot: TransomTrackingSnapshot) -> String? {
        switch (snapshot.receivedPieces, snapshot.expectedPieces) {
        case let (received?, expected?): return "\(received) / \(expected)"
        case let (received?, nil): return "\(received)"
        default: return nil
        }
    }

    private func decimalWeight(_ value: Decimal?) -> String? {
        guard let value else { return nil }
        return "\(NSDecimalNumber(decimal: value).stringValue) KG"
    }
}
