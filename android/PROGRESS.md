# Mouse Mover Android — Progress

Living checklist. Update at the end of each phase.

## Delivery phases

| Phase | Status | Branch / PR |
|-------|--------|-------------|
| 1 — App scaffold | In progress | `android/scaffold` |
| 2 — Device list & control | Pending | `android/device-list-jiggle` |
| 3 — NSD discovery wizard | Pending | `android/wizard-mdns-scan` |
| 4 — Soft-AP provisioning | Pending | `android/wizard-softap` |
| 5 — Polish & CI | Pending | `android/polish` |

## Phase 1 — App scaffold

- [x] Gradle Compose app (`com.mkflabs.mousemover`, minSdk 26, targetSdk 35)
- [x] Empty home state
- [x] `DeviceStatus` / wifi DTOs + OkHttp client
- [x] `DeviceEndpointResolver`
- [x] Room entity stub
- [x] NSD / Soft-AP stubs + `RadioDiscovery` seam
- [x] Cleartext network security config
- [x] Unit tests: status decode, endpoint resolver
- [x] `android/README.md`

## Phase 2 — Device list & control

- [ ] Room database + repository
- [ ] Home list, presence dots, jiggle
- [ ] Detail (rename, token, delete)
- [ ] Add by address → Confirm
- [ ] Unit tests

## Phase 3 — LAN NSD scan wizard

- [ ] Real `NsdManager` browser + filter/dedupe
- [ ] Path A wizard
- [ ] Hide already-saved devices
- [ ] VM unit tests

## Phase 4 — Soft-AP provisioning

- [ ] `SoftApJoiner` + Path B
- [ ] Emulator-safe Continue
- [ ] VM unit tests

## Phase 5 — Polish & CI

- [ ] Docs / SECURITY / QA checklist
- [ ] GitHub Actions android job
- [ ] Root README / CONTRIBUTING

## Manual QA

- [ ] Unit tests via Gradle
- [ ] Emulator empty state + install
- [ ] Add by address to live device (host LAN)
- [ ] Jiggle / rename / delete
- [ ] Device: NSD scan + Soft-AP Path B
