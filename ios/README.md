# Mouse Mover (iOS)

SwiftUI companion app for discovering and controlling **mouseMover** ESP32-S3 devices over the local network.

## Requirements

- Xcode 15+ (Swift 5.9+)
- iOS 17.0 deployment target
- macOS for building and Simulator testing

## Project layout

| Path | Purpose |
|------|---------|
| `MouseMover/` | App sources, assets, Info.plist |
| `MouseMoverTests/` | Unit tests (API decoding, etc.) |
| `PROGRESS.md` | Phase checklist for app delivery |

## Build

```bash
cd ios
xcodebuild -project MouseMover.xcodeproj -scheme MouseMover \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Open `MouseMover.xcodeproj` in Xcode to run on Simulator or a device.

## Firmware dependency

Multi-device identity fields (`device_id`, per-device mDNS suffix) require firmware **0.4.0** — see firmware PR #7. The app decodes those fields when present and falls back to host-based IDs on older firmware.

## Capabilities

Configured in `MouseMover/Info.plist`:

- Local network usage (Bonjour + HTTP to LAN devices)
- Bonjour service type `_http._tcp.`
- App Transport Security: local networking allowed

## Bundle ID

`com.mkflabs.mousemover`
