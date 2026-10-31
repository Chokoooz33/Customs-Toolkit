import Foundation

public enum CargoArrivalState: String, Codable, CaseIterable, Sendable {
    case unknown
    case inTransit
    case notArrived
    case arrived
    case partial
}

public enum TrackingSourceState: String, Codable, Sendable {
    case live
    case sourceOnly
    case unavailable
}

/// Identifies whether the data shown for an airline came from the carrier itself or from a third-party router.
/// This is deliberately separate from `airlineName`: the carrier stays Air India/Etihad/etc. even when the
/// successful read path was Track-Trace. Optional snapshot fields keep older saved Cargo Board records decodable.
public enum TrackingDataSourceKind: String, Codable, Sendable {
    case officialCarrier
    case aggregator
}

public enum TrackingSourceAttribution {
    public static func kind(for url: URL?) -> TrackingDataSourceKind {
        guard let host = url?.host?.lowercased() else { return .officialCarrier }
        if host == "touch.track-trace.com" || host.hasSuffix(".track-trace.com") ||
            host == "thedeliverytracker.com" || host.hasSuffix(".thedeliverytracker.com") {
            return .aggregator
        }
        return .officialCarrier
    }

    public static func displayName(for url: URL?, carrierName: String?) -> String {
        guard let host = url?.host?.lowercased() else { return carrierName ?? "Airline" }
        if host == "touch.track-trace.com" || host.hasSuffix(".track-trace.com") { return "Track-Trace" }
        if host == "thedeliverytracker.com" || host.hasSuffix(".thedeliverytracker.com") { return "The Delivery Tracker" }
        return carrierName ?? host
    }
}

/// Shared timestamp parser used by parsers and both tracking UIs. Airline portals do not agree on one
/// date format; keeping one parser prevents a valid event (notably Air India timestamps with seconds)
/// from being treated as undated and sorted below an older Transom event.
public enum TrackingEventTimestamp {
    private static let formats = [
        "EEE, d MMM yyyy HH:mm:ss", "EEE, dd MMM yyyy HH:mm:ss",
        "EEE, d MMM yyyy, HH:mm:ss", "EEE, dd MMM yyyy, HH:mm:ss",
        "EEE, d MMM yyyy HH:mm", "EEE, dd MMM yyyy HH:mm",
        "EEE, d MMM yyyy, HH:mm", "EEE, dd MMM yyyy, HH:mm",
        "d MMM yyyy, HH:mm:ss", "dd MMM yyyy, HH:mm:ss",
        "d MMM yyyy HH:mm:ss", "dd MMM yyyy HH:mm:ss",
        "d MMM yyyy HH:mm", "dd MMM yyyy HH:mm",
        "d MMMM yyyy HH:mm:ss", "dd MMMM yyyy HH:mm:ss",
        "d MMMM yyyy HH:mm", "dd MMMM yyyy HH:mm",
        "dd.MM.yyyy HH:mm:ss", "d.MM.yyyy HH:mm:ss",
        "dd.MM.yyyy HH:mm", "d.MM.yyyy HH:mm",
        "dd/MM/yyyy HH:mm:ss", "d/M/yyyy HH:mm:ss",
        "dd/MM/yyyy HH:mm", "d/M/yyyy HH:mm",
        "dd-MMM-yyyy HH:mm:ss", "d-MMM-yyyy HH:mm:ss",
        "dd-MMM-yyyy HH:mm", "d-MMM-yyyy HH:mm"
    ]

    public static func parse(_ value: String?) -> Date? {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) { return date }
        }
        return nil
    }

    /// Sorts only when timestamps are comparable. If both events are undated, source order is preserved.
    public static func newestFirst(_ events: [TrackingEvent]) -> [TrackingEvent] {
        events.enumerated().sorted { lhs, rhs in
            let ld = parse(lhs.element.timestamp)
            let rd = parse(rhs.element.timestamp)
            if let ld, let rd, ld != rd { return ld > rd }
            if ld != nil && rd == nil { return true }
            if ld == nil && rd != nil { return false }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }
}

