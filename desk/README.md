# Daybook desk display

A Raspberry Pi renders Daybook's desk view (`index.html?desk`) every 5 minutes into an 800×480 black-and-white image for an e-ink panel.

- `install.sh`: one-time setup on the Pi (Chromium, Sydney time zone, systemd timer, preview page on port 8080).
- `render.sh`: opens the desk view in headless Chromium and screenshots it. Quiet hours 11pm–6am.
- `convert.py`: converts to 1-bit, ignores pages that aren't ready, only replaces `frame.png` when it changed, and calls `display.py` if present (the future e-paper driver).
- `viewer.html`: preview page served by the Pi at `http://<hostname>.local:8080`.

The Pi uses its own **read-only** GitHub key for `daybook-data`, kept in `~/.config/daybook-desk/config` (mode 600). It is passed to the page after `#`, so it never leaves the Pi except to the GitHub API.

Preview the layout in any browser: `https://ollyj77.github.io/daybook/?desk` (uses the key already saved on that device). Add `&at=2026-10-06T09:15` to see another time.
