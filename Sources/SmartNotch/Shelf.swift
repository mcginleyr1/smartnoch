import AppKit
import Observation

@Observable final class Shelf {
    static let limit = 6

    var urls: [URL] {
        didSet { UserDefaults.standard.set(urls.map(\.path), forKey: "shelf") }
    }

    init() {
        urls = (UserDefaults.standard.stringArray(forKey: "shelf") ?? [])
            .filter(FileManager.default.fileExists(atPath:))
            .map(URL.init(fileURLWithPath:))
    }

    func add(_ url: URL) {
        guard !urls.contains(url) else { return }
        urls = Array((urls + [url]).suffix(Self.limit))
    }

    func airDrop(_ urls: [URL]) {
        NSSharingService(named: .sendViaAirDrop)!.perform(withItems: urls)
    }
}

func loadFileURLs(_ providers: [NSItemProvider], then handle: @escaping (URL) -> Void) {
    for provider in providers {
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            DispatchQueue.main.async { handle(url) }
        }
    }
}
