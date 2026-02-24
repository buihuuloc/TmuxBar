import Foundation

struct TmuxSession: Equatable, Identifiable {
    let name: String
    let paneCount: Int
    let isAttached: Bool
    let createdAt: String

    var id: String { name }

    var displayTitle: String {
        let attached = isAttached ? " ●" : ""
        return "\(name)  (\(paneCount) pane\(paneCount == 1 ? "" : "s"))\(attached)"
    }
}
