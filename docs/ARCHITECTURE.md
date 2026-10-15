# Architecture

```
EventKit / Google / Slack / Jira
               ↓
Read-only adapters + provider parsers
               ↓
AttentionItem → merge personal follow-up state
               ↓
Atomic local snapshot + Keychain credentials
               ↓
ReminderPlanner → notification reconciliation
               ↓
Menu bar / edge handle / native glass drawer / Settings
```

## Targets

- `HoldletCore`: Codable models, pure prioritization/merge/reminder planning, link validation, provider parsing, atomic snapshot persistence.
- `HoldletApp`: AppKit lifecycle, SwiftUI panel/settings, EventKit adapter, external API adapters, PKCE loopback sign-in, Keychain, notifications, launch-at-login.
- `HoldletCoreTests`: synthetic provider fixtures and behavior tests using Swift Testing.

The app has no third-party package dependencies and no server. The initial storage format is a versioned JSON snapshot, not SQLite: it keeps the first release inspectable and simple. A database/migration layer becomes appropriate for multi-account histories and larger retention volumes. Corrupt or unsupported state opens read-only; the original file is never silently overwritten. Reset explicitly backs it up first.

## State and concurrency

`AppState` is main-actor isolated. URLSession requests suspend without blocking the UI. A single periodic sync runs at a time; a configuration generation prevents old in-flight responses from repopulating a disconnected source. Providers fail independently and preserve their last snapshot. HTTP 429 honors `Retry-After`; the next ordinary poll is three minutes later. The notification reconciler serializes the latest desired snapshots to avoid missing a change during an in-flight scheduling pass.

Provider IDs include source and identity. Calendar occurrences include an absolute start timestamp for EventKit. Source snapshots remove absent calendar events, while Gmail/Slack personal follow-ups survive query removal. A completed item remains a personal state, not a write to the provider. Metadata is refreshed when present in a provider response.

## Notifications

The pure planner considers lead time, snooze, completion, work hours and redaction. At most 48 item notifications are planned, leaving room under macOS limits for focus and tests. Demo fixture items cannot schedule alerts. Identifiers are stable per item/deadline. Reconciliation removes obsolete requests. A local ledger prevents the same already-fired deadline from being scheduled on every poll. Past task deadlines remain in the panel instead of generating a burst of historical notifications.

The OS controls notification presentation and sleep behavior. No Critical Alert entitlement or Focus bypass is requested. A focus session survives restart via its absolute end date. An expired session is surfaced on return without replaying stale timers.

## Security boundaries

- Provider credentials use Keychain's `WhenUnlockedThisDeviceOnly` access class.
- App state is local with mode 0600, in a 0700 directory. No application-level database encryption is claimed.
- External links accept HTTPS only; meeting links require known service host boundaries, rejecting lookalike domains.
- Jira credentials are restricted to a validated `*.atlassian.net` HTTPS site without embedded user info or custom port/path.
- OAuth binds IPv4 loopback only; state and verifier use cryptographic randomness. Browser callback content is plain text and never echoes credentials.
- Diagnostics exclude titles, senders, service error bodies, tokens and local account identifiers.
- No provider content is sent to an LLM, analytics service or Holdlet backend.

## Design

The approved reference is macOS Control Center: distinct rounded translucent modules, circular symbols, capsule actions and system text. Neutral materials inherit desktop tones. macOS 26 uses SwiftUI Liquid Glass; older supported systems use `NSVisualEffectView`. Typography remains opaque and supports native accessibility. The pet is deliberately a later optional surface; it does not own scheduling logic.

## Presence and cues

`EdgeDockController` owns a separate non-key NSPanel for the handle. It does not require Accessibility or Screen Recording permission. The drawer remains a separate key-capable panel; custom cues animate the handle without opening it or stealing focus. Placement uses normalized position and display ID, clamped within the display's visible frame. A disconnected display falls back to an available screen.

`EdgeLayout`, `WorkSchedule`, `AttentionCuePlanner` and `IncomingCueTracker` are pure core policies. Deadline cue IDs incorporate the deadline, so a rescheduled meeting is eligible again. A local UserDefaults ledger prevents repeat delivery across normal relaunches. Incoming providers establish a first-success baseline; later incoming fingerprints can cue. Custom cues and macOS notifications are separate delivery channels. Incoming-message cues are quiet during a local focus session; deadlines remain eligible.

The global shortcut uses OS hot-key registration, not global keystroke monitoring. Registration failure is visible in Settings. Public user connection setup and internal developer credential setup are separated.
