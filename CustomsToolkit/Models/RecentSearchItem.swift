import Foundation

/// Lightweight record of a recent HS code search query.
public struct RecentSearchItem: Identifiable, Codable, Hashable {
    public let id: String
    public let query: String
    public let normalizedQuery: String
    public let timestamp: Date
    
    public init(
        id: String = UUID().uuidString,
        query: String,
        normalizedQuery: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.query = query
        self.normalizedQuery = normalizedQuery
        self.timestamp = timestamp
    }
}
