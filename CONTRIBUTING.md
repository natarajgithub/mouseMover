# Contributing

Thanks for helping improve **mouseMover** / `usb-hid-s3`.

## Development setup

```bash
cd usb-hid-s3
cp config.env.example config.env
# Optional STA seed (never commit):
cp include/wifi_secrets.h.example include/wifi_secrets.h
```

Requires [PlatformIO Core](https://docs.platformio.org/en/latest/core/installation.html)
and Python 3.11+ for host tools.

## Checks to run before a PR

```bash
cd usb-hid-s3
pio test -e native          # required — also runs in CI
pio run -e esp32s3          # required — also runs in CI
```

Optional on-device (macOS + Waveshare ESP32-S3-Zero/Mini):

```bash
./scripts/e2e.sh            # needs board + Input Monitoring / Accessibility
```

Do **not** expect on-device pytest to pass in GitHub Actions.

## What not to commit

- `include/wifi_secrets.h`, `config.env`, `.env`, keys, PEM/P12 files
- Local lab notes: `docs/PHASE_LOG.md`, `docs/ISSUES.md` (gitignored)
- `.pio/` build trees

## Pull requests

1. One focused change per PR when possible.
2. Keep PRs mergeable against `main`; CI must stay green.
3. Update `CHANGELOG.md` / docs when behavior or flash steps change.
4. Never commit secrets.

## Code style

- Match existing C++ / Python style in the touched files.
- Keep pure logic in `lib/` so `pio test -e native` can cover it.
- Prefer small, reviewable diffs over drive-by refactors.
