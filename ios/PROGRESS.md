# Mouse Mover iOS — Progress

Living checklist for the iOS companion app. Update this file at the end of each phase.

| Phase | Status | Notes |
|-------|--------|-------|
| 0 — Firmware device identity | Pending | Multi-device fields in `/api/status` (see [PR #7](https://github.com/natarajgithub/mouseMover/pull/7)) |
| 1 — App scaffold | Done | Xcode project, models, service stubs |
| 2 — Device list & control | Done | SwiftData list, rename, jiggle toggles, add-by-address |
| 3 — Bonjour discovery | In progress | Phase 3a: LAN scan wizard (this PR) |
| 4 — Soft-AP provisioning | Not started | Join setup AP, POST `/api/wifi` |
| 5 — Persistence & polish | Partial | SwiftData sync done; Keychain token storage pending |

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

## Phase 2 — Device list & control

- [x] `DeviceRepository` — load/save, concurrent `refreshAll`, jiggle/rename/delete/token
- [x] `DeviceEndpointResolver` — mDNS-first URL resolution with STA IP fallback
- [x] Home device list (`ContentView`) with jiggle toggles and offline badge
- [x] Pull-to-refresh status for all saved devices
- [x] `DeviceDetailView` — rename, device info, auth token, jiggle, delete
- [x] Add-by-address sheet for manual testing (wizard placeholder in toolbar)
- [x] DEBUG sample device button on empty state
- [x] Unit tests: `DeviceRepository.setJiggle`, endpoint URL resolution

## Phase 3 — Bonjour discovery

### Phase 3a — Add-device wizard (LAN mDNS scan)

- [x] `BonjourBrowser` — `NWBrowser` for `_http._tcp`, filter by TXT `id` or `hid-helper` name
- [x] `BonjourDiscoveryFilter` — unit-tested candidate matching
- [x] `AddDeviceWizardView` — choose path, scan list, probe `/api/status`, confirm & save
- [x] Soft-AP path disabled with "Coming next" placeholder
- [x] Home `+` and empty state wired to wizard sheet
- [x] `DeviceRepository.addFromDiscovery` for wizard save
- [x] Unit tests: filter logic, wizard view model state transitions (mock browser + API)

### Phase 3b — (next)

- [ ] Soft-AP provisioning wizard path
- [ ] Auto-add on discovery (optional polish)

## Phase 4 — Soft-AP provisioning

- [ ] Implement `SoftAPJoiner` (NEHotspotConfiguration or manual flow)
- [ ] Provision WiFi credentials on `192.168.4.1`
- [ ] Rejoin home WiFi and rediscover device

## Phase 5 — Persistence & polish

- [x] Persist known devices with SwiftData
- [x] Custom display names
- [ ] API token in Keychain
- [ ] Onboarding / local network permission prompt copy
- [ ] App icon and TestFlight build
