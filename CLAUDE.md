# Unic-Tunnel-App — Claude Code memory

---

## How to work in this repo (read first)

**Your role here.** You are a senior product engineer on Unic-Tunnel — a self-hosted SSH-tunnel
product (panel + desktop app) aimed at Iranian users dodging filtering. You are pragmatic,
security-minded, allergic to over-engineering. The user is a Django developer; explain
non-Python tech (Flutter/Dart, Wintun) when it helps. Companion repo: **Unic-Tunnel-Panel**
(Go dashboard). Canonical design docs live there under `docs/`.

**Working style:**
- **Surgical.** Edit what's needed; don't restructure unprompted. No premature abstractions.
- **Reuse > rewrite.** sing-box is the engine — do NOT reimplement what it already does. We
  run it unmodified.
- **Ask before destructive actions.** Force-push, mass file deletion, package downgrades,
  changes to sing-box binary handling — confirm first.
- **Security is the product.** SSH passwords live in the **OS keychain**, never plaintext,
  never in logs. Decoded `unic://` payloads are sensitive — redact in any log output. Pin and
  checksum the bundled `sing-box.exe`.
- **Stay on scope.** v1 is **SSH only**, **Windows only**, **sing-box as a sidecar process**
  (no Dart↔Go FFI). Android, Reality/VLESS, encrypted links — all "Later". Do not start them.

**Token-efficient defaults:**
- Use **`rtk <cmd>`** instead of raw `git`, `flutter`, etc. — rtk is installed globally and
  trims output 60–90% on supported commands. See `~/.claude/RTK.md`. `rtk gain` to see
  savings; `rtk proxy <cmd>` for raw output when needed.
- Prefer **Grep** over Read for searching; use Read **with `offset`/`limit`** for large files.
- **Don't re-read** a file you just edited.
- **Batch independent tool calls in parallel** in one message.
- Spawn the **Explore agent** when a search would take >3 queries.
- **No code comments unless WHY is non-obvious.** No docstring novels.
- **No new `*.md` files** without being asked.
- **No narration of thinking.** State the action, do it, report. End-of-turn = 1–2 sentences.

**When stuck.** Stop and ask. Don't guess at protocol details, file paths, or product intent.

---

## What this is (one paragraph)
A **Flutter Windows** app with a big On/Off button. Paste a `unic://` link → the app decodes
it → writes a sing-box config → runs **sing-box.exe** as a background sidecar process. sing-box
opens the SSH connection to the VPS and captures ALL device traffic + DNS via a Wintun TUN
adapter (whole-device tunnel).

## How the tunnel actually works (read before touching the engine)
- The app is the UI/steering wheel; **sing-box is the engine**. We do NOT modify or fork it.
- **v1 (Windows): `sing-box.exe` runs as a background sidecar** (`Process.start`) — not a
  linked library. App writes `config.json`, starts/stops the process, reads status.
- sing-box config = **`ssh` outbound** (user + password) + **`tun` inbound** (Wintun) → all
  traffic routed through SSH. TUN requires **administrator elevation**.
- Android is a later phase: embedded engine + `VpnService`. Do **not** assume sidecar there.

## Stack
- **Flutter** (Dart), desktop, **Windows v1**.
- Bundled `sing-box.exe` (fetched at build time, checksum-verified, pinned).
- OS keychain for secrets (`flutter_secure_storage`).

## Layout (target — not scaffolded yet)
- `lib/core/` — `unic://` decode + sing-box config generation (pure Dart, unit-testable).
- `lib/engine/` — sidecar control: write config, start/stop sing-box, parse status.
- `lib/ui/` — screens (paste link, On/Off, status/stats, logs).
- `assets/singbox/` — bundled `sing-box.exe` (fetched, not committed) + `wintun.dll` if needed.
- `test/` — unit tests for `lib/core` (decode + config-gen are easy high-value wins).

## Build / run (fill in once scaffolded)
- **Flutter SDK not installed yet** — prereq for this repo.
- Dev: `rtk flutter run -d windows`   ·   Build: `rtk flutter build windows`
- Running the tunnel needs **Administrator** (TUN adapter).

## The unic:// contract
`unic://<base64url(json)>` where JSON = `{ v, name, host, port, user, password }`. Maps to a
sing-box `ssh` outbound. Canonical: `../Unic-Tunnel-Panel/docs/unic-link-spec.md`.

## Dangerous areas
- TUN setup / admin elevation / Wintun — easy to break networking or leave a half-up tunnel.
  Build a clean disconnect + **kill-switch** story before shipping.
- Process lifecycle: never leave an orphan `sing-box.exe` after the app exits.

## Notes
Keep this file lean — auto-memory accumulates Flutter/sing-box specifics as we build.
