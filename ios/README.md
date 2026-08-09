# Mouse Mover (iOS)

SwiftUI companion app for discovering and controlling **mouseMover** ESP32-S3 devices over the local network.

## Security

**LAN and Soft-AP control can move the mouse and type on the host PC** attached to the device. Anyone on the same Wi‑Fi (or on the device’s open setup network during provisioning) can call the REST API unless you harden the firmware.

- Use only on **trusted networks** you control.
- Prefer home/lab Wi‑Fi; avoid public hotspots for provisioning or daily use.
- Optionally set **`CONTROL_API_TOKEN`** in firmware (`usb-hid-s3/include/wifi_secrets.h` or build flags) and enter the same token in the app’s device detail screen. When set, firmware requires `X-API-Token` on `/api/*` requests.
- See [`../SECURITY.md`](../SECURITY.md) for the full firmware threat model.

## Requirements

- Xcode 15+ (Swift 5.9+)
- iOS 17.0 deployment target
- macOS for building and Simulator testing
- **Firmware 0.4.0+** for multi-device identity (`device_id`, per-device mDNS suffix, Soft-AP SSID). Older firmware may still work with host-based fallbacks; see [PR #7](https://github.com/natarajgithub/mouseMover/pull/7).

## Project layout

| Path | Purpose |
|------|---------|
| `MouseMover/` | App sources, assets, Info.plist |
| `MouseMoverTests/` | Unit tests (API decoding, wizard state, etc.) |
| `PROGRESS.md` | Phase checklist and manual QA |

## Build and run

### Xcode (recommended)

1. Open `MouseMover.xcodeproj` in Xcode.
2. Select the **MouseMover** scheme.
3. Choose **iPhone Simulator** (e.g. iPhone 17) or a connected device.
4. **Product → Run** (⌘R).

On first launch, iOS prompts for **local network** access — required for Bonjour discovery and HTTP control.

### Command line

```bash
cd ios
xcodebuild -project MouseMover.xcodeproj -scheme MouseMover \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

xcodebuild -project MouseMover.xcodeproj -scheme MouseMover \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

### Physical device — Soft-AP wizard

Path B of the add-device wizard uses `NEHotspotConfiguration` to join the firmware setup AP. On a **real iPhone**, your Apple Developer provisioning profile must include the **Hotspot Configuration** capability (`com.apple.developer.networking.HotspotConfiguration`). Without it, the wizard falls back to manual **Settings → Wi‑Fi** instructions.

Simulator cannot join Soft-AP networks; use Path A (LAN scan) or add-by-address for Simulator testing.

## Add-device wizard

Tap **+** on the home screen to open the wizard. Two paths:

| Path | When to use | Flow |
|------|-------------|------|
| **A — Scan local network** | Device already on your home Wi‑Fi | Bonjour browse `_http._tcp`, filter HID helpers, probe `/api/status`, confirm & save |
| **B — Set up new device (Soft‑AP)** | Fresh or unprovisioned device | Join firmware Soft-AP → read `/api/wifi` → POST home SSID/password → reconnect to home Wi‑Fi → rediscover on LAN (or enter address manually) |

Both paths share the same confirm/save step. Path B filters Bonjour results by `device_id` when firmware reports it.

Manual **Add by address** (toolbar) remains available for lab testing without discovery.

## Capabilities

Configured in `MouseMover/Info.plist`:

- Local network usage (Bonjour + HTTP to LAN devices)
- Bonjour service type `_http._tcp.`
- App Transport Security: local networking allowed

## Bundle ID

`com.mkflabs.mousemover`

## Manual QA

See [`PROGRESS.md`](PROGRESS.md#manual-qa-checklist) for a release smoke checklist.
