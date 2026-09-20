import AppKit
import Observation

/// Track info comes from the players' distributed notifications (no permission needed);
/// artwork and transport controls go through AppleScript (Automation permission).
@Observable final class NowPlaying {
    var title = ""
    var artist = ""
    var isPlaying = false
    var artwork: NSImage?

    @ObservationIgnored private var player = "Music"
    @ObservationIgnored private let scripts = DispatchQueue(label: "smartnotch.applescript")

    init() {
        let players = ["Music": ("com.apple.Music.playerInfo", "com.apple.Music"),
                       "Spotify": ("com.spotify.client.PlaybackStateChanged", "com.spotify.client")]
        for (player, (notification, bundleID)) in players {
            DistributedNotificationCenter.default().addObserver(forName: .init(notification), object: nil, queue: .main) { [weak self] note in
                let info = note.userInfo ?? [:]
                self?.update(player: player, title: info["Name"] as? String, artist: info["Artist"] as? String,
                             state: info["Player State"] as? String)
            }
            if !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty {
                queryCurrentTrack(player)
            }
        }
    }

    func playPause() { tell(player, "playpause") }
    func next() { tell(player, "next track") }
    func previous() { tell(player, "previous track") }

    private func update(player: String, title: String?, artist: String?, state: String?) {
        let playing = state?.lowercased() == "playing"
        guard playing || player == self.player else { return }
        let trackChanged = title != self.title || player != self.player
        self.player = player
        self.title = title ?? ""
        self.artist = artist ?? ""
        isPlaying = playing
        if trackChanged { loadArtwork() }
    }

    private func queryCurrentTrack(_ player: String) {
        tell(player, "get {name of current track, artist of current track, player state as string}") { [weak self] result in
            guard let result, result.numberOfItems == 3 else { return }
            self?.update(player: player, title: result.atIndex(1)?.stringValue, artist: result.atIndex(2)?.stringValue,
                         state: result.atIndex(3)?.stringValue)
        }
    }

    private func loadArtwork() {
        artwork = nil
        let track = title
        let show: (NSImage?) -> Void = { [weak self] image in
            DispatchQueue.main.async { if self?.title == track { self?.artwork = image } }
        }
        if player == "Spotify" {
            tell(player, "artwork url of current track") { result in
                guard let url = result?.stringValue.flatMap(URL.init(string:)) else { return }
                URLSession.shared.dataTask(with: url) { data, _, _ in show(data.flatMap(NSImage.init(data:))) }.resume()
            }
        } else {
            tell(player, "data of artwork 1 of current track") { show(($0?.data).flatMap(NSImage.init(data:))) }
        }
    }

    private func tell(_ player: String, _ command: String, completion: ((NSAppleEventDescriptor?) -> Void)? = nil) {
        scripts.async {
            var error: NSDictionary?
            let result = NSAppleScript(source: "tell application \"\(player)\" to \(command)")!.executeAndReturnError(&error)
            if let error { NSLog("AppleScript '%@' failed: %@", command, error) }
            DispatchQueue.main.async { completion?(error == nil ? result : nil) }
        }
    }
}
