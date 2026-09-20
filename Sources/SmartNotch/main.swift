import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var notch: NotchController?
    private var monitors: [Any] = []
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    func applicationDidFinishLaunching(_ notification: Notification) {
        notch = NotchController(model: model)

        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: "SmartNotch")
        let menu = NSMenu()
        menu.addItem(withTitle: "Quit SmartNotch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu

        let model = model
        model.calendar.onUpcoming = { model.flash(.text(icon: "calendar", text: "\($0)m")) }
        monitors = [
            VolumeMonitor { model.flash(.level(icon: $0 == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill", value: $0)) },
            BrightnessMonitor { model.flash(.level(icon: "sun.max.fill", value: $0)) },
            BatteryMonitor { level, charging, notable in
                model.battery = (level, charging)
                if notable {
                    model.flash(.text(icon: charging ? "battery.100.bolt" : "battery.25", text: "\(level)%"))
                }
            },
        ]
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
