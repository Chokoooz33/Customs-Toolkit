import Foundation

public enum ServiceArea: String, CaseIterable, Identifiable, Codable {
    case air
    case sea

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .air: return "airplane"
        case .sea: return "ferry.fill"
        }
    }
}
