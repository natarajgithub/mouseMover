# Mouse Mover (Android)

Kotlin + Jetpack Compose companion for **usb-hid-s3** / **hid-helper** firmware **0.4.0+**.

## Requirements

- Android Studio Ladybug+ or JDK 17
- Android SDK 35
- Emulator AVD API 34+ for day-to-day runs
- Physical device for Soft-AP join / Nearby Wi‑Fi permission QA

## Build & test

```bash
cd android
./gradlew :app:testDebugUnitTest
./gradlew :app:assembleDebug
./gradlew :app:installDebug   # with emulator/device attached
```

## Architecture (scaffold)

| Package | Role |
|---------|------|
| `network/` | DTOs, OkHttp API client, endpoint resolver |
| `data/` | Room entity stub |
| `discovery/` | NSD browser interface + stub (`RadioDiscovery` seam for future BLE) |
| `wifi/` | Soft-AP joiner interface + stub |
| `ui/` | Compose screens |

## Soft-AP / emulator note

Joining `usb-hid-s3-XXXX` via `WifiNetworkSpecifier` is **not reliable on the emulator**. Path B will support Continue-after-manual Wi‑Fi (same as iOS Simulator).

## Security

LAN/Soft-AP control is unauthenticated unless firmware `CONTROL_API_TOKEN` is set. Prefer that on shared networks. See root [`SECURITY.md`](../SECURITY.md).

## Progress

See [`PROGRESS.md`](PROGRESS.md).
