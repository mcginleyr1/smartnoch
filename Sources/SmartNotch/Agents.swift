import AppKit
import Observation

private let agentEvent = Notification.Name("com.smartnotch.agent")

enum AgentState: String {
    case working, waiting, idle, done

    var label: String {
        switch self {
        case .working: "Working"
        case .waiting: "Needs you"
        case .idle: "Idle"
        case .done: "Done"
        }
    }
}

struct AgentSession: Identifiable, Equatable {
    let id: String
    let agent: String
    /// Bundle ID of the app the agent runs in (its terminal), empty when unknown.
    let app: String
    var cwd: String
    var state: AgentState
    var detail: String
    var updated = Date()

    var project: String { URL(fileURLWithPath: cwd).lastPathComponent }

    var icon: String {
        switch agent {
        case "claude": "asterisk"
        case "codex": "chevron.left.forwardslash.chevron.right"
        case "vibe": "wind"
        default: "cpu"
        }
    }
}

/// Coding-agent sessions, fed by hooks that run `SmartNotch notify <agent> <state>` (see hooks/).
@Observable final class Agents {
    /// Some agents (Vibe) have no approval event: a tool call that has not finished after this long is shown as waiting.
    private static let approvalGrace: TimeInterval = 10

    var sessions: [AgentSession] = []

    @ObservationIgnored var onDone: (AgentSession) -> Void = { _ in }
    @ObservationIgnored private var timer: Timer?

    init() {
        DistributedNotificationCenter.default().addObserver(forName: agentEvent, object: nil, queue: .main) { [weak self] note in
            self?.handle(note.userInfo as! [String: String])
        }
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.sessions.removeAll { $0.updated.timeIntervalSinceNow < ($0.state == .waiting ? -3600 : -600) }
        }
    }

    /// The session most in need of attention, for the collapsed notch.
    var active: AgentSession? {
        sessions.first { $0.state == .waiting } ?? sessions.first { $0.state == .working }
    }

    private func handle(_ info: [String: String]) {
        let id = info["agent"]! + ":" + info["session"]!
        let previous = sessions.first { $0.id == id }?.state
        sessions.removeAll { $0.id == id }
        guard info["state"] != "ended" else { return }

        let toolPending = info["state"] == "tool"
        let session = AgentSession(id: id, agent: info["agent"]!, app: info["app"] ?? "", cwd: info["cwd"]!,
                                   state: toolPending ? .working : AgentState(rawValue: info["state"]!)!, detail: info["detail"]!)
        sessions.insert(session, at: 0)

        if session.state == .done, previous != .done { onDone(session) }
        if toolPending {
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.approvalGrace) { [weak self] in
                guard let index = self?.sessions.firstIndex(where: { $0.id == id && $0.updated == session.updated }) else { return }
                self?.sessions[index].state = .waiting
            }
        }
    }

    /// Brings the session's terminal to the front; in Ghostty, the exact terminal whose working directory matches.
    func focus(_ session: AgentSession) {
        NSRunningApplication.runningApplications(withBundleIdentifier: session.app).first?.activate()
        guard session.app == "com.mitchellh.ghostty" else { return }
        let cwd = session.cwd.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            NSAppleScript(source: "tell application id \"\(session.app)\" to focus (first terminal whose working directory is \"\(cwd)\")")!
                .executeAndReturnError(&error)
            if let error { NSLog("Focusing terminal for %@ failed: %@", session.cwd, error) }
        }
    }
}

/// CLI side, run by agent hooks: forwards the hook's stdin JSON payload to the running app.
func postAgentEvent(agent: String, state: String) {
    precondition(["working", "waiting", "idle", "done", "ended", "tool"].contains(state), "unknown agent state: \(state)")
    let input = isatty(STDIN_FILENO) == 0 ? FileHandle.standardInput.readDataToEndOfFile() : Data()
    let payload = (try? JSONSerialization.jsonObject(with: input)) as? [String: Any] ?? [:]
    let cwd = payload["cwd"] as? String ?? FileManager.default.currentDirectoryPath
    let detail = ["tool_name", "notification_text", "message", "last_assistant_message"].lazy.compactMap { payload[$0] as? String }.first ?? ""

    DistributedNotificationCenter.default().postNotificationName(agentEvent, object: nil, userInfo: [
        "agent": agent,
        "app": ProcessInfo.processInfo.environment["__CFBundleIdentifier"] ?? "",
        "state": state,
        "session": payload["session_id"] as? String ?? cwd,
        "cwd": cwd,
        "detail": String(detail.prefix(200)),
    ], deliverImmediately: true)
}
