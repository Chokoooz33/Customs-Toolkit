import Foundation

public struct AirlineTrackingSource: Hashable, Sendable {
    public let prefix: String
    public let name: String
    public let iataCode: String?
    public let trackingURL: URL?

    public init(prefix: String, name: String, iataCode: String? = nil, trackingURL: URL? = nil) {
        self.prefix = prefix
        self.name = name
        self.iataCode = iataCode
        self.trackingURL = trackingURL
    }
}

public enum AirlineDirectory {
    /// Operationally useful AWB-prefix directory for carriers commonly encountered in Gulf air cargo.
    /// Unknown prefixes still work: the tracker keeps the AWB and exposes Transom Cargo as the second source.
    private static let sources: [String: AirlineTrackingSource] = [
        "910": .init(prefix: "910", name: "Oman Air Cargo", iataCode: "WY", trackingURL: URL(string: "https://cargo.omanair.com/track-shipment")),
        "176": .init(prefix: "176", name: "Emirates SkyCargo", iataCode: "EK", trackingURL: URL(string: "https://eskycargo.emirates.com/app/offerandorder/#/home/find-offer")),
        "157": .init(prefix: "157", name: "Qatar Airways Cargo", iataCode: "QR", trackingURL: URL(string: "https://www.qrcargo.com/s/track-your-shipment")),
        "607": .init(prefix: "607", name: "Etihad Cargo", iataCode: "EY", trackingURL: URL(string: "https://touch.track-trace.com/aircargo")),
        "235": .init(prefix: "235", name: "Turkish Cargo", iataCode: "TK", trackingURL: URL(string: "https://www.turkishcargo.com/en/cargo-tracking")),
        "065": .init(prefix: "065", name: "Saudia Cargo", iataCode: "SV", trackingURL: URL(string: "https://www.saudiacargo.com/en/digital-services?tab=trackShipment")),
        "020": .init(prefix: "020", name: "Lufthansa Cargo", iataCode: "LH", trackingURL: URL(string: "https://www.lufthansa-cargo.com/en/eservices/etracking")),
        "172": .init(prefix: "172", name: "Cargolux", iataCode: "CV", trackingURL: URL(string: "https://www.cargolux.com/track-and-Trace")),
        "071": .init(prefix: "071", name: "Ethiopian Cargo", iataCode: "ET", trackingURL: URL(string: "https://ethiopiancargo.azurewebsites.net/my-cargo/track-your-shipment")),
        "072": .init(prefix: "072", name: "Gulf Air Cargo", iataCode: "GF", trackingURL: URL(string: "https://www.gulfair.com/cargo")),
        "160": .init(prefix: "160", name: "Cathay Cargo", iataCode: "CX", trackingURL: URL(string: "https://www.cathaycargo.com/usrapps/eservices/track/track.aspx")),
        "618": .init(prefix: "618", name: "Singapore Airlines Cargo", iataCode: "SQ", trackingURL: URL(string: "https://www.siacargo.com")),
        "057": .init(prefix: "057", name: "Air France KLM Martinair Cargo", iataCode: "AF", trackingURL: URL(string: "https://www.afklcargo.com/WW/en/homepage/homepage")),
        "074": .init(prefix: "074", name: "KLM Cargo", iataCode: "KL", trackingURL: URL(string: "https://www.afklcargo.com/mycargo/shipment/singlesearch")),
        "125": .init(prefix: "125", name: "British Airways Cargo", iataCode: "BA", trackingURL: URL(string: "https://www.iagcargo.com/en/")),
        "098": .init(prefix: "098", name: "Air India Cargo", iataCode: "AI", trackingURL: URL(string: "https://aicargoportal.airindia.com/icargoneoportal/app/main/#/app")),
        "229": .init(prefix: "229", name: "Kuwait Airways Cargo", iataCode: "KU", trackingURL: URL(string: "https://www.kuwaitairways.com/en/cargo/tracking")),
        "514": .init(prefix: "514", name: "Air Arabia Cargo", iataCode: "G9", trackingURL: URL(string: "https://cargo.airarabia.com/cargo-tracking/")),
        "960": .init(prefix: "960", name: "SalamAir", iataCode: "OV", trackingURL: URL(string: "https://touch.track-trace.com/aircargo"))
    ]

    public static func source(forAWB awb: String) -> AirlineTrackingSource? {
        guard let prefix = AWBNormalizer.prefix(awb) else { return nil }
        return sources[prefix]
    }

    public static func source(forPrefix prefix: String) -> AirlineTrackingSource? {
        sources[prefix]
    }

    /// Returns a source URL prepared for the specific AWB when the carrier supports it.
    /// Oman Air uses the no-login SmartKargo tracking page and accepts prefix/serial query values.
    public static func liveTrackingURL(forAWB awb: String) -> URL? {
        let normalized = AWBNormalizer.normalized(awb)
        guard normalized.count == 11,
              let prefix = AWBNormalizer.prefix(normalized),
              let source = sources[prefix] else { return nil }

        if prefix == "910" {
            let serial = String(normalized.dropFirst(3))
            var components = URLComponents(string: "https://omanair.smartkargo.com/FrmAWBTracking.aspx")
            components?.queryItems = [
                URLQueryItem(name: "AWBNo", value: serial),
                URLQueryItem(name: "AWBPrefix", value: prefix)
            ]
            return components?.url
        }

        return source.trackingURL
    }
}

