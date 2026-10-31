import Foundation
import SwiftUI

@MainActor
@Observable
public final class AirCargoTrackingViewModel {
    public var awbInput: String = ""
    public private(set) var result: AirCargoTrackingResult?
    public private(set) var isLoading = false
    public private(set) var isUpdatingSecondarySource = false
    public private(set) var errorKey: LocalizedKey?

    private let service: AirCargoTrackingService
    private let boardStore: CargoBoardStore

    public init(
        service: AirCargoTrackingService = .shared,
        boardStore: CargoBoardStore = .shared
    ) {
        self.service = service
        self.boardStore = boardStore
    }

    public var normalizedAWB: String {
        AWBNormalizer.normalized(awbInput)
    }

    public var formattedAWB: String {
        AWBNormalizer.formatted(awbInput)
    }

    public var canTrack: Bool {
        AWBNormalizer.isValidLength(awbInput) && !isLoading
    }

    /// Stores only the 11 AWB digits. The view formats the dash automatically after the carrier prefix.
    public func setAWBInput(_ rawValue: String) {
        let digits = String(AWBNormalizer.normalized(rawValue).prefix(11))
        if awbInput != digits {
            awbInput = digits
        }
    }

    public func clearAWB() {
        awbInput = ""
        result = nil
        errorKey = nil
    }

    public var isOnBoard: Bool {
        guard let result else { return false }
        return boardStore.contains(awb: result.awb)
    }

    public func track() async {
        guard AWBNormalizer.isValidLength(awbInput) else {
            errorKey = .trackingInvalidAWB
            result = nil
            return
        }

        let normalized = AWBNormalizer.normalized(awbInput)
        if let cached = boardStore.result(forAWB: normalized) {
            // Show saved data immediately while the live refresh begins.
            result = cached
        } else {
            result = nil
        }

        isLoading = true
        isUpdatingSecondarySource = false
        errorKey = nil
        defer {
            isLoading = false
            isUpdatingSecondarySource = false
        }

        do {
            var receivedProgress = false
            for try await progress in service.trackProgressively(awb: normalized) {
                receivedProgress = true
                if let current = result {
                    result = AirCargoTrackingResultMerger.merge(existing: current, incoming: progress.result)
                } else {
                    result = progress.result
                }
                isUpdatingSecondarySource = !progress.isFinal
            }

            if !receivedProgress, result == nil {
                errorKey = .trackingUnableToPrepare
            }
        } catch {
            // If the AWB was already saved, keep its last verified data visible instead of blanking the card.
            if result == nil {
                errorKey = .trackingUnableToPrepare
            }
        }
    }

    public func addToBoard() {
        guard let result else { return }
        boardStore.addOrUpdate(result)
        HapticFeedback.success()
    }
}
