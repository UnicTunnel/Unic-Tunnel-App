# Unic-Tunnel-App

**Flutter desktop client** (Windows first) for Unic-Tunnel. Paste a `unic://` link, press **On**,
and your whole device tunnels through your VPS. Uses **sing-box** as the engine (run as a
background sidecar process).

**Status:** foundation (design + docs). No code yet. Flutter SDK not installed yet (prereq).

## Docs
- Agent memory / conventions: [`CLAUDE.md`](CLAUDE.md)
- Architecture, data flow, and the `unic://` link format live in the Panel repo's `docs/`:
  [architecture](https://github.com/Unic-Tunnel/Unic-Tunnel-Panel/blob/main/docs/architecture.md)
  · [unic:// spec](https://github.com/Unic-Tunnel/Unic-Tunnel-Panel/blob/main/docs/unic-link-spec.md)

## Stack (planned)
Flutter (Dart) · bundled `sing-box.exe` sidecar · OS keychain for secrets. **Windows first**;
Android (embedded engine + `VpnService`) is a later phase.

## Companion
Panel: **[Unic-Tunnel-Panel](https://github.com/Unic-Tunnel/Unic-Tunnel-Panel)**
