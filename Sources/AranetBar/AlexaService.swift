import Foundation

struct AlexaReading {
    let voc: Int        // ppb
    let pm25: Double    // µg/m³
    let timestamp: Date
}

@MainActor
class AlexaService: ObservableObject {
    @Published var latestReading: AlexaReading?
    @Published var isConnected = false
    @Published var lastError: String?
    @Published var deviceName: String?

    var isConfigured: Bool {
        FileManager.default.fileExists(atPath: Self.dataFile.path)
    }

    private var pollTimer: Timer?

    private static let dataFile = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/aranet-bar/air-quality.json")

    init() {
        loadReading()
        startPolling()
    }

    func refreshReading() {
        loadReading()
    }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.loadReading() }
        }
    }

    private func loadReading() {
        guard let data = try? Data(contentsOf: Self.dataFile) else {
            isConnected = false
            return
        }

        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw ReadingError.invalidFormat
            }

            let voc = (json["voc"] as? NSNumber)?.intValue
            let pm25 = (json["pm25"] as? NSNumber)?.doubleValue
            let name = json["device_name"] as? String

            guard let v = voc, let p = pm25 else {
                throw ReadingError.missingFields
            }

            // Check staleness — ignore readings older than 30 minutes
            var timestamp = Date()
            if let ts = json["timestamp"] as? String {
                let fmt = ISO8601DateFormatter()
                // Try with fractional seconds first, then without
                fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                var parsed = fmt.date(from: ts)
                if parsed == nil {
                    fmt.formatOptions = [.withInternetDateTime]
                    parsed = fmt.date(from: ts)
                }
                if let parsed {
                    timestamp = parsed
                    if Date().timeIntervalSince(parsed) > 1800 {
                        lastError = "Air quality data is stale"
                        isConnected = false
                        return
                    }
                }
            }

            latestReading = AlexaReading(voc: v, pm25: p, timestamp: timestamp)
            deviceName = name ?? "Air Quality Monitor"
            isConnected = true
            lastError = nil
        } catch {
            lastError = "Bad air-quality.json: \(error.localizedDescription)"
            isConnected = false
        }
    }

    enum ReadingError: Error, LocalizedError {
        case invalidFormat, missingFields
        var errorDescription: String? {
            switch self {
            case .invalidFormat: "Invalid JSON format"
            case .missingFields: "Missing voc or pm25 fields"
            }
        }
    }
}
