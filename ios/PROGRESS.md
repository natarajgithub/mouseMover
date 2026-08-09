# Mouse Mover iOS — Progress

Living checklist for the iOS companion app. Update this file at the end of each phase.

## Delivery phases

| Phase | Status | PR / notes |
|-------|--------|------------|
| 0 — Firmware device identity | Done (firmware) | [`device_id` + unique mDNS/Soft-AP — PR #7](https://github.com/natarajgithub/mouseMover/pull/7) |
| 1 — App scaffold | Done | [PR #8](https://github.com/natarajgithub/mouseMover/pull/8) |
| 2 — Device list & control | Done | [PR #9](https://github.com/natarajgithub/mouseMover/pull/9) |
| 3 — Bonjour discovery | Done | [PR #10](https://github.com/natarajgithub/mouseMover/pull/10) (LAN scan) |
| 4 — Soft-AP provisioning | Done | [PR #11](https://github.com/natarajgithub/mouseMover/pull/11) |
| 5 — Persistence & polish | Done | Docs, SECURITY note, QA checklist (this branch) |

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
- [x] Soft-AP path placeholder (Phase 3b replaces)
- [x] Home `+` and empty state wired to wizard sheet
- [x] `DeviceRepository.addFromDiscovery` for wizard save
- [x] Unit tests: filter logic, wizard view model state transitions (mock browser + API)

### Phase 3b — Soft-AP provisioning wizard

- [x] `SoftAPJoiner` — `NEHotspotConfiguration` join with open/passphrase APs; simulator-safe errors
- [x] `SoftAPJoinerProtocol` + `MockSoftAPJoiner` for unit tests
- [x] Wizard Path B — instructions, join SSID, probe `192.168.4.1/api/wifi`, home Wi‑Fi form, provision, reconnect prompt, LAN rediscover + manual address fallback
- [x] `WifiStatus` decodes `device_id`, `ap_ssid`, `ap_ip` (firmware 0.4.0)
- [x] Reuses Path A confirm/save; filters Bonjour by expected `device_id`
- [x] Unit tests: Soft-AP wizard state machine (mock joiner + API + browser)

### Phase 3c — (optional polish)

- [ ] Auto-add on discovery

## Phase 4 — Soft-AP provisioning

- [x] Implement `SoftAPJoiner` (NEHotspotConfiguration + manual Settings fallback)
- [x] Provision WiFi credentials on `192.168.4.1`
- [x] Rejoin home WiFi and rediscover device

## Phase 5 — Persistence & polish

- [x] Persist known devices with SwiftData
- [x] Custom display names
- [x] App icon (`Assets.xcassets/AppIcon.appiconset`)
- [x] Local network permission copy (`NSLocalNetworkUsageDescription`)
- [x] `ios/README.md` — SECURITY note, build/run, wizard overview, firmware 0.4.0+
- [x] Manual QA checklist (below)
- [ ] API token in Keychain (stored in SwiftData today; Keychain migration deferred)
- [ ] TestFlight / App Store build

## Manual QA checklist

Run on Simulator unless noted. Physical device required for Soft-AP join and local-network prompt.

- [ ] **Unit tests** — `cd ios && xcodebuild … test` (see [`README.md`](README.md))
- [ ] **Empty state** — launch with no devices; empty copy and **+** visible
- [ ] **Add by address** — save a lab device by IP/hostname; list shows offline until refresh
- [ ] **Wizard Path A** — scan finds Bonjour candidate (or empty scan on Simulator); probe + save
- [ ] **Wizard Path B** (device) — join Soft-AP, provision home Wi‑Fi, rediscover or manual fallback
- [ ] **Jiggle toggle** — enable/disable on live device; host mouse moves when enabled
- [ ] **Rename** — detail screen display name persists after relaunch
- [ ] **Delete** — remove device from list and SwiftData
- [ ] **Pull to refresh** — updates online/offline badges
- [ ] **API token** (optional) — with firmware `CONTROL_API_TOKEN` set, token in detail screen unlocks control
- [ ] **Local network prompt** — first Bonjour scan triggers iOS permission dialog