public protocol AirlineLiveTrackingResolving: Sendable {
    func fetch(awb: String, source: AirlineTrackingSource?) async throws -> AirlineTrackingSnapshot
}

public protocol TransomLiveTrackingResolving: Sendable {
    func fetch(awb: String) async throws -> TransomTrackingSnapshot
}

public enum AirCargoTrackingError: LocalizedError {
    case invalidAWB

    public var errorDescription: String? {
        switch self {
        case .invalidAWB:
            return "Invalid AWB"
        }
    }
}

public enum TrackingProgressSource: Sendable, Equatable {
    case airline
    case transom
}

public struct AirCargoTrackingProgress: Sendable {
    public let result: AirCargoTrackingResult
    public let completedSource: TrackingProgressSource
    public let isFinal: Bool

    public init(result: AirCargoTrackingResult, completedSource: TrackingProgressSource, isFinal: Bool) {
        self.result = result
        self.completedSource = completedSource
        self.isFinal = isFinal
    }
}

public enum AirCargoTrackingResultMerger {
    /// Keeps the last verified live source visible while a progressive refresh is still resolving
    /// the other source, and preserves recent events when a source temporarily omits them.
    public static func merge(existing: AirCargoTrackingResult, incoming: AirCargoTrackingResult) -> AirCargoTrackingResult {
        var merged = incoming

        if incoming.airline.sourceState != .live && existing.airline.sourceState == .live {
            merged.airline = existing.airline
        } else if incoming.airline.sourceState == .live,
                  incoming.airline.recentEvents == nil,
                  existing.airline.recentEvents != nil {
            merged.airline.recentEvents = existing.airline.recentEvents
        }

        if incoming.transom.sourceState != .live && existing.transom.sourceState == .live {
            merged.transom = existing.transom
        } else if incoming.transom.sourceState == .live,
                  incoming.transom.recentEvents == nil,
                  existing.transom.recentEvents != nil {
            merged.transom.recentEvents = existing.transom.recentEvents
        }

        merged.updatedAt = max(existing.updatedAt, incoming.updatedAt)
        return merged
    }
}

