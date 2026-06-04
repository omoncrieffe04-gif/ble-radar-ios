# BLE Radar 333 — iPhone (standalone, runs with the computer off)

A native SwiftUI + CoreBluetooth radar that scans nearby Bluetooth-LE devices and plots them by
signal strength, **on the iPhone itself** — clickable dots, vendor names, live detail card.
Same JARVIS look as the desktop version, but it needs no computer once installed.

> **Built on Windows? Yes — via a cloud Mac.** You don't own a Mac, so GitHub Actions builds the
> `.ipa` for you on a macOS runner; you install it with **AltStore** using your own Apple ID.

---

## What it does (and the honest limits)
- Scans **all advertising BLE devices**, places each as a blip (closer to centre = stronger signal),
  tap a dot for a detail card (vendor, signal, rough distance, company ID, services, Tx power).
- **Limits iOS imposes** (unavoidable): BLE only (no Classic BT); you get a per-app **UUID, not the
  MAC**; it's **proximity, not a geographic map**; and reliable scanning is **foreground** (iOS
  throttles background BLE). "Computer off" = ✅; "phone screen off / app closed" = scanning pauses.

## Build it (no Mac needed)
1. Create a **free GitHub account** and a new repo, e.g. `ble-radar-ios`.
2. Upload this whole folder (drag the files into the repo's web uploader, keeping the
   `Sources/` and `.github/` folders). Commit.
3. GitHub → **Actions** tab → the **Build IPA** workflow runs automatically (~3–5 min).
   Open the finished run → **Artifacts** → download **`BLERadar-unsigned-ipa`** → unzip to get
   `BLERadar-unsigned.ipa`. (It's unsigned on purpose — AltStore signs it with your Apple ID.)

## Install it with AltStore (your Apple ID)
AltStore sideloads the `.ipa` and re-signs it with a **free Apple ID** (no $99 account needed).
1. On a Windows PC **once**: install **AltServer** (altstore.io), plug in the iPhone, install
   **AltStore** to the phone, sign in with your Apple ID.
2. In **AltStore → My Apps → +**, pick `BLERadar-unsigned.ipa`. It installs to your home screen.
3. Launch it, tap **Allow** on the Bluetooth prompt — the radar goes live. **Computer can now be
   off**; the app scans on the iPhone.

### The one catch with free sideloading
A free Apple ID signature **expires after 7 days** — AltStore "refreshes" it (reconnect to
AltServer on the PC, or use **SideStore** to refresh on-device over Wi-Fi with no computer).
A **paid Apple Developer account ($99/yr)** removes the 7-day limit (1-year signing). Your call —
the app code is identical either way.

## Files
- `Sources/Scanner.swift` — CoreBluetooth scan + device model + vendor (company-ID) map
- `Sources/Radar.swift` — radar canvas geometry, blip placement, tap hit-test, vendor colours
- `Sources/App.swift` — app entry, header, device list, live detail card
- `project.yml` — XcodeGen spec (generates the Xcode project on the runner; no fragile .xcodeproj)
- `.github/workflows/build-ipa.yml` — cloud-Mac build → unsigned `.ipa` artifact

## Want the easy route instead?
**nRF Connect** or **LightBlue** on the App Store scan all nearby BLE devices standalone, today,
no build. This custom app is for the JARVIS-styled radar + your own tweaks.
