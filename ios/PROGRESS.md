# Mouse Mover iOS — Progress

Living checklist for the iOS companion app. Update this file at the end of each phase.

| Phase | Status | Notes |
|-------|--------|-------|
| 0 — Firmware device identity | Pending | Multi-device fields in `/api/status` (see [PR #7](https://github.com/natarajgithub/mouseMover/pull/7)) |
| 1 — App scaffold | In progress | Xcode project, models, service stubs |
| 2 — Bonjour discovery | Not started | NWBrowser, device list UI |
| 3 — Device control | Not started | Status, jiggle toggle, auth token |
| 4 — Soft-AP provisioning | Not started | Join setup AP, POST `/api/wifi` |
| 5 — Persistence & polish | Not started | SwiftData sync, settings, error UX |

## Phase 1 — App scaffold

- [x] Xcode project (`MouseMover.xcodeproj`) builds for iOS Simulator
- [x] SwiftUI app entry + placeholder home empty state
- [x] `Device` model + `DeviceStatus` Codable (firmware 0.4.0 shape)
- [x] `DeviceAPIClientProtocol` + URLSession `status` GET decoding
- [x] Service stubs: `BonjourBrowser`, `SoftAPJoiner`
- [x] `DeviceStore` SwiftData model stub
- [x] `HomeViewModel` stub
- [x] Info.plist: local network, Bonjour, ATS local networking
- [x] Unit test: decode stub `/api/status` JSON
- [x] `ios/README.md`

## Phase 2 — Bonjour discovery (next)

- [ ] Implement `BonjourBrowser` with `NWBrowser` for `_http._tcp.`
- [ ] Resolve host/port and probe `/api/status`
- [ ] Replace home empty state with discovered device list
- [ ] Handle duplicate entries by `device_id`

## Phase 3 — Device control

- [ ] Device detail screen (name, IP, firmware, jiggle state)
- [ ] Jiggle on/off via `POST /api/jiggle`
- [ ] Optional API token storage (Keychain)
- [ ] Pull-to-refresh status

## Phase 4 — Soft-AP provisioning

- [ ] Implement `SoftAPJoiner` (NEHotspotConfiguration or manual flow)
- [ ] Provision WiFi credentials on `192.168.4.1`
- [ ] Rejoin home WiFi and rediscover device

## Phase 5 — Persistence & polish

- [ ] Persist known devices with SwiftData
- [ ] Custom display names
- [ ] Onboarding / local network permission prompt copy
- [ ] App icon and TestFlight build
