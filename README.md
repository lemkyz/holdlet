<p align="center"><img src="docs/brand.svg" width="80" alt="Holdlet icon"></p>
<h1 align="center">Holdlet</h1>
<p align="center">Keep work from slipping away.</p>
<p align="center">A native, open-source Mac companion that keeps meetings and follow-ups at the screen edge.</p>
<p align="center"><a href="https://github.com/lemkyz/holdlet/actions/workflows/ci.yml">Build & tests</a> · <a href="docs/SETUP.md">Connect your tools</a> · <a href="docs/ROADMAP.md">Roadmap</a> · <a href="docs/README.tr.md">Türkçe</a></p>

**Status: 0.2 developer preview.** The menu bar, screen-edge drawer, Mac Calendar and local workflows are usable now. Public Gmail, Slack and Jira sign-in still require publisher registrations and live-account acceptance. Ordinary setup no longer asks users for developer credentials. See [connection readiness](docs/STATUS.md).

<p align="center"><img src="docs/screenshot.png" width="320" alt="Holdlet native Mac panel showing synthetic demo data"></p>

The screenshot is from the running native app with synthetic data. Window-only captures may flatten desktop translucency.

## What it does

- Stays in the menu bar and in a small screen-edge handle, even after closing the drawer.
- Snaps the draggable handle to any edge or connected display; retains its placement.
- Opens with a click, inward scroll or Control + Option + H; hides with Escape, outward scroll or another click.
- Nudges the handle three times for an approaching deadline, with optional sound and a Reduce Motion fallback.
- Offers a setup checklist for Calendar, notifications and automatic start, with direct routes to system permissions.
- Supports weekday and overnight-shift schedules in the Mac's time zone.
- Opens a Control Center-inspired panel with native glass modules. Uses Liquid Glass on macOS 26, visual-effect materials on macOS 14-15.
- Shows the next meeting with a countdown and a safe HTTPS join link.
- Keeps personal follow-up states separate from source-system task states: active, waiting, snoozed, complete.
- Saves local reminders, snoozes and focus sessions across restarts.
- Watches marked Gmail threads for new incoming messages on successful sync; reading a message does not complete its follow-up.
- Includes a 25-minute focus timer, manual screen-sharing privacy mode, connection health, and a sample-data mode.
- Supports English and Turkish UI. Provider error details may be English.

## Connections in this alpha

| Source | Supported scope | Setup |
|---|---|---|
| Mac Calendar | Selected calendars, next 7 days, timed/non-declined events | macOS Calendar permission |
| Direct Google Calendar | Primary calendar, next 7 days, up to 250 timed events | Publisher-configured build; developer setup is separate |
| Gmail | Up to 50 matching threads, plus up to 50 waiting threads | Same Google sign-in; works alongside Mac Calendar |
| Slack | Up to 100 matches for a user-defined search | Internal user OAuth token with `search:read` |
| Jira Cloud | Up to 100 unfinished issues assigned to you | Site, account email, unscoped personal API token |

Sync runs every 3 minutes while the Mac is awake. This is **not push delivery**. Over-limit responses produce a visible error and preserve the previous snapshot. Slack is a personal/internal setup, not a Marketplace-approved public integration. Jira 3LO, multi-account connections, automatic Slack reply detection, all-day events, and phones are not supported yet. See [setup and limitations](docs/SETUP.md).

## Build and run

Runs on macOS 14+. Building requires Swift 6+ and the macOS 26 SDK (Xcode 26+ or matching Command Line Tools) for the availability-gated Liquid Glass API. The current code was locally built with Swift 6.3.3 on Apple Silicon. CI uses a full Xcode toolchain. No third-party Swift dependencies.

```bash
git clone https://github.com/lemkyz/holdlet.git
cd holdlet
./scripts/test.sh
./scripts/build-app.sh
open dist/Holdlet.app
```

For a credential-free, isolated demo:

```bash
open -n dist/Holdlet.app --args --demo --show
```

Demo fixture items never schedule notifications. The isolated `--demo` process does not poll connected services or persist its sample state. Close it before launching the normal app. Do not run `swift run Holdlet` for Calendar/notification testing: use the `.app` bundle so macOS can find usage descriptions and app identity.

The build script signs locally with an **ad-hoc signature** unless `SIGNING_IDENTITY` is provided. An ad-hoc signature is not Developer ID signing or Apple notarization. Build from source for now. A downloadable alpha, if attached to a release, has the same limitation; do not disable Gatekeeper globally. For distribution, see [release instructions](docs/RELEASING.md).

## First run

1. Open **Settings → General → Set up my Mac**. This requests Calendar/notification permission and enables automatic start. macOS may ask for approval.
2. Choose calendars under **Connections**. Google, Outlook, Exchange and iCloud calendars already synced to Calendar.app use the same macOS permission. **Add Google, Outlook or Exchange calendar** opens Internet Accounts directly.
3. Send the five-second notification test and preview the edge nudge.
4. Close Settings. Drag the handle to your preferred edge or display; click to open your day. Use **+** for a local reminder.
5. Set working days/hours, meeting lead time, privacy and sound preferences as needed.

Click the pin to keep the drawer visible when clicking elsewhere. Closing the drawer or Settings keeps Holdlet running; **Quit Holdlet** intentionally exits. Automatic start launches it at the next login, not after an intentional quit. Joining opens a link; it does not prove attendance.

Gmail, Slack and Jira are shown with their actual availability. No developer-console work is required by ordinary users. Contributors testing internal integrations can use **Diagnostics → Developer connections** and [the advanced setup guide](docs/SETUP.md).

## Privacy and reliability

- Credentials are stored in macOS Keychain, not in the repository or local state file.
- Follow-ups, headers/titles, connection status and preferences are saved locally in `~/Library/Application Support/Holdlet/state-v1.json`, with directory mode `0700` and file mode `0600`.
- That file is **not encrypted by Holdlet**. FileVault is a system setting.
- Network requests go to explicitly connected providers. Google OAuth uses the system browser, PKCE/state and a temporary IPv4 loopback listener. No mail bodies are fetched for the current UI.
- No telemetry, ads, hidden AI calls, automatic sending, Jira updates, or notification-center scraping.
- Disconnect removes a provider's local items and local credentials, and reconciles pending reminders. Provider-side token revocation is separate.
- Custom edge cues use their own sound preference and work schedule; macOS Focus controls system notifications. Local focus sessions silence incoming-message cues, while deadlines still surface.
- Focus, notification permission, sleep and system policies affect delivery. The app cannot promise an alert while the Mac is powered off. It reconciles on wake and surfaces overdue local work.

See [product contract](docs/PRODUCT.md), [architecture](docs/ARCHITECTURE.md), [validation](docs/VALIDATION.md), and [security policy](SECURITY.md).

## Contribute

Useful first contributions: provider fixtures, keyboard accessibility, time-zone edge cases, translations, and clean-machine install testing. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before starting a new connector. Do not attach real emails, messages, tokens, or customer data to issues.

Created by [Melike Polat](https://github.com/lemkyz). Licensed under [Apache-2.0](LICENSE).
