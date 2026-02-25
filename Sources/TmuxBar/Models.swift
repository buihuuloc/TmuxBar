import Foundation

struct TmuxSession: Equatable, Identifiable {
    let name: String
    let paneCount: Int
    let isAttached: Bool
    let createdAt: String

    var id: String { name }

    var relativeAge: String {
        guard let epoch = TimeInterval(createdAt) else { return "" }
        let elapsed = Date().timeIntervalSince1970 - epoch
        guard elapsed >= 0 else { return "" }
        switch elapsed {
        case ..<60: return "<1m"
        case ..<3600: return "\(Int(elapsed / 60))m"
        case ..<86400: return "\(Int(elapsed / 3600))h"
        default: return "\(Int(elapsed / 86400))d"
        }
    }

    var displayTitle: String {
        let attached = isAttached ? " ●" : ""
        let age = relativeAge.isEmpty ? "" : " · \(relativeAge)"
        return "\(name)  (\(paneCount) pane\(paneCount == 1 ? "" : "s"))\(age)\(attached)"
    }
}
