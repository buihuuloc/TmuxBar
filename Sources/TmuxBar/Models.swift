import Foundation

struct TmuxSession: Equatable, Identifiable {
    let name: String
    let windowCount: Int
    let isAttached: Bool
    let createdAt: String

    var id: String { name }

    var displayTitle: String {
        let attached = isAttached ? " ●" : ""
        return "\(name)  (\(windowCount) window\(windowCount == 1 ? "" : "s"))\(attached)"
    }
}