public struct TrackingEvent: Codable, Equatable, Sendable {
    /// Operational milestone code supplied by the source when available (for example RCF/NFD/DLV).
    public var code: String?
    /// Exact event title captured from the source. The UI may show a simplified Arabic label above it,
    /// but this source wording is preserved for auditability.
    public var title: String
    public var location: String?
    public var timestamp: String?
    public var flightNumber: String?

    public init(
        code: String? = nil,
        title: String,
        location: String? = nil,
        timestamp: String? = nil,
        flightNumber: String? = nil
    ) {
        self.code = code
        self.title = title
        self.location = location
        self.timestamp = timestamp
        self.flightNumber = flightNumber
    }
}

public struct AirlineTrackingSnapshot: Codable, Equatable, Sendable {
    public var sourceState: TrackingSourceState
    public var airlineName: String?
    public var airlinePrefix: String?
    public var flightNumber: String?
    public var origin: String?
    public var destination: String?
    public var departure: String?
    public var arrival: String?
    public var pieces: Int?
    public var weightKg: Decimal?
    public var status: String?
    public var lastEvent: String?
    /// All verified source events captured from the airline, newest first. Optional keeps saved Cargo Board data backward-compatible.
    public var recentEvents: [TrackingEvent]?
    /// Name of the site that actually supplied the captured data (carrier site, Track-Trace, etc.).
    public var dataSourceName: String?
    public var dataSourceKind: TrackingDataSourceKind?
    public var sourceURL: URL?
    public var fetchedAt: Date?

    public init(
        sourceState: TrackingSourceState = .sourceOnly,
        airlineName: String? = nil,
        airlinePrefix: String? = nil,
        flightNumber: String? = nil,
        origin: String? = nil,
        destination: String? = nil,
        departure: String? = nil,
        arrival: String? = nil,
        pieces: Int? = nil,
        weightKg: Decimal? = nil,
        status: String? = nil,
        lastEvent: String? = nil,
        recentEvents: [TrackingEvent]? = nil,
        dataSourceName: String? = nil,
        dataSourceKind: TrackingDataSourceKind? = nil,
        sourceURL: URL? = nil,
        fetchedAt: Date? = nil
    ) {
        self.sourceState = sourceState
        self.airlineName = airlineName
        self.airlinePrefix = airlinePrefix
        self.flightNumber = flightNumber
        self.origin = origin
        self.destination = destination
        self.departure = departure
        self.arrival = arrival
        self.pieces = pieces
        self.weightKg = weightKg
        self.status = status
        self.lastEvent = lastEvent
        self.recentEvents = recentEvents
        self.dataSourceName = dataSourceName
        self.dataSourceKind = dataSourceKind
        self.sourceURL = sourceURL
        self.fetchedAt = fetchedAt
    }
}

public struct TransomTrackingSnapshot: Codable, Equatable, Sendable {
    public var sourceState: TrackingSourceState
    public var arrivalState: CargoArrivalState
    public var receivedPieces: Int?
    public var expectedPieces: Int?
    public var shortLandedPieces: Int?
    public var weightKg: Decimal?
    public var origin: String?
    public var destination: String?
    public var flightNumber: String?
    public var flightDate: String?
    public var importExport: String?
    public var agent: String?
    public var status: String?
    public var lastEvent: String?
    /// All verified Transom events captured from the official Transom source, newest first. Optional keeps saved Cargo Board data backward-compatible.
    public var recentEvents: [TrackingEvent]?
    public var sourceURL: URL?
    public var fetchedAt: Date?

    public init(
        sourceState: TrackingSourceState = .sourceOnly,
        arrivalState: CargoArrivalState = .unknown,
        receivedPieces: Int? = nil,
        expectedPieces: Int? = nil,
        shortLandedPieces: Int? = nil,
        weightKg: Decimal? = nil,
        origin: String? = nil,
        destination: String? = nil,
        flightNumber: String? = nil,
        flightDate: String? = nil,
        importExport: String? = nil,
        agent: String? = nil,
        status: String? = nil,
        lastEvent: String? = nil,
        recentEvents: [TrackingEvent]? = nil,
        sourceURL: URL? = nil,
        fetchedAt: Date? = nil
    ) {
        self.sourceState = sourceState
        self.arrivalState = arrivalState
        self.receivedPieces = receivedPieces
        self.expectedPieces = expectedPieces
        self.shortLandedPieces = shortLandedPieces
        self.weightKg = weightKg
        self.origin = origin
        self.destination = destination
        self.flightNumber = flightNumber
        self.flightDate = flightDate
        self.importExport = importExport
        self.agent = agent
        self.status = status
        self.lastEvent = lastEvent
        self.recentEvents = recentEvents
        self.sourceURL = sourceURL
        self.fetchedAt = fetchedAt
    }
}

