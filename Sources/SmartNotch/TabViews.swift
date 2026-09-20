import SwiftUI

struct WidgetsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 10) {
            Card { nowPlaying }.frame(width: 250)
            Card { calendar }
            Card { weather }.frame(width: 110)
                .onTapGesture { NSWorkspace.shared.open(NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.weather")!) }
        }
    }

    private var nowPlaying: some View {
        let player = model.nowPlaying
        return HStack(spacing: 12) {
            Artwork(size: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text(player.title.isEmpty ? "Nothing playing" : player.title).font(.headline).lineLimit(1)
                Text(player.artist).font(.subheadline).foregroundStyle(.gray).lineLimit(1)
                Spacer()
                HStack(spacing: 18) {
                    Button(action: player.previous) { Image(systemName: "backward.fill") }
                    Button(action: player.playPause) { Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").font(.title2) }
                    Button(action: player.next) { Image(systemName: "forward.fill") }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var calendar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Upcoming", systemImage: "calendar").font(.caption).foregroundStyle(.gray)
            if model.calendar.denied {
                Text("Calendar access denied").font(.callout).foregroundStyle(.gray)
            } else if model.calendar.events.isEmpty {
                Text("No upcoming events").font(.callout).foregroundStyle(.gray)
            }
            ForEach(model.calendar.events.prefix(3), id: \.eventIdentifier) { event in
                HStack(spacing: 6) {
                    Capsule().fill(Color(cgColor: event.calendar.cgColor)).frame(width: 3, height: 26)
                    VStack(alignment: .leading) {
                        Text(event.title).font(.callout).lineLimit(1)
                        Text(event.startDate, format: .dateTime.weekday().hour().minute()).font(.caption).foregroundStyle(.gray)
                    }
                }
            }
        }
    }

    private var weather: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: model.weather.symbol).symbolRenderingMode(.multicolor).font(.largeTitle)
            Spacer()
            Text(model.weather.temperature?.formatted(.measurement(width: .abbreviated, numberFormatStyle: .number.precision(.fractionLength(0)))) ?? "--")
                .font(.title2.weight(.semibold))
            Text(model.weather.summary).font(.caption).foregroundStyle(.gray)
        }
    }
}

struct AgentBadge: View {
    let state: AgentState

    var body: some View {
        switch state {
        case .working: ProgressView().controlSize(.small)
        case .waiting: Image(systemName: "hand.raised.fill").foregroundStyle(.yellow)
        case .done: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .idle: Image(systemName: "moon.zzz.fill").foregroundStyle(.gray)
        }
    }
}

struct AgentsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.agents.sessions.isEmpty {
            Text("No active agent sessions").foregroundStyle(.gray)
        }
        ScrollView(showsIndicators: false) {
            VStack(spacing: 6) {
                ForEach(model.agents.sessions) { session in
                    HStack(spacing: 10) {
                        Image(systemName: session.icon).frame(width: 20)
                        Text(session.project).font(.callout.weight(.semibold)).lineLimit(1)
                        Text(session.detail).font(.caption).foregroundStyle(.gray).lineLimit(1)
                        Spacer()
                        Text(session.agent.capitalized + " · " + session.state.label).font(.caption).foregroundStyle(.gray)
                        AgentBadge(state: session.state).frame(width: 20)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
}

struct FilesView: View {
    @Environment(AppModel.self) private var model
    @State private var airDropTargeted = false

    var body: some View {
        HStack(spacing: 10) {
            Card {
                if model.shelf.urls.isEmpty {
                    Text("Drop files here").foregroundStyle(.gray).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                HStack(spacing: 8) { ForEach(model.shelf.urls, id: \.self, content: file) }
            }

            Card {
                VStack(spacing: 8) {
                    Image(systemName: "dot.radiowaves.left.and.right").font(.largeTitle)
                    Text("AirDrop").font(.caption)
                }
                .foregroundStyle(airDropTargeted ? .blue : .gray)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: 110)
            .onDrop(of: [.fileURL], isTargeted: $airDropTargeted) { providers in
                loadFileURLs(providers) { model.shelf.airDrop([$0]) }
                return true
            }
        }
    }

    private func file(_ url: URL) -> some View {
        VStack(spacing: 4) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 48, height: 48)
            Text(url.lastPathComponent).font(.caption2).lineLimit(2).multilineTextAlignment(.center)
        }
        .frame(width: 74)
        .onTapGesture { NSWorkspace.shared.open(url) }
        .onDrag { NSItemProvider(contentsOf: url)! }
        .contextMenu {
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            Button("AirDrop") { model.shelf.airDrop([url]) }
            Button("Remove") { model.shelf.urls.removeAll { $0 == url } }
        }
    }
}

struct ClipboardView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.clipboard.clips.isEmpty {
            Text("Copied text and images show up here").foregroundStyle(.gray)
        }
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(model.clipboard.clips) { clip in
                    Card {
                        if let text = clip.text { Text(text).font(.caption).lineLimit(9) }
                        if let image = clip.image { Image(nsImage: image).resizable().aspectRatio(contentMode: .fit) }
                    }
                    .frame(width: 140)
                    .onTapGesture { model.clipboard.copy(clip) }
                    .contextMenu {
                        Button("Remove") { model.clipboard.clips.removeAll { $0.id == clip.id } }
                        Button("Clear All") { model.clipboard.clips = [] }
                    }
                }
            }
        }
    }
}