/// Combines the two agreed tracking sources: the issuing airline and Transom Cargo.
///
/// The service intentionally never fabricates shipment events. If no verified live connector is injected,
/// it returns source-only cards with the official tracking destinations. This keeps the UI and Cargo Board
/// production-safe while airline/Transom API or web-integration adapters are verified independently.
public actor AirCargoTrackingService {
    public static let shared = AirCargoTrackingService(
        airlineResolver: OfficialWebTrackingResolver.shared,
        transomResolver: OfficialWebTrackingResolver.shared
    )

    public static let transomTrackingURL = URL(string: "https://webtrack.omansats.om/shipment-tracking-details")!

    private let airlineResolver: (any AirlineLiveTrackingResolving)?
    private let transomResolver: (any TransomLiveTrackingResolving)?

    public init(
        airlineResolver: (any AirlineLiveTrackingResolving)? = nil,
        transomResolver: (any TransomLiveTrackingResolving)? = nil
    ) {
        self.airlineResolver = airlineResolver
        self.transomResolver = transomResolver
    }

    /// Final-result API kept for callers that do not need progressive UI updates.
    public func track(awb input: String) async throws -> AirCargoTrackingResult {
        try await performTrack(awb: input, emit: nil)
    }

    /// Streams a result as soon as the first source finishes, then streams the fully refreshed result.
    /// WKWebView work remains serialized by `TrackingWebKitSerialGate`; this improves perceived speed
    /// without reintroducing the dual-WebView instability seen on real devices.
    public nonisolated func trackProgressively(awb input: String) -> AsyncThrowingStream<AirCargoTrackingProgress, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    _ = try await self.performTrack(awb: input) { progress in
                        continuation.yield(progress)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func performTrack(
        awb input: String,
        emit: (@Sendable (AirCargoTrackingProgress) -> Void)?
    ) async throws -> AirCargoTrackingResult {
        let normalized = AWBNormalizer.normalized(input)
        guard AWBNormalizer.isValidLength(normalized) else {
            throw AirCargoTrackingError.invalidAWB
        }

        let airlineSource = AirlineDirectory.source(forAWB: normalized)
        var airline = sourceOnlyAirline(awb: normalized, source: airlineSource)
        var transom = sourceOnlyTransom()

        // The three carrier-specific adapters are normally the fastest first answer. For generic/adaptive
        // airline pages, Transom is tried first so a slow or inaccessible carrier website cannot hold the
        // whole screen hostage before the user sees useful airport data.
        let prefix = AWBNormalizer.prefix(normalized)
        let airlineFirst = Self.optimizedAirlinePrefixes.contains(prefix ?? "")

        if airlineFirst {
            airline = await resolveAirline(awb: normalized, source: airlineSource)
            let first = makeResult(awb: normalized, airline: airline, transom: transom)
            emit?(AirCargoTrackingProgress(result: first, completedSource: .airline, isFinal: false))

            guard !Task.isCancelled else { return first }
            transom = await resolveTransom(awb: normalized)
        } else {
            transom = await resolveTransom(awb: normalized)
            let first = makeResult(awb: normalized, airline: airline, transom: transom)
            emit?(AirCargoTrackingProgress(result: first, completedSource: .transom, isFinal: false))

            guard !Task.isCancelled else { return first }
            airline = await resolveAirline(awb: normalized, source: airlineSource)
        }

        transom = fillMissingSharedFacts(in: transom, from: airline)
        let final = makeResult(awb: normalized, airline: airline, transom: transom)
        emit?(AirCargoTrackingProgress(
            result: final,
            completedSource: airlineFirst ? .transom : .airline,
            isFinal: true
        ))
        return final
    }

    private static let optimizedAirlinePrefixes: Set<String> = ["910", "176", "235", "157", "098"]

    private func makeResult(
        awb: String,
        airline: AirlineTrackingSnapshot,
        transom: TransomTrackingSnapshot
    ) -> AirCargoTrackingResult {
        AirCargoTrackingResult(awb: awb, airline: airline, transom: transom, updatedAt: Date())
    }

    private func sourceOnlyAirline(awb: String, source: AirlineTrackingSource?) -> AirlineTrackingSnapshot {
        let url = AirlineDirectory.liveTrackingURL(forAWB: awb) ?? source?.trackingURL
        return AirlineTrackingSnapshot(
            sourceState: .sourceOnly,
            airlineName: source?.name,
            airlinePrefix: AWBNormalizer.prefix(awb),
            dataSourceName: TrackingSourceAttribution.displayName(for: url, carrierName: source?.name),
            dataSourceKind: TrackingSourceAttribution.kind(for: url),
            sourceURL: url
        )
    }

    private func sourceOnlyTransom() -> TransomTrackingSnapshot {
        TransomTrackingSnapshot(
            sourceState: .sourceOnly,
            arrivalState: .unknown,
            sourceURL: Self.transomTrackingURL
        )
    }

    private func fillMissingSharedFacts(
        in snapshot: TransomTrackingSnapshot,
        from airline: AirlineTrackingSnapshot
    ) -> TransomTrackingSnapshot {
        var transom = snapshot
        guard transom.sourceState == .live else { return transom }

        // These are shipment-level facts, not inferred events. Transom sometimes leaves Received Weight
        // blank even though the issuing airline returned the verified AWB weight/piece total. Keep
        // Transom's operational state/events authoritative, but fill missing shared shipment facts.
        if transom.expectedPieces == nil { transom.expectedPieces = airline.pieces }
        if transom.weightKg == nil { transom.weightKg = airline.weightKg }
        if transom.origin == nil { transom.origin = airline.origin }
        if transom.destination == nil { transom.destination = airline.destination }
        if transom.flightNumber == nil { transom.flightNumber = airline.flightNumber }
        return transom
    }

    private func resolveAirline(awb: String, source: AirlineTrackingSource?) async -> AirlineTrackingSnapshot {
        if let airlineResolver {
            do {
                var snapshot = try await airlineResolver.fetch(awb: awb, source: source)
                if snapshot.airlineName == nil { snapshot.airlineName = source?.name }
                if snapshot.airlinePrefix == nil { snapshot.airlinePrefix = AWBNormalizer.prefix(awb) }
                if snapshot.sourceURL == nil { snapshot.sourceURL = source?.trackingURL }
                snapshot.dataSourceName = snapshot.dataSourceName ?? TrackingSourceAttribution.displayName(for: snapshot.sourceURL, carrierName: source?.name)
                snapshot.dataSourceKind = snapshot.dataSourceKind ?? TrackingSourceAttribution.kind(for: snapshot.sourceURL)
                snapshot.sourceState = .live
                snapshot.fetchedAt = snapshot.fetchedAt ?? Date()
                return snapshot
            } catch {
                // Fall through to the official source card. Existing board data is preserved by the store.
            }
        }

        return sourceOnlyAirline(awb: awb, source: source)
    }

    private func resolveTransom(awb: String) async -> TransomTrackingSnapshot {
        if let transomResolver {
            do {
                var snapshot = try await transomResolver.fetch(awb: awb)
                snapshot.sourceState = .live
                snapshot.sourceURL = snapshot.sourceURL ?? Self.transomTrackingURL
                snapshot.fetchedAt = snapshot.fetchedAt ?? Date()
                return snapshot
            } catch {
                // Fall through to the source-only state; never substitute guessed arrival data.
            }
        }

        return sourceOnlyTransom()
    }
}
