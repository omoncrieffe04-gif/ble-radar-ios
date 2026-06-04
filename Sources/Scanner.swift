import Foundation
import CoreBluetooth

// One discovered BLE device (keyed by iOS per-app UUID — Apple hides the real MAC).
struct BLEDevice: Identifiable, Equatable {
    let id: UUID
    var name: String
    var rssi: Int
    var vendor: String
    var company: String
    var services: Int
    var tx: Int?
    var firstSeen: Date
    var lastSeen: Date
}

final class BLEScanner: NSObject, ObservableObject, CBCentralManagerDelegate {
    @Published var devices: [UUID: BLEDevice] = [:]
    @Published var status: String = "starting…"
    private var central: CBCentralManager!
    private var pruneTimer: Timer?

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
        // drop devices not seen for 45 s so the radar stays live
        pruneTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let cutoff = Date().addingTimeInterval(-45)
            let stale = self.devices.filter { $0.value.lastSeen < cutoff }.map { $0.key }
            if !stale.isEmpty { for k in stale { self.devices.removeValue(forKey: k) } }
        }
    }

    func centralManagerDidUpdateState(_ c: CBCentralManager) {
        switch c.state {
        case .poweredOn:    status = "scanning"; startScan()
        case .poweredOff:   status = "Bluetooth is OFF"
        case .unauthorized: status = "Bluetooth permission denied"
        case .unsupported:  status = "BLE unsupported"
        default:            status = "waiting…"
        }
    }

    func startScan() {
        central.scanForPeripherals(withServices: nil,
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }

    func centralManager(_ c: CBCentralManager, didDiscover p: CBPeripheral,
                        advertisementData adv: [String: Any], rssi RSSI: NSNumber) {
        let id = p.identifier
        let advName = (adv[CBAdvertisementDataLocalNameKey] as? String) ?? p.name ?? ""
        var vendor = "unknown"
        var company = "—"
        if let md = adv[CBAdvertisementDataManufacturerDataKey] as? Data, md.count >= 2 {
            let cid = UInt16(md[0]) | (UInt16(md[1]) << 8)
            company = String(format: "0x%04x", cid)
            vendor = Self.companies[cid] ?? company
        }
        let svc = (adv[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?.count ?? 0
        let tx = (adv[CBAdvertisementDataTxPowerLevelKey] as? NSNumber)?.intValue
        let now = Date()
        if var d = devices[id] {
            if !advName.isEmpty { d.name = advName }
            d.rssi = RSSI.intValue; d.vendor = vendor; d.company = company
            d.services = svc; if tx != nil { d.tx = tx }; d.lastSeen = now
            devices[id] = d
        } else {
            devices[id] = BLEDevice(id: id, name: advName, rssi: RSSI.intValue, vendor: vendor,
                                    company: company, services: svc, tx: tx,
                                    firstSeen: now, lastSeen: now)
        }
    }

    // Bluetooth SIG company identifiers (common subset; falls back to hex)
    static let companies: [UInt16: String] = [
        0x004C: "Apple", 0x0006: "Microsoft", 0x0075: "Samsung", 0x00E0: "Google",
        0x0059: "Nordic", 0x000F: "Broadcom", 0x0087: "Garmin", 0x009E: "Bose",
        0x012D: "Sony", 0x00C4: "LG", 0x038F: "Xiaomi", 0x027D: "Huawei",
        0x0499: "Ruuvi", 0x8802: "Govee", 0x0157: "Amazfit", 0x0171: "Amazon",
        0x004F: "Logitech", 0x05A7: "Sonos", 0x0118: "Tile", 0x0822: "Adafruit",
    ]
}
