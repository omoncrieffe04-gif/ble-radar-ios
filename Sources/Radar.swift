import SwiftUI

// ---- shared geometry so draw + tap hit-test agree ----
func radarRadius(_ size: CGSize) -> CGFloat { min(size.width, size.height) / 2 - 30 }

func blipAngle(_ id: UUID) -> Double {
    var h: UInt64 = 1469598103934665603
    for b in id.uuidString.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
    return Double(h % 3600) / 3600.0 * 2 * .pi
}

func blipRadius(_ rssi: Int, _ R: CGFloat) -> CGFloat {
    let clamped = Double(max(-100, min(-35, rssi)))
    let t = (clamped + 100) / 65            // 0 far .. 1 near
    return R * CGFloat(1 - t) * 0.92 + 12
}

func blipPoint(_ d: BLEDevice, _ size: CGSize) -> CGPoint {
    let R = radarRadius(size)
    let a = blipAngle(d.id)
    let r = blipRadius(d.rssi, R)
    return CGPoint(x: size.width / 2 + cos(a) * r, y: size.height / 2 + sin(a) * r)
}

func vendorColor(_ v: String) -> Color {
    switch v {
    case "Apple": return Color(red: 0.87, green: 0.90, blue: 1.0)
    case "Samsung": return Color(red: 0.36, green: 0.62, blue: 1.0)
    case "Google": return Color(red: 0.37, green: 0.82, blue: 0.54)
    case "Govee": return Color(red: 0.21, green: 0.84, blue: 0.76)
    case "Microsoft": return Color(red: 0.26, green: 0.84, blue: 0.84)
    case "Sony": return Color(red: 0.79, green: 0.63, blue: 1.0)
    case "Bose": return Color(red: 1.0, green: 0.62, blue: 0.44)
    default: return Color(red: 0.61, green: 0.48, blue: 1.0)
    }
}

func friendlyName(_ d: BLEDevice) -> String {
    let n = d.name.trimmingCharacters(in: .whitespaces)
    if !n.isEmpty { return n }
    let known = d.vendor != "unknown" && !d.vendor.hasPrefix("0x")
    let tail = String(d.id.uuidString.suffix(4))
    return known ? "\(d.vendor) \(tail)" : "·\(d.id.uuidString.suffix(6))"
}

func estDistanceM(_ d: BLEDevice) -> Double {
    let tx = Double(d.tx ?? -59), n = 2.5
    return pow(10, (tx - Double(d.rssi)) / (10 * n))
}

struct RadarCanvas: View {
    let devices: [BLEDevice]
    @Binding var selected: UUID?
    private let lav = Color(red: 0.725, green: 0.639, blue: 1.0)

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                Canvas { ctx, sz in
                    let cx = sz.width / 2, cy = sz.height / 2, R = radarRadius(sz)
                    // range rings
                    for (rssi, lab) in [(-40, "-40"), (-55, "-55"), (-70, "-70"), (-85, "-85"), (-100, "-100")] {
                        let rr = blipRadius(rssi, R)
                        ctx.stroke(Path(ellipseIn: CGRect(x: cx - rr, y: cy - rr, width: rr * 2, height: rr * 2)),
                                   with: .color(lav.opacity(0.16)))
                        ctx.draw(Text(lab).font(.system(size: 9, design: .monospaced)).foregroundColor(lav.opacity(0.4)),
                                 at: CGPoint(x: cx + 14, y: cy - rr + 8))
                    }
                    // sweep
                    let sweep = (t * 1.1).truncatingRemainder(dividingBy: 2 * .pi)
                    var wedge = Path()
                    wedge.move(to: CGPoint(x: cx, y: cy))
                    wedge.addArc(center: CGPoint(x: cx, y: cy), radius: R,
                                 startAngle: .radians(sweep - 0.5), endAngle: .radians(sweep), clockwise: false)
                    ctx.fill(wedge, with: .radialGradient(Gradient(colors: [lav.opacity(0.28), .clear]),
                             center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: R))
                    var line = Path()
                    line.move(to: CGPoint(x: cx, y: cy))
                    line.addLine(to: CGPoint(x: cx + cos(sweep) * R, y: cy + sin(sweep) * R))
                    ctx.stroke(line, with: .color(lav.opacity(0.55)))
                    // centre = YOU
                    let pr = 6 + 3 * sin(t * 3)
                    ctx.stroke(Path(ellipseIn: CGRect(x: cx - pr, y: cy - pr, width: pr * 2, height: pr * 2)),
                               with: .color(lav.opacity(0.5)))
                    ctx.fill(Path(ellipseIn: CGRect(x: cx - 4, y: cy - 4, width: 8, height: 8)), with: .color(lav))
                    ctx.draw(Text("YOU").font(.system(size: 9, design: .monospaced)).foregroundColor(lav.opacity(0.6)),
                             at: CGPoint(x: cx, y: cy + 16))
                    // devices
                    for d in devices {
                        let p = blipPoint(d, sz)
                        let c0 = vendorColor(d.vendor)
                        let sel = d.id == selected
                        let fade = max(0.3, 1 - d.lastSeen.distance(to: tl.date) / 45)
                        ctx.fill(Path(ellipseIn: CGRect(x: p.x - (sel ? 6 : 4), y: p.y - (sel ? 6 : 4),
                                 width: (sel ? 12 : 8), height: (sel ? 12 : 8))), with: .color(c0.opacity(fade)))
                        if sel {
                            ctx.stroke(Path(ellipseIn: CGRect(x: p.x - 12, y: p.y - 12, width: 24, height: 24)),
                                       with: .color(.white), lineWidth: 1.5)
                        }
                        ctx.draw(Text(friendlyName(d)).font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(sel ? .white : lav.opacity(0.9)),
                                 at: CGPoint(x: p.x + 38, y: p.y), anchor: .leading)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(SpatialTapGesture().onEnded { ev in
                var best: UUID? = nil; var bd: CGFloat = 26
                for d in devices {
                    let p = blipPoint(d, size)
                    let dd = hypot(p.x - ev.location.x, p.y - ev.location.y)
                    if dd < bd { bd = dd; best = d.id }
                }
                selected = best
            })
        }
    }
}
