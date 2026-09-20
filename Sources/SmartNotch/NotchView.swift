import SwiftUI

struct NotchView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let radius: CGFloat = model.expanded ? 24 : 10
        Group {
            if model.expanded { ExpandedView() } else { ActivityView() }
        }
        .frame(width: model.currentSize.width, height: model.currentSize.height)
        .background(.black)
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius))
        .onDrop(of: [.fileURL], isTargeted: Binding(get: { false }, set: { targeted in
            if targeted { (model.expanded, model.tab) = (true, .files) }
        })) { providers in
            loadFileURLs(providers, then: model.shelf.add)
            return true
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(duration: 0.3), value: model.currentSize)
        .preferredColorScheme(.dark)
    }
}

/// Collapsed state: live activity content in the wings on either side of the notch.
struct ActivityView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 0) {
            leading.frame(width: AppModel.wingWidth)
            Spacer(minLength: model.notchSize.width)
            trailing.frame(width: AppModel.wingWidth)
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.white)
    }

    @ViewBuilder private var leading: some View {
        switch model.activity {
        case .level(let icon, _), .text(let icon, _), .agent(let icon, _): Image(systemName: icon)
        case .music: Artwork(size: 22)
        case nil: EmptyView()
        }
    }

    @ViewBuilder private var trailing: some View {
        switch model.activity {
        case .level(_, let value): ProgressView(value: value).tint(.white).padding(.horizontal, 10)
        case .text(_, let text): Text(text).monospacedDigit()
        case .agent(_, let state): AgentBadge(state: state)
        case .music: Waveform()
        case nil: EmptyView()
        }
    }
}

struct Waveform: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2) {
                ForEach(0..<4, id: \.self) { bar in
                    Capsule().frame(width: 3, height: 4 + 10 * abs(sin(time * 3 + Double(bar) * 1.7)))
                }
            }
            .frame(height: 16)
        }
    }
}

struct Artwork: View {
    @Environment(AppModel.self) private var model
    let size: CGFloat

    var body: some View {
        Group {
            if let artwork = model.nowPlaying.artwork {
                Image(nsImage: artwork).resizable().aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "music.note").frame(maxWidth: .infinity, maxHeight: .infinity).background(.white.opacity(0.1))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size / 5))
    }
}

struct ExpandedView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Button { model.tab = tab } label: {
                        Image(systemName: tab.icon).foregroundStyle(model.tab == tab ? .white : .gray)
                    }
                }
                Spacer()
                if let battery = model.battery {
                    Label("\(battery.level)%", systemImage: battery.charging ? "battery.100.bolt" : "battery.75")
                        .foregroundStyle(.gray)
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .medium))
            .frame(height: model.notchSize.height)

            Group {
                switch model.tab {
                case .widgets: WidgetsView()
                case .agents: AgentsView()
                case .files: FilesView()
                case .clipboard: ClipboardView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
        .foregroundStyle(.white)
    }
}

struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}
