import Foundation
import SwiftUI

@Observable
public final class CargoBoardStore {
    public static let shared = CargoBoardStore()

    private let defaults: UserDefaults
    private let storageKey = "customs_toolkit_air_cargo_board_v1"

    public private(set) var shipments: [CargoBoardShipment] = []
    public private(set) var isRefreshing = false
    public private(set) var lastRefreshAt: Date?

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    public func contains(awb: String) -> Bool {
        let normalized = AWBNormalizer.normalized(awb)
        return shipments.contains { $0.result.awb == normalized }
    }

    public func result(forAWB awb: String) -> AirCargoTrackingResult? {
        let normalized = AWBNormalizer.normalized(awb)
        return shipments.first(where: { $0.result.awb == normalized })?.result
    }

    public func addOrUpdate(_ result: AirCargoTrackingResult) {
        let normalized = AWBNormalizer.normalized(result.awb)
        guard !normalized.isEmpty else { return }

        if let index = shipments.firstIndex(where: { $0.result.awb == normalized }) {
            shipments[index].result = AirCargoTrackingResultMerger.merge(existing: shipments[index].result, incoming: result)
            shipments[index].lastRefreshAttempt = Date()
        } else {
            shipments.insert(CargoBoardShipment(result: result), at: 0)
        }

        sortAndSave()
    }

    public func remove(id: UUID) {
        shipments.removeAll { $0.id == id }
        save()
    }

    public func remove(awb: String) {
        let normalized = AWBNormalizer.normalized(awb)
        shipments.removeAll { $0.result.awb == normalized }
        save()
    }


    @MainActor
    public func refresh(id: UUID, using service: AirCargoTrackingService = .shared) async {
        guard !isRefreshing,
              let currentIndex = shipments.firstIndex(where: { $0.id == id }) else { return }

        isRefreshing = true
        defer { isRefreshing = false }

        let awb = shipments[currentIndex].result.awb
        shipments[currentIndex].lastRefreshAttempt = Date()

        do {
            for try await progress in service.trackProgressively(awb: awb) {
                guard let updatedIndex = shipments.firstIndex(where: { $0.id == id }) else { break }
                shipments[updatedIndex].result = AirCargoTrackingResultMerger.merge(
                    existing: shipments[updatedIndex].result,
                    incoming: progress.result
                )
            }
        } catch {
            // Keep the last verified snapshot when a live source is temporarily unavailable.
        }

        lastRefreshAt = Date()
        sortAndSave()
    }

    @MainActor
    public func refreshAll(using service: AirCargoTrackingService = .shared) async {
        guard !isRefreshing, !shipments.isEmpty else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        // Snapshot stable shipment IDs rather than array indices. `service.track` suspends, and the
        // board can be edited while awaiting WebKit/network work; an old index may no longer exist.
        let shipmentIDs = shipments.map(\.id)
        for id in shipmentIDs {
            guard let currentIndex = shipments.firstIndex(where: { $0.id == id }) else {
                continue
            }

            let awb = shipments[currentIndex].result.awb
            shipments[currentIndex].lastRefreshAttempt = Date()

            do {
                for try await progress in service.trackProgressively(awb: awb) {
                    guard let updatedIndex = shipments.firstIndex(where: { $0.id == id }) else {
                        break
                    }
                    shipments[updatedIndex].result = AirCargoTrackingResultMerger.merge(
                        existing: shipments[updatedIndex].result,
                        incoming: progress.result
                    )
                }
            } catch {
                // Preserve the last verified board snapshot if either live source is temporarily unavailable.
            }
        }

        lastRefreshAt = Date()
        sortAndSave()
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([CargoBoardShipment].self, from: data) else {
            shipments = []
            return
        }
        shipments = decoded.sorted { $0.addedAt > $1.addedAt }
    }

    private func sortAndSave() {
        shipments.sort { lhs, rhs in
            if lhs.result.boardState != rhs.result.boardState {
                return statePriority(lhs.result.boardState) < statePriority(rhs.result.boardState)
            }
            return lhs.addedAt > rhs.addedAt
        }
        save()
    }

    private func statePriority(_ state: CargoArrivalState) -> Int {
        switch state {
        case .partial: return 0
        case .arrived: return 1
        case .inTransit: return 2
        case .notArrived: return 3
        case .unknown: return 4
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(shipments) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
