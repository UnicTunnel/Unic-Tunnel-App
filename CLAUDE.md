# Unic-Tunnel-App — Claude Code memory

> Desktop **client** for Unic-Tunnel. Decodes a `unic://` link and turns the user's whole device
> into a tunnel through their VPS by driving **sing-box**. Companion repo: **Unic-Tunnel-Panel**
> (Go dashboard). Canonical design docs live in the Panel repo's `docs/`.

## What this is (one paragraph)
A Flutter app with a big On/Off button. Paste a `unic://` link → the app decodes it → writes a
sing-box config → runs **sing-box**, which opens the SSH connection to the VPS and captures ALL
device traffic + DNS through it (whole-device tunnel). **Windows first.**

## How the tunnel actually works (read this before touching the engine)
- The app is the **UI/steering wheel**; **sing-box is the engine**. We do NOT modify or fork it.
- **v1 (Windows): run `sing-box.exe` as a background "sidecar" process** (`Process.start`) — not
  as a linked library. The app writes `config.json`, starts/stops the process, reads status.
  This avoids any Dart↔Go FFI in v1 (much simpler, lower-risk).
- sing-box config = **`ssh` outbound** (user + password) + **`tun` inbound** (Wintun on Windows)
  → all traffic routed through SSH. TUN requires **administrator elevation**.
- **Android is a later phase and is different**: it needs the embedded engine + `VpnService`.
  Do not assume the sidecar model for Android.

## Stack
- **Flutter** (Dart), desktop, **Windows target** for v1.
- Bundled asset: a pinned `sing-box.exe` (fetched at build time, checksum-verified).
- OS keychain for secrets (e.g. `flutter_secure_storage`).

## Layout (target — not scaffolded yet)
- `lib/core/` — `unic://` decode + sing-box config generation (pure Dart, unit-testable).
- `lib/engine/` — sidecar control: write config, start/stop `sing-box.exe`, parse status.
- `lib/ui/` — screens (paste link, On/Off, status/stats, logs).
- `assets/singbox/` — bundled `sing-box.exe` (fetched, not committed) + `wintun.dll` if needed.
- `test/` — unit tests for `lib/core` (decode + config-gen are the easy, high-value wins).

## Build / run (fill in once scaffolded)
- **Flutter SDK is not installed yet** — prereq for this repo (install before Phase 3).
- Dev: `flutter run -d windows`   ·   Build: `flutter build windows`
- Running the tunnel needs **Administrator** (TUN adapter).

## Security rules (hard constraints)
- Store the SSH password in the **OS keychain**, never plaintext on disk, never in logs.
- **Never print the decoded secret** — redact in any log output.
- Treat the `unic://` payload as sensitive; don't leave it in UI state longer than needed.
- **Pin + checksum the bundled `sing-box.exe`** so the engine can't be silently swapped.

## The unic:// contract
`unic://<base64url(json)>` where JSON = `{ v, name, host, port, user, password }`. The app decodes
it and maps it to a sing-box `ssh` outbound. Canonical spec lives in the Panel repo:
`../Unic-Tunnel-Panel/docs/unic-link-spec.md`. App and panel MUST agree on the `v` version.

## Dangerous areas (take care)
- TUN setup / admin elevation / Wintun — easy to break networking or leave a half-up tunnel.
  Build a clean disconnect + **kill-switch** story before shipping.
- Process lifecycle: never leave an orphan `sing-box.exe` after the app exits.

## Out of scope for v1 (see the plan's "Later options")
Reality/VLESS outbound, encrypted links, `vless://` import, Android. Keep v1 = **SSH + Windows**.

## Notes
Repo is currently empty (foundation pass). Keep this file lean — auto-memory will accumulate
Flutter/sing-box specifics as we build.
