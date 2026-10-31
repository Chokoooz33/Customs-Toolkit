import Foundation
import Observation

public struct GoldPriceSnapshot: Codable, Equatable, Sendable {
    public let price24: Decimal
    public let price22: Decimal
    public let price21: Decimal
    public let price18: Decimal
    public let sourceUpdatedText: String?
    public let fetchedAt: Date

    public func price(for karat: Int) -> Decimal? {
        switch karat {
        case 24: return price24
        case 22: return price22
        case 21: return price21
        case 18: return price18
        default: return nil
        }
    }
}

public enum GoldPriceServiceError: LocalizedError, Equatable {
    case invalidSourceURL
    case invalidResponse
    case invalidEncoding
    case missingPrice(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidSourceURL:
            return "Invalid gold price source URL."
        case .invalidResponse:
            return "The gold price source returned an invalid response."
        case .invalidEncoding:
            return "The gold price page could not be decoded."
        case .missingPrice(let karat):
            return "Could not locate the \(karat)K gold price in the source page."
        }
    }
}

/// Lightweight native gold-price reader for the approved Oman source.
///
/// The dashboard consumes this service so normal daily use does not require rendering
/// the advertising/consent-heavy website. The original website remains available as a
/// source/fallback screen through `GoldPriceWebView`.
@MainActor
@Observable
public final class GoldPriceService {
    public static let shared = GoldPriceService()

    public private(set) var snapshot: GoldPriceSnapshot?
    public private(set) var isLoading = false
    public private(set) var lastError: String?

    private let session: URLSession
    private let cacheKey = "customs_toolkit.gold_price_snapshot.v1"
    private let refreshInterval: TimeInterval = 10 * 60

    public init(session: URLSession = .shared) {
        self.session = session
        self.snapshot = Self.loadCachedSnapshot(forKey: cacheKey)
    }

    /// Uses cached data immediately and refreshes only when the cache is stale.
    public func refreshIfNeeded() async {
        if let snapshot, Date().timeIntervalSince(snapshot.fetchedAt) < refreshInterval {
            return
        }
        await refresh(force: false)
    }

    public func refresh(force: Bool = true) async {
        if isLoading { return }
        if !force, let snapshot, Date().timeIntervalSince(snapshot.fetchedAt) < refreshInterval {
            return
        }

        guard let url = URL(string: AppConfig.trustedGoldPriceURL) else {
            lastError = GoldPriceServiceError.invalidSourceURL.localizedDescription
            return
        }

        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            request.cachePolicy = .reloadRevalidatingCacheData
            request.setValue(
                "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148 Safari/604.1",
                forHTTPHeaderField: "User-Agent"
            )
            request.setValue("ar,en;q=0.8", forHTTPHeaderField: "Accept-Language")

            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw GoldPriceServiceError.invalidResponse
            }

            let parsed = try Self.parseHTMLData(data, fetchedAt: Date())
            snapshot = parsed
            Self.saveCachedSnapshot(parsed, forKey: cacheKey)
        } catch {
            // Keep a previously cached snapshot visible if refresh fails.
            lastError = error.localizedDescription
        }
    }

    // MARK: - Parsing

    public nonisolated static func parseHTMLData(_ data: Data, fetchedAt: Date = Date()) throws -> GoldPriceSnapshot {
        guard var html = String(data: data, encoding: .utf8) else {
            throw GoldPriceServiceError.invalidEncoding
        }

        // Remove non-content blocks before stripping tags. This keeps parsing deterministic
        // while avoiding a WebView and its consent/advertising UI.
        html = html.replacingOccurrences(
            of: #"(?is)<script[^>]*>.*?</script>"#,
            with: " ",
            options: .regularExpression
        )
        html = html.replacingOccurrences(
            of: #"(?is)<style[^>]*>.*?</style>"#,
            with: " ",
            options: .regularExpression
        )
        html = html.replacingOccurrences(of: #"(?is)<[^>]+>"#, with: " ", options: .regularExpression)
        html = decodeCommonHTMLEntities(html)

        return try parsePlainText(html, fetchedAt: fetchedAt)
    }

    public nonisolated static func parsePlainText(_ text: String, fetchedAt: Date = Date()) throws -> GoldPriceSnapshot {
        let normalized = text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        func price(_ karat: Int) throws -> Decimal {
            let pattern = "عيار\\s*\(karat)\\s*([0-9][0-9,]*(?:\\.[0-9]+)?)\\s*ريال"
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
            guard let match = regex.firstMatch(in: normalized, options: [], range: range),
                  let valueRange = Range(match.range(at: 1), in: normalized) else {
                throw GoldPriceServiceError.missingPrice(karat)
            }

            let raw = normalized[valueRange].replacingOccurrences(of: ",", with: "")
            guard let value = Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX")) else {
                throw GoldPriceServiceError.missingPrice(karat)
            }
            return value
        }

        let sourceUpdatedText: String? = {
            let pattern = #"تم تحديث أسعار الذهب في عمان[،,]?\s*(.{1,90}?)(?=الأسعار بالأيام السابقة|$)"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
                  let match = regex.firstMatch(
                    in: normalized,
                    options: [],
                    range: NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
                  ),
                  let valueRange = Range(match.range(at: 1), in: normalized) else {
                return nil
            }
            return String(normalized[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }()

        return GoldPriceSnapshot(
            price24: try price(24),
            price22: try price(22),
            price21: try price(21),
            price18: try price(18),
            sourceUpdatedText: sourceUpdatedText,
            fetchedAt: fetchedAt
        )
    }

    private nonisolated static func decodeCommonHTMLEntities(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#160;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }

    // MARK: - Cache

    private static func loadCachedSnapshot(forKey key: String) -> GoldPriceSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(GoldPriceSnapshot.self, from: data)
    }

    private static func saveCachedSnapshot(_ snapshot: GoldPriceSnapshot, forKey key: String) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
