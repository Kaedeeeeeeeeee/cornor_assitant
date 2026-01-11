import Foundation

enum HotCorner: String, CaseIterable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    func localizedName(using localization: LocalizationManager) -> String {
        switch self {
        case .topLeft:
            return localization.localized("hot_corner.top_left")
        case .topRight:
            return localization.localized("hot_corner.top_right")
        case .bottomLeft:
            return localization.localized("hot_corner.bottom_left")
        case .bottomRight:
            return localization.localized("hot_corner.bottom_right")
        }
    }
}
