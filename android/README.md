# Mouse Mover (Android)

Kotlin + Jetpack Compose companion for **usb-hid-s3** / **hid-helper** firmware **0.4.0+**.

Feature parity with the [iOS Mouse Mover](../ios/) app: device list, LED-matched presence, jiggle, add-by-address confirm, LAN NSD scan, Soft-AP provisioning.

## Requirements

- Android Studio Ladybug+ or JDK 17
- Android SDK 35 (`compileSdk` / `targetSdk` 35, `minSdk` 26)
- Emulator AVD API 34+ for day-to-day runs
- Physical device for Soft-AP join / Nearby Wi‑Fi permission QA

## Build & test

```bash
cd android
./gradlew :app:testDebugUnitTest
./gradlew :app:assembleDebug
./gradlew :app:installDebug
```

## Architecture

| Package | Role |
|---------|------|
| `network/` | DTOs, OkHttp API client, endpoint resolver, presence |
| `data/` | Room DB + repository |
| `discovery/` | NSD browser, filter/dedupe, `SavedDeviceIndex` (`RadioDiscovery` seam for future BLE) |
| `wifi/` | Soft-AP joiner (`WifiNetworkSpecifier`) |
| `ui/` / `viewmodel/` | Compose screens + ViewModels |

## Soft-AP / emulator note

Joining `usb-hid-s3-XXXX` via `WifiNetworkSpecifier` is **not reliable on the emulator**. Path B supports **Continue** after you join Soft-AP in system Wi‑Fi settings (same lesson as iOS Simulator).

## Security

LAN/Soft-AP control is unauthenticated unless firmware `CONTROL_API_TOKEN` is set. Prefer that on shared networks. Tokens are stored in Room (same tradeoff as iOS SwiftData today). See root [`SECURITY.md`](../SECURITY.md).

## Manual QA checklist

- [ ] Unit tests via Gradle
- [ ] Emulator empty state + install
- [ ] Add by address to live device (host LAN reachable from emulator)
- [ ] Jiggle / rename / delete / pull-to-refresh / presence poll (~15s)
- [ ] Device: NSD scan finds `hid-helper-xxxx`
- [ ] Device: Soft-AP Path B provisions home Wi‑Fi
- [ ] Emulator Soft-AP: Continue after manual Wi‑Fi
