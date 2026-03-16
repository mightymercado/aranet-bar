import SwiftUI

struct PopoverView: View {
    @ObservedObject var aranet: AranetService
    @ObservedObject var alexa: AlexaService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "aqi.medium")
                    .foregroundStyle(.secondary)
                Text("Air Quality")
                    .font(.headline)
                Spacer()
                if let name = aranet.deviceName {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(aranet.isConnected ? .green : .red)
                            .frame(width: 6, height: 6)
                        Text(name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let reading = aranet.latestReading {
                Divider()

                // CO2 hero
                HStack(alignment: .firstTextBaseline) {
                    Text("\(reading.co2)")
                        .font(.system(size: 36, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(co2Color(reading.co2))
                    Text("ppm CO\u{2082}")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    co2Badge(reading.co2)
                }

                Divider()

                // Secondary readings grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 10) {
                    sensorCard(
                        icon: "thermometer.medium",
                        label: "Temperature",
                        value: String(format: "%.1f\u{00B0}C", reading.temperature)
                    )
                    sensorCard(
                        icon: "humidity",
                        label: "Humidity",
                        value: "\(reading.humidity)%"
                    )
                    sensorCard(
                        icon: "barometer",
                        label: "Pressure",
                        value: String(format: "%.0f hPa", reading.pressure)
                    )
                    sensorCard(
                        icon: reading.battery > 20 ? "battery.75percent" : "battery.25percent",
                        label: "Battery",
                        value: "\(reading.battery)%",
                        valueColor: reading.battery > 20 ? .primary : .red
                    )
                }

                // Alexa Air Quality section
                if let alexaReading = alexa.latestReading {
                    Divider()

                    HStack {
                        Image(systemName: "aqi.low")
                            .foregroundStyle(.secondary)
                        Text("VOC & Particulate")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let name = alexa.deviceName {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(alexa.isConnected ? .green : .red)
                                    .frame(width: 5, height: 5)
                                Text(name)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                    ], spacing: 10) {
                        sensorCard(
                            icon: "wind",
                            label: "VOC",
                            value: "\(alexaReading.voc) ppb",
                            valueColor: vocColor(alexaReading.voc)
                        )
                        sensorCard(
                            icon: "smoke",
                            label: "PM2.5",
                            value: String(format: "%.1f µg/m³", alexaReading.pm25),
                            valueColor: pm25Color(alexaReading.pm25)
                        )
                    }
                } else if let alexaError = alexa.lastError, alexa.isConfigured {
                    Divider()
                    Text(alexaError)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Divider()

                // Footer
                HStack {
                    Text("Updated \(reading.timestamp, style: .relative) ago")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button {
                        aranet.refreshReading()
                        alexa.refreshReading()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
            } else if aranet.isScanning {
                Divider()
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Scanning for Aranet4...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            } else {
                Divider()
                VStack(spacing: 8) {
                    Text("No Aranet4 connected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Scan for Devices") {
                        aranet.startScanning()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            if let error = aranet.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // Quit
            Divider()
            Button("Quit Aranet Bar") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .frame(width: 280)
    }

    // MARK: - Components

    private func sensorCard(icon: String, label: String, value: String, valueColor: Color = .primary) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.subheadline.monospacedDigit().weight(.medium))
                    .foregroundStyle(valueColor)
            }
        }
    }

    private func vocColor(_ ppb: Int) -> Color {
        if ppb <= 300 { return .green }
        if ppb <= 1000 { return .orange }
        return .red
    }

    private func pm25Color(_ ugm3: Double) -> Color {
        if ugm3 <= 12 { return .green }
        if ugm3 <= 35 { return .orange }
        return .red
    }

    private func co2Color(_ ppm: Int) -> Color {
        if ppm < 800 { return .green }
        if ppm < 1000 { return Color(red: 0.55, green: 0.75, blue: 0.3) }
        if ppm < 1400 { return .orange }
        return .red
    }

    private func co2Badge(_ ppm: Int) -> some View {
        let (text, color): (String, Color) = {
            if ppm < 800 { return ("Excellent", .green) }
            if ppm < 1000 { return ("Good", Color(red: 0.55, green: 0.75, blue: 0.3)) }
            if ppm < 1400 { return ("Fair", .orange) }
            return ("Poor", .red)
        }()

        return Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
