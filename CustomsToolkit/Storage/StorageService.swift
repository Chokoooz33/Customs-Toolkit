import Foundation
import SwiftUI

public enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    public var id: String { rawValue }
    
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Centralized local storage service using UserDefaults for offline persistence.
@Observable
public final class StorageService {
    
    public static let shared = StorageService()
    
    private let defaults: UserDefaults
    
    // Keys
    private let recentHSKey = "customs_toolkit_recent_hs_searches"
    private let appearanceKey = "customs_toolkit_appearance_mode"
    
    public var recentHSSearches: [RecentSearchItem] = []
    public var appearanceMode: AppAppearance {
        didSet {
            defaults.set(appearanceMode.rawValue, forKey: appearanceKey)
        }
    }
    
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        
        // Load appearance
        if let rawAppearance = defaults.string(forKey: appearanceKey),
           let saved = AppAppearance(rawValue: rawAppearance) {
            self.appearanceMode = saved
        } else {
            self.appearanceMode = .system
        }
        
        // Load recent searches
        loadRecentSearches()
    }
    
    // MARK: - Recent Searches Management
    
    private func loadRecentSearches() {
        guard let data = defaults.data(forKey: recentHSKey),
              let items = try? JSONDecoder().decode([RecentSearchItem].self, from: data) else {
            self.recentHSSearches = []
            return
        }
        self.recentHSSearches = items
    }
    
    public func addRecentHSSearch(query: String) {
        let normalized = HSNormalizer.normalize(query)
        guard !normalized.isEmpty else { return }
        
        // Remove existing duplicates of same normalized code
        var current = recentHSSearches.filter { $0.normalizedQuery != normalized }
        
        let newItem = RecentSearchItem(
            query: query.trimmingCharacters(in: .whitespacesAndNewlines),
            normalizedQuery: normalized,
            timestamp: Date()
        )
        
        current.insert(newItem, at: 0)
        
        // Keep maximum 10 recent searches
        if current.count > 10 {
            current = Array(current.prefix(10))
        }
        
        self.recentHSSearches = current
        saveRecentSearches()
    }
    
    public func clearRecentHSSearches() {
        self.recentHSSearches = []
        defaults.removeObject(forKey: recentHSKey)
    }
    
    private func saveRecentSearches() {
        if let data = try? JSONEncoder().encode(recentHSSearches) {
            defaults.set(data, forKey: recentHSKey)
        }
    }
}
