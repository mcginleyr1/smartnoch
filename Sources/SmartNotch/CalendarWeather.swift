import CoreLocation
import EventKit
import Observation

@Observable final class CalendarEvents {
    var events: [EKEvent] = []
    var denied = false

    @ObservationIgnored var onUpcoming: (Int) -> Void = { _ in }
    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private var alerted: Set<String> = []
    @ObservationIgnored private var timer: Timer?

    init() {
        store.requestFullAccessToEvents { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.denied = !granted
                guard granted else { return }
                self?.refresh()
                self?.timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in self?.refresh() }
            }
        }
    }

    private func refresh() {
        let now = Date()
        let predicate = store.predicateForEvents(withStart: now, end: now.addingTimeInterval(36 * 3600), calendars: nil)
        events = store.events(matching: predicate).filter { !$0.isAllDay && $0.startDate > now }.sorted { $0.startDate < $1.startDate }

        for event in events {
            let minutes = Int(event.startDate.timeIntervalSince(now) / 60)
            if minutes < 5, alerted.insert(event.eventIdentifier).inserted { onUpcoming(minutes + 1) }
        }
    }
}

/// Current conditions from open-meteo.com (no API key) at the CoreLocation position.
@Observable final class Weather: NSObject, CLLocationManagerDelegate {
    var temperature: Measurement<UnitTemperature>?
    var symbol = "cloud"
    var summary = ""

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var timer: Timer?

    private struct Response: Decodable {
        struct Current: Decodable {
            let temperature_2m: Double
            let weather_code: Int
        }
        let current: Current
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.requestWhenInUseAuthorization()
        timer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in self?.refresh() }
    }

    /// CoreLocation when authorized; otherwise (denied, or Location Services off) an approximate position from the IP address.
    private func refresh() {
        switch manager.authorizationStatus {
        case .authorizedAlways: manager.requestLocation()
        case .notDetermined: break
        default: locateByIP()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        refresh()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        NSLog("Location failed: %@", error.localizedDescription)
        locateByIP()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        fetchWeather(latitude: "\(coordinate.latitude)", longitude: "\(coordinate.longitude)")
    }

    private func locateByIP() {
        struct Geo: Decodable { let latitude, longitude: String }
        URLSession.shared.dataTask(with: URL(string: "https://get.geojs.io/v1/ip/geo.json")!) { [weak self] data, _, error in
            guard let data else { return NSLog("IP geolocation failed: %@", error?.localizedDescription ?? "") }
            let geo = try! JSONDecoder().decode(Geo.self, from: data)
            self?.fetchWeather(latitude: geo.latitude, longitude: geo.longitude)
        }.resume()
    }

    private func fetchWeather(latitude: String, longitude: String) {
        let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m,weather_code")!
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data else { return NSLog("Weather fetch failed: %@", error?.localizedDescription ?? "") }
            let current = try! JSONDecoder().decode(Response.self, from: data).current
            DispatchQueue.main.async {
                guard let self else { return }
                self.temperature = Measurement(value: current.temperature_2m, unit: .celsius)
                (self.symbol, self.summary) = Self.describe(current.weather_code)
            }
        }.resume()
    }

    /// WMO weather interpretation codes
    private static func describe(_ code: Int) -> (String, String) {
        switch code {
        case 0: ("sun.max.fill", "Clear")
        case 1...2: ("cloud.sun.fill", "Partly cloudy")
        case 3: ("cloud.fill", "Overcast")
        case 45, 48: ("cloud.fog.fill", "Fog")
        case 51...57: ("cloud.drizzle.fill", "Drizzle")
        case 61...67, 80...82: ("cloud.rain.fill", "Rain")
        case 71...77, 85...86: ("cloud.snow.fill", "Snow")
        case 95...99: ("cloud.bolt.rain.fill", "Thunderstorm")
        default: ("cloud", "")
        }
    }
}
