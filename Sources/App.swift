import SwiftUI

@main
struct BLERadarApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    @StateObject private var scanner = BLEScanner()
    @State private var selected: UUID? = nil
    private let bg = Color(red: 0.039, green: 0.035, blue: 0.075)
    private let lav = Color(red: 0.725, green: 0.639, blue: 1.0)

    private var sorted: [BLEDevice] {
        scanner.devices.values.sorted { $0.rssi > $1.rssi }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            bg.ignoresSafeArea()
            VStack(spacing: 0) {
                // header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("◴ BLE RADAR 333").font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundColor(lav).tracking(2)
                        Text("\(sorted.count) DEVICES · \(scanner.status.uppercased())")
                            .font(.system(size: 10, design: .monospaced)).foregroundColor(lav.opacity(0.5))
                    }
                    Spacer()
                }.padding(.horizontal, 16).padding(.top, 8)

                RadarCanvas(devices: sorted, selected: $selected)
                    .frame(height: UIScreen.main.bounds.width)

                // device list
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(sorted) { d in
                            DeviceRow(d: d, selected: d.id == selected)
                                .onTapGesture { selected = d.id }
                        }
                    }.padding(8)
                }
            }
            // detail card overlay (live)
            if let id = selected, let d = scanner.devices[id] {
                DetailCard(d: d) { selected = nil }
                    .padding(12)
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct DeviceRow: View {
    let d: BLEDevice; let selected: Bool
    var body: some View {
        HStack(spacing: 9) {
            Circle().fill(vendorColor(d.vendor)).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 1) {
                Text(friendlyName(d)).font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Color(red: 0.91, green: 0.88, blue: 1.0)).lineLimit(1)
                Text("\(d.vendor) · \(d.id.uuidString.prefix(13))…")
                    .font(.system(size: 9, design: .monospaced)).foregroundColor(.gray).lineLimit(1)
            }
            Spacer()
            Text("\(d.rssi) dBm").font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(red: 0.61, green: 0.53, blue: 0.88))
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(selected ? 0.10 : 0.03)))
        .overlay(RoundedRectangle(cornerRadius: 8)
            .stroke(Color(red: 0.435, green: 0.341, blue: 0.769), lineWidth: selected ? 1 : 0))
    }
}

struct DetailCard: View {
    let d: BLEDevice; let close: () -> Void
    private let lav = Color(red: 0.725, green: 0.639, blue: 1.0)

    private func near(_ m: Double) -> String {
        m < 1.2 ? "very close" : m < 4 ? "near" : m < 10 ? "same room" : "far"
    }
    private func row(_ k: String, _ v: String) -> some View {
        HStack { Text(k).font(.system(size: 11, design: .monospaced)).foregroundColor(.gray)
            Spacer()
            Text(v).font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color(red: 0.80, green: 0.74, blue: 1.0))
                .multilineTextAlignment(.trailing) }
    }
    var body: some View {
        let dist = estDistanceM(d)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle().fill(vendorColor(d.vendor)).frame(width: 10, height: 10)
                Text(friendlyName(d)).font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white).lineLimit(1)
                Spacer()
                Button(action: close) { Text("✕").foregroundColor(.gray) }
            }
            row("Vendor", d.vendor)
            row("ID", String(d.id.uuidString.prefix(18)) + "…")
            row("Signal", "\(d.rssi) dBm")
            row("Distance ≈", String(format: "%.1f m · %@", dist, near(dist)))
            row("Name", d.name.isEmpty ? "— not advertised" : d.name)
            row("Company ID", d.company)
            row("Services", "\(d.services)")
            row("Tx power", d.tx != nil ? "\(d.tx!) dBm" : "—")
        }
        .padding(12)
        .frame(width: 260)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.051, green: 0.043, blue: 0.094).opacity(0.96)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 0.227, green: 0.184, blue: 0.388), lineWidth: 1))
    }
}
