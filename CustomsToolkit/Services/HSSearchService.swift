import Foundation

/// Status of the local customs tariff database.
public enum TariffDatasetStatus: Equatable {
    case notInstalled(reason: String)
    case ready(metadata: TariffDatasetMetadata, itemCount: Int)
}

/// Service handling HS Code searches, partial matching, ranking, and tariff dataset management.
@Observable
public final class HSSearchService {
    
    public static let shared = HSSearchService()
    
    public private(set) var status: TariffDatasetStatus
    public private(set) var currentMetadata: TariffDatasetMetadata?
    private var dataset: [HSCodeItem] = []
    private var searchIndex: [SearchIndexEntry] = []

    private struct SearchIndexEntry {
        let item: HSCodeItem
        let englishDescription: String
        let arabicDescription: String
    }

    public struct SearchResultSet {
        public let items: [HSCodeItem]
        public let totalMatches: Int
        public let isTruncated: Bool
    }
    
    public init(initialDataset: [HSCodeItem]? = nil, metadata: TariffDatasetMetadata? = nil) {
        if let items = initialDataset, !items.isEmpty {
            let meta = metadata ?? TariffDatasetMetadata(recordCount: items.count)
            self.dataset = items
            self.searchIndex = Self.makeSearchIndex(items)
            self.currentMetadata = meta
            self.status = .ready(metadata: meta, itemCount: items.count)
        } else {
            // Attempt to load from bundled production dataset resource if available
            let loader = TariffDatasetLoader.shared
            switch loader.loadBundledDataset() {
            case .success((let meta, let items, _)):
                self.dataset = items
                self.searchIndex = Self.makeSearchIndex(items)
                self.currentMetadata = meta
                self.status = .ready(metadata: meta, itemCount: items.count)
            case .failure:
                // Production default state: Awaiting validated structured dataset
                self.status = .notInstalled(
                    reason: "Tariff reference data is not installed yet."
                )
                self.currentMetadata = nil
            }
        }
    }
    
    /// Loads or imports a structured tariff dataset.
    public func loadDataset(_ items: [HSCodeItem], metadata: TariffDatasetMetadata? = nil) {
        let meta = metadata ?? TariffDatasetMetadata(recordCount: items.count)
        self.dataset = items
        self.searchIndex = Self.makeSearchIndex(items)
        self.currentMetadata = meta
        self.status = .ready(metadata: meta, itemCount: items.count)
    }
    
    /// Unloads dataset, returning status to pending.
    public func resetDataset() {
        self.dataset = []
        self.searchIndex = []
        self.currentMetadata = nil
        self.status = .notInstalled(
            reason: "Tariff reference data is not installed yet."
        )
    }
    
    /// Performs ranked search across HS codes and descriptions.
    ///
    /// The search index pre-normalizes descriptions once when the dataset loads,
    /// avoiding expensive Arabic normalization across 14k+ records on every keystroke.
    /// Results may be capped for UI rendering while preserving the true match count.
    public func searchResultSet(query: String, limit: Int = 160) -> SearchResultSet {
        let normalizedQuery = HSNormalizer.normalize(query)
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedArabicQuery = HSNormalizer.normalizeArabicForSearch(trimmedQuery)
        let lowercasedEnQuery = trimmedQuery.lowercased()

        guard !normalizedQuery.isEmpty || !trimmedQuery.isEmpty else {
            return SearchResultSet(items: [], totalMatches: 0, isTruncated: false)
        }

        var exactMatches: [HSCodeItem] = []
        var prefixMatches: [HSCodeItem] = []
        var descriptionMatches: [HSCodeItem] = []

        for entry in searchIndex {
            let item = entry.item
            let itemNormCode = item.normalizedCode

            if !normalizedQuery.isEmpty && itemNormCode == normalizedQuery {
                exactMatches.append(item)
                continue
            }

            if !normalizedQuery.isEmpty && itemNormCode.hasPrefix(normalizedQuery) {
                prefixMatches.append(item)
                continue
            }

            var isMatch = false
            if !lowercasedEnQuery.isEmpty && entry.englishDescription.contains(lowercasedEnQuery) {
                isMatch = true
            }

            if !isMatch && !normalizedArabicQuery.isEmpty && entry.arabicDescription.contains(normalizedArabicQuery) {
                isMatch = true
            }

            if isMatch {
                descriptionMatches.append(item)
            }
        }

        prefixMatches.sort { $0.normalizedCode < $1.normalizedCode }
        let allMatches = exactMatches + prefixMatches + descriptionMatches
        let safeLimit = max(1, limit)
        let visible = Array(allMatches.prefix(safeLimit))

        return SearchResultSet(
            items: visible,
            totalMatches: allMatches.count,
            isTruncated: allMatches.count > visible.count
        )
    }

    /// Compatibility API used by existing unit tests and non-UI callers.
    public func search(query: String) -> [HSCodeItem] {
        searchResultSet(query: query, limit: Int.max).items
    }

    private static func makeSearchIndex(_ items: [HSCodeItem]) -> [SearchIndexEntry] {
        items.map { item in
            SearchIndexEntry(
                item: item,
                englishDescription: item.descriptionEnglish?.lowercased() ?? "",
                arabicDescription: item.descriptionArabic.map(HSNormalizer.normalizeArabicForSearch) ?? ""
            )
        }
    }

}
