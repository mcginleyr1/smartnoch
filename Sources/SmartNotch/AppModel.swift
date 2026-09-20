import AppKit
import Observation

enum Tab: String, CaseIterable {
    case widgets, agents, files, clipboard

    var icon: String {
        switch self {
        case .widgets: "square.grid.2x2"
        case .agents: "terminal"
        case .files: "tray.full"
        case .clipboard: "doc.on.clipboard"
        }
    }
}

enum Activity: Equatable {
    case level(icon: String, value: Double)
    case text(icon: String, text: String)
    case agent(icon: String, state: AgentState)
    case music
}

@Observable final class AppModel {
    static let expandedSize = CGSize(width: 640, height: 230)
    static let wingWidth: CGFloat = 64

    var expanded = false
    var tab = Tab.widgets
    var hud: Activity?
    var notchSize = CGSize.zero
    var battery: (level: Int, charging: Bool)?

    let nowPlaying = NowPlaying()
    let shelf = Shelf()
    let clipboard = ClipboardHistory()
    let calendar = CalendarEvents()
    let weather = Weather()
    let agents = Agents()

    @ObservationIgnored private var hudDismiss: DispatchWorkItem?

    var activity: Activity? {
        hud ?? agents.active.map { .agent(icon: $0.icon, state: $0.state) } ?? (nowPlaying.isPlaying ? .music : nil)
    }

    var collapsedSize: CGSize {
        CGSize(width: notchSize.width + (activity == nil ? 0 : 2 * Self.wingWidth), height: notchSize.height)
    }

    var currentSize: CGSize { expanded ? Self.expandedSize : collapsedSize }

    func flash(_ activity: Activity) {
        hud = activity
        hudDismiss?.cancel()
        let dismiss = DispatchWorkItem { [weak self] in self?.hud = nil }
        hudDismiss = dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: dismiss)
    }
}
