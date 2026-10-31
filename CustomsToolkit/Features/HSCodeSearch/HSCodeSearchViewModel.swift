import SwiftUI

@MainActor
@Observable
public final class HSCodeSearchViewModel {

    public var searchQuery: String = "" {
        didSet { scheduleSearch() }
    }

    public var searchResults: [HSCodeItem] = []
    public var totalMatchCount: Int = 0
    public var resultsAreTruncated: Bool = false
    public var isSearching: Bool = false
    public var needsMoreInput: Bool = false
    public var selectedItem: HSCodeItem?

    private let searchService: HSSearchService
    private let storageService: StorageService
    private var searchTask: Task<Void, Never>?

    public var datasetStatus: TariffDatasetStatus { searchService.status }
    public var recentSearches: [RecentSearchItem] { storageService.recentHSSearches }

    public init(
        searchService: HSSearchService = .shared,
        storageService: StorageService = .shared
    ) {
        self.searchService = searchService
        self.storageService = storageService
    }

   

    private func scheduleSearch() {
        searchTask?.cancel()
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            clearSearchState()
            return
        }

        let normalizedCode = HSNormalizer.normalize(trimmed)
        let containsLetters = trimmed.unicodeScalars.contains { CharacterSet.letters.contains($0) }
        let effectiveLength = containsLetters ? trimmed.count : normalizedCode.count

        guard effectiveLength >= 2 else {
            searchResults = []
            totalMatchCount = 0
            resultsAreTruncated = false
            needsMoreInput = true
            isSearching = false
            return
        }

        needsMoreInput = false
        isSearching = true

        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 140_000_000)
            guard !Task.isCancelled, let self else { return }
            self.performSearchNow(trimmed)
        }
    }

    public func performSearch() {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            clearSearchState()
            return
        }
        searchTask?.cancel()
        performSearchNow(trimmed)
    }

    private func performSearchNow(_ query: String) {
        let resultSet = searchService.searchResultSet(query: query, limit: 160)
        searchResults = resultSet.items
        totalMatchCount = resultSet.totalMatches
        resultsAreTruncated = resultSet.isTruncated
        isSearching = false
    }

    private func clearSearchState() {
        searchTask?.cancel()
        searchResults = []
        totalMatchCount = 0
        resultsAreTruncated = false
        needsMoreInput = false
        isSearching = false
    }

    public func commitSearchQuery() {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !needsMoreInput else { return }
        storageService.addRecentHSSearch(query: trimmed)
        performSearch()
    }

    public func selectRecentSearch(_ item: RecentSearchItem) {
        HapticFeedback.selection()
        searchQuery = item.query
    }

    public func clearRecentSearches() {
        HapticFeedback.impact(style: .light)
        storageService.clearRecentHSSearches()
    }

    public func copyHSCode(_ item: HSCodeItem) {
        ClipboardService.copy(item.code)
        HapticFeedback.success()
    }

    public func copyDescription(_ item: HSCodeItem, isArabic: Bool) {
        let text = isArabic ? item.descriptionAr : item.descriptionEn
        ClipboardService.copy(text)
        HapticFeedback.success()
    }
}
