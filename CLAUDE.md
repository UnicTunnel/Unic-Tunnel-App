# Unic-Tunnel-App — repo memory

> The workspace `CLAUDE.md` two levels up (via the parent of this repo) loads
> automatically and holds the **shared rules** (role, security, scope, token
> efficiency). This file is repo-specific.

## Stack

Flutter (Dart) · **Windows v1**, Android later · runs **`sing-box.exe` as a
background sidecar process** (no Dart↔Go FFI in v1) · OS keychain for secrets via
`flutter_secure_storage`.

## Planned layout (NOT scaffolded yet — confirm scope before generating)

- `lib/core/` — `unic://` decode + sing-box config generation (pure Dart,
  unit-testable, no Flutter deps)
- `lib/engine/` — sidecar control: write `config.json`, start/stop `sing-box.exe`,
  parse status output
- `lib/ui/` — screens (paste link, On/Off, status, logs)
- `assets/singbox/` — bundled `sing-box.exe` + `wintun.dll` (fetched at build time,
  checksum-pinned, NOT committed)
- `test/` — unit tests; start with `lib/core/`

Full diagram: `../docs/structure.md`.

## Build / run

- **Flutter SDK is not installed yet.** Prereq before this repo can compile.
- Dev: `rtk flutter run -d windows`
- Build: `rtk flutter build windows`
- Running the tunnel requires **Administrator** elevation (Wintun TUN adapter).

## How the engine actually works (read before touching `lib/engine/`)

The app is the UI; **sing-box is the engine**. On press-On:
1. Decode the saved `unic://` link.
2. Generate a sing-box `config.json`:
   - **`ssh` outbound** with user + password from the link
   - **`tun` inbound** (Wintun on Windows, `auto_route: true`)
3. Spawn `sing-box.exe run -c config.json` as a child process.
4. ALL device traffic + DNS now routes through the SSH connection.

We do **not** fork or modify sing-box. Pin and checksum the bundled binary.

## Gotchas specific to this repo

- **Process lifecycle:** never leave an orphan `sing-box.exe` after the app exits.
  Build a kill-switch + explicit cleanup on disconnect before any release.
- **Decoded `unic://` payload is sensitive** — redact in log output; store the
  password in the OS keychain, never plaintext.
- **Admin elevation** is required for TUN. The app should detect non-elevated
  startup and re-launch elevated (or refuse with a clear message), not silently fail.
- **Android (later phase) is fundamentally different**: embedded engine + Android
  `VpnService`. Do not assume the sidecar model applies there.

## Scope reminder

v1 = Windows + SSH only. No Android, no Reality, no encrypted link format.
See workspace `CLAUDE.md`.
