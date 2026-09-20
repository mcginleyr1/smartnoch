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
    case agent(AgentSession)
    case music
}

@Observable final class AppModel {
    static let expandedSize = CGSize(width: 640, height: 230)

    var expanded = false
    var tab = Tab.widgets
    var hud: Activity?
    var notchSize = CGSize.zero
    var hasNotch = true
    var battery: (level: Int, charging: Bool)?

    let nowPlaying = NowPlaying()
    let shelf = Shelf()
    let clipboard = ClipboardHistory()
    let calendar = CalendarEvents()
    let weather = Weather()
    let agents = Agents()

    @ObservationIgnored private var hudDismiss: DispatchWorkItem?

    /// Without a notch to extend, persistent activities would be a permanent pill: only notifications show.
    var activity: Activity? {
        if let hud { return hud }
        if let session = agents.active, hasNotch || session.state == .waiting { return .agent(session) }
        return hasNotch && nowPlaying.isPlaying ? .music : nil
    }

    /// Agent activity is near-permanent while sessions run, so it stays small: just the agent's icon.
    var wingWidth: CGFloat {
        switch activity {
        case nil: 0
        case .agent: 34
        default: 64
        }
    }

    var collapsedSize: CGSize {
        CGSize(width: notchSize.width + 2 * wingWidth, height: notchSize.height)
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
