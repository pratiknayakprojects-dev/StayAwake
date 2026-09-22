# StayAwake

A tiny menu bar utility for macOS that keeps your Mac awake — on demand, for a set time, or even with the lid closed.

## Install

1. Go to the [latest release](https://github.com/pratiknayakprojects-dev/StayAwake/releases/latest) and download `StayAwake.dmg`.
2. Open the DMG and drag **StayAwake** into your **Applications** folder.
3. Launch StayAwake from Applications (or Spotlight). It has no dock icon or window — look for a small cup icon in your menu bar, near the clock.

The app is signed with a Developer ID certificate and notarized by Apple, so it opens normally with no security warnings.

## Usage

Click the cup icon in the menu bar:

- **Off** — normal sleep behavior.
- **Keep Awake** — prevents your Mac from sleeping (lid must stay open).
- **Keep Awake When Lid Closed** — also prevents sleep with the lid closed. The first time you use this, macOS will ask you to approve a one-time background helper (Touch ID or password) — after that, switching this on or off never prompts again.
- **Auto-Stop After** — optionally set a timer (10 min, 30 min, 1 hour, 3 hours) so it turns itself off automatically. The menu bar icon fills up like a cup and drains as time runs out.
- **Carry My Workstation** *(new in v1.1)* — one click: keeps your Mac awake with the lid closed for an hour, and automatically reconnects to your iPhone's Personal Hotspot, the same way clicking the Wi-Fi menu would. If it can't connect, it sends you an iMessage alert. First use asks for two one-time approvals — Accessibility access, and where to send the failure alert — after that it's a single click.

## How it works

- "Keep Awake" uses a standard macOS power-management assertion (`IOPMAssertionCreateWithName`) — no special privileges needed.
- "Keep Awake When Lid Closed" needs to flip a protected system setting (`pmset disablesleep`), which macOS only allows for privileged processes. StayAwake installs a small root-running helper daemon (via `SMAppService`) to do this — approved once, then reused silently for every future toggle.
- "Carry My Workstation" drives the real Wi-Fi menu via Accessibility automation to trigger Instant Hotspot — there's no public API for that Bluetooth-triggered join, so it clicks the same control a person would. It verifies the connection by checking for Personal Hotspot's fixed `172.20.10.0/24` address range, since macOS's own network APIs proved unreliable for this check.

## Building from source

Requires Xcode command line tools.

```bash
git clone https://github.com/pratiknayakprojects-dev/StayAwake.git
cd StayAwake
./build_app.sh
```

This produces `StayAwake.app`. To run it unsigned locally, you may need to right-click → Open the first time to bypass Gatekeeper, since only official releases are signed and notarized.

## License

MIT