public struct AirCargoTrackingResult: Codable, Equatable, Identifiable, Sendable {
    public var awb: String
    public var airline: AirlineTrackingSnapshot
    public var transom: TransomTrackingSnapshot
    public var updatedAt: Date

    public var id: String { awb }

    public init(
        awb: String,
        airline: AirlineTrackingSnapshot,
        transom: TransomTrackingSnapshot,
        updatedAt: Date = Date()
    ) {
        self.awb = awb
        self.airline = airline
        self.transom = transom
        self.updatedAt = updatedAt
    }

    public var boardState: CargoArrivalState {
        if let short = transom.shortLandedPieces, short > 0 { return .partial }
        if transom.arrivalState != .unknown { return transom.arrivalState }

        // When Transom has no record yet, keep the Cargo Board useful by accepting only strong
        // airline evidence. This never upgrades a shipment from vague text such as "processing".
        let destination = airline.destination?.uppercased()
        let events = airline.recentEvents ?? []
        if events.contains(where: { event in
            let code = event.code?.uppercased()
            let lower = event.title.lowercased()
            if code == "DLV" || code == "NFD" || code == "RFD" { return true }
            if lower.contains("delivered") || lower.contains("ready for delivery") || lower.contains("notified consignee") { return true }
            if code == "ARR" || code == "RCF" || lower.contains("arrived") || lower.contains("received at destination") || lower.contains("received in") {
                if lower.contains("received at destination") { return true }
                guard let destination else { return false }
                return event.location?.uppercased() == destination || lower.contains(destination.lowercased())
            }
            return false
        }) { return .arrived }

        let status = (airline.status ?? "").lowercased()
        if status.contains("delivered") || status.contains("ready for delivery") || status.contains("notified consignee") || status.contains("received at destination") { return .arrived }
        if let destination,
           (status.contains("arrived") || status.contains("received in")),
           status.contains(destination.lowercased()) { return .arrived }
        if status.contains("departed") || status.contains("in transit") { return .inTransit }
        if status.contains("accepted") || status.contains("booked") { return .notArrived }
        return .unknown
    }
}

public struct CargoBoardShipment: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var result: AirCargoTrackingResult
    public var addedAt: Date
    public var lastRefreshAttempt: Date?

    public init(
        id: UUID = UUID(),
        result: AirCargoTrackingResult,
        addedAt: Date = Date(),
        lastRefreshAttempt: Date? = nil
    ) {
        self.id = id
        self.result = result
        self.addedAt = addedAt
        self.lastRefreshAttempt = lastRefreshAttempt
    }
}

public enum AWBNormalizer {
    /// Returns only Western Arabic digits, accepting Arabic-Indic numerals and common separators.
    public static func digitsOnly(_ input: String) -> String {
        input.compactMap { character -> Character? in
            if character.isNumber {
                if let value = character.wholeNumberValue {
                    return Character(String(value))
                }
            }
            return nil
        }
        .reduce(into: "") { $0.append($1) }
    }

    public static func normalized(_ input: String) -> String {
        digitsOnly(input)
    }

    public static func formatted(_ input: String) -> String {
        let digits = normalized(input)
        guard digits.count > 3 else { return digits }
        let prefix = digits.prefix(3)
        let serial = digits.dropFirst(3)
        return "\(prefix)-\(serial)"
    }

    public static func isValidLength(_ input: String) -> Bool {
        normalized(input).count == 11
    }

    public static func prefix(_ input: String) -> String? {
        let digits = normalized(input)
        guard digits.count >= 3 else { return nil }
        return String(digits.prefix(3))
    }
}
