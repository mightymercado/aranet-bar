import Foundation
import CoreBluetooth

struct AranetReading {
    let co2: Int
    let temperature: Double
    let pressure: Double
    let humidity: Int
    let battery: Int
    let timestamp: Date

    var co2Level: CO2Level {
        if co2 < 800 { return .excellent }
        if co2 < 1000 { return .good }
        if co2 < 1400 { return .fair }
        return .poor
    }

    enum CO2Level: String {
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case poor = "Poor"
    }
}

@MainActor
class AranetService: NSObject, ObservableObject {
    @Published var latestReading: AranetReading?
    @Published var isConnected = false
    @Published var isScanning = false
    @Published var lastError: String?
    @Published var deviceName: String?

    private var centralManager: CBCentralManager!
    private var aranetPeripheral: CBPeripheral?
    private var pollTimer: Timer?
    private var reconnectTimer: Timer?
    private var readingsCharacteristic: CBCharacteristic?

    private static let aranetServiceUUID = CBUUID(string: "f0cd1400-95da-4f4b-9ac8-aa55d312af0c")
    private static let aranetServiceV2UUID = CBUUID(string: "FCE0")
    private static let currentReadingsUUID = CBUUID(string: "f0cd1503-95da-4f4b-9ac8-aa55d312af0c")

    private var delegateBridge: AranetBLEDelegate!

    override init() {
        super.init()
        delegateBridge = AranetBLEDelegate(service: self)
        centralManager = CBCentralManager(delegate: delegateBridge, queue: nil)
    }

    func startScanning() {
        guard centralManager.state == .poweredOn else {
            lastError = "Bluetooth not available"
            return
        }
        isScanning = true
        lastError = nil
        centralManager.scanForPeripherals(
            withServices: [Self.aranetServiceUUID, Self.aranetServiceV2UUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self, self.isScanning, self.aranetPeripheral == nil else { return }
            self.centralManager.stopScan()
            self.isScanning = false
            self.lastError = "No Aranet4 found nearby"
        }
    }

    func disconnect() {
        pollTimer?.invalidate()
        pollTimer = nil
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        if let peripheral = aranetPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        aranetPeripheral = nil
        readingsCharacteristic = nil
        isConnected = false
        deviceName = nil
    }

    func refreshReading() {
        guard let peripheral = aranetPeripheral,
              let characteristic = readingsCharacteristic,
              peripheral.state == .connected else {
            scheduleReconnect()
            return
        }
        peripheral.readValue(for: characteristic)
    }

    // MARK: - BLE Callbacks

    fileprivate func didUpdateState(_ state: CBManagerState) {
        if state == .poweredOn, !isConnected, aranetPeripheral == nil {
            startScanning()
        } else if state != .poweredOn {
            isConnected = false
            if state == .poweredOff { lastError = "Bluetooth is off" }
        }
    }

    fileprivate func didDiscover(_ peripheral: CBPeripheral, name: String?) {
        centralManager.stopScan()
        isScanning = false
        aranetPeripheral = peripheral
        deviceName = name ?? "Aranet4"
        peripheral.delegate = delegateBridge
        centralManager.connect(peripheral, options: nil)
    }

    fileprivate func didConnect(_ peripheral: CBPeripheral) {
        isConnected = true
        lastError = nil
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        peripheral.discoverServices([Self.aranetServiceUUID, Self.aranetServiceV2UUID])
    }

    fileprivate func didDisconnect() {
        isConnected = false
        readingsCharacteristic = nil
        scheduleReconnect()
    }

    fileprivate func didDiscoverCharacteristic(_ characteristic: CBCharacteristic) {
        if characteristic.uuid == Self.currentReadingsUUID {
            readingsCharacteristic = characteristic
            aranetPeripheral?.readValue(for: characteristic)
            startPolling()
        }
    }

    fileprivate func didUpdateValue(_ data: Data) {
        guard let reading = parseReading(data) else { return }
        latestReading = reading
        lastError = nil
    }

    // MARK: - Polling & Reconnect

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshReading() }
        }
    }

    private func scheduleReconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if let p = self.aranetPeripheral, p.state == .disconnected {
                    self.centralManager.connect(p, options: nil)
                } else if self.aranetPeripheral == nil {
                    self.startScanning()
                }
            }
        }
    }

    private func parseReading(_ data: Data) -> AranetReading? {
        guard data.count >= 7 else { return nil }
        let co2 = Int(data[0]) | (Int(data[1]) << 8)
        let tempRaw = Int(data[2]) | (Int(data[3]) << 8)
        let pressureRaw = Int(data[4]) | (Int(data[5]) << 8)
        let humidity = Int(data[6])
        let battery = data.count >= 8 ? Int(data[7]) : 0
        return AranetReading(
            co2: co2,
            temperature: Double(tempRaw) * 0.05,
            pressure: Double(pressureRaw) * 0.1,
            humidity: humidity,
            battery: battery,
            timestamp: Date()
        )
    }
}

// MARK: - BLE Delegate Bridge

private class AranetBLEDelegate: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    weak var service: AranetService?

    init(service: AranetService) {
        self.service = service
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        MainActor.assumeIsolated { service?.didUpdateState(central.state) }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                         advertisementData: [String: Any], rssi: NSNumber) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
        MainActor.assumeIsolated { service?.didDiscover(peripheral, name: name) }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        MainActor.assumeIsolated { service?.didConnect(peripheral) }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        MainActor.assumeIsolated { service?.didDisconnect() }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for svc in services { peripheral.discoverCharacteristics(nil, for: svc) }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let chars = service.characteristics else { return }
        for char in chars {
            MainActor.assumeIsolated { self.service?.didDiscoverCharacteristic(char) }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        MainActor.assumeIsolated { service?.didUpdateValue(data) }
    }
}
