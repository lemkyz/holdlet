# Validation

## Local evidence

- Native macOS executable compiled with Swift 6.3.3 on Apple Silicon.
- `.app` bundle created with Info.plist usage descriptions, icon and an ad-hoc signature.
- Demo app launched on macOS; accessibility tree and panel rendering inspected.
- Demo UI acceptance: focus start/stop changed the live countdown; Settings opened; connection setup was disabled in isolated demo; privacy mode replaced titles/senders; adding a local reminder increased the open-item count.
- 25 core tests passed locally on the initial implementation.
- 0.1.2: 38 tests passed, including Desktop OAuth file validation, old-preference migration, independent Gmail/calendar selection and the actual HTTP client's OAuth/API failure handling through a URLProtocol fixture. These tests do not establish successful sign-in to a live Google account.
- Normal bundled-app startup passes `./scripts/smoke-app.sh` (on a clean test account); this check caught and prevented a normal-domain UserDefaults startup regression. CI runs it after packaging.
- Core tests cover merge, cancellation, rescheduling, deduplication, reading-vs-completion, incoming Gmail activity, work hours/time zones/DST, snooze/lead times, notification privacy/capacity, persistence permissions/corruption, link host boundaries and synthetic provider decoding.

Run `./scripts/test.sh` for the exact current test count/results. CI runs the same suite, builds the app and uploads an artifact. Live acceptance is recorded below; sample-provider decoding alone is not evidence of a live integration succeeding.

## 0.2 evidence

- 50 tests pass locally in five suites. New coverage includes negative-coordinate displays, small screens, edge snapping, old-state migration, day selection, overnight shifts, stale-deadline suppression, late meeting sync, first-provider baselines, first arrival after an empty sync and new incoming-thread fingerprints.
- Native demo checks verified the handle opens the drawer, the screen-edge chooser moves it to the right, closing Settings leaves the handle available, the live label updates, and the five primary Settings tabs remain accessible.
- The handle preview action was invoked. Physical sound, exact animation timing, cross-display dragging and global physical-key delivery are still manual acceptance items.
- Normal-profile acceptance verified Calendar successful sync, enabled notifications and enabled automatic start together in the readiness checklist. Calendar access needed renewal after the ad-hoc rebuild; no clean-machine or stable-signed-update claim is made.
- macOS system-settings links are recovery routes; their availability and destination can differ by OS release. Clean-machine permission acceptance remains required.

## Manual acceptance before relying on it

| Flow | Required check |
|---|---|
| Edge surface | Drag to four edges and another screen; unplug display; relaunch; Reduce Motion; no focus theft |
| Shortcut | Control + Option + H from another foreground app; registration conflict; disable/re-enable |
| First install | Open `.app`, onboarding visible, no provider requests before connecting |
| Local reminder | Add, snooze, restart, see expected time, receive one alert |
| Completion | Complete pending item; its future notification disappears |
| Focus | Start, restart, finish; stop cancels the scheduled timer alert |
| Notifications | Allow/deny/revoke, Focus on/off, full-screen, mirrored/external display |
| Calendar | Grant/deny, choose calendars, recurring events, reschedule, cancel |
| Google | Consent, refresh token, sign-in cancellation, account disconnect |
| Gmail | Read mail without completing; waiting thread resurfaces on incoming message |
| Slack | Allowed user token, missing scope, invalid token, query cap |
| Jira | Valid site/token, invalid host, revoked token, completed issue, date-only deadline |
| Recovery | Offline, 401/403/429, wake from sleep; preserve last snapshot and show error |
| Privacy | Hide titles and senders in panel and scheduled notification content |
| Disconnect | Local items/keys removed, in-flight results do not return, alerts reconciled |
| Accessibility | Keyboard, VoiceOver, Reduce Transparency, Increased Contrast, Reduce Motion |

Apple Silicon is the locally tested architecture. Intel and older supported macOS versions need real-device validation. Performance targets (idle CPU, memory and battery) need Instruments measurements; the project does not claim measured numbers yet.

## 0.2.1 OAuth listener regression

A real Desktop client exposed an application-side startup failure before the browser opened: Network.NWError POSIX EINVAL (22). NWListener was started without a new-connection handler; the handler was assigned only after waiting for readiness. Installing the handler before start fixes the failure while retaining the IPv4 loopback-only bind.

52 tests pass locally. New tests exercise the actual production authorization method with an injected browser opener: the real listener reaches readiness, constructs a loopback redirect/PKCE/state URL, can retry after browser-open failure, and cancels after readiness without a token exchange or Keychain writes. These are native socket tests, not HTTP fixture responses. They do not establish Google consent or Gmail API acceptance.

Errors and in-progress Google sign-in are now visible inside the developer-connection sheet rather than being hidden behind it. The local configured package exposes Continue with Google in the normal Connections screen. The generic source/CI build still needs publisher configuration during packaging.

### Sign-in setup timeout recovery

Manual Google consent reached the loopback redirect after the original three-minute wait had expired, leaving Safari unable to connect to the closed listener. The sign-in window now allows fifteen minutes, and a timed-out attempt explains how to start a fresh flow instead of suggesting an unrelated scope change. Old callback tabs cannot resume an expired attempt; retrying creates a new state and PKCE verifier.

53 tests pass locally, including a real-listener expiration followed by a fresh attempt. These checks do not establish live Gmail synchronization.

### Live acceptance on 16 October 2026

Using the locally configured Desktop OAuth client and a developer-approved Google test account, the user completed consent and the browser reached Holdlet's loopback callback. The application saved the authenticated connection and completed its first real Gmail API synchronization. Both persisted connection health and the Connections screen reported Gmail connected with a successful synchronization at 11:48 Europe/Istanbul. No account identifiers, message content, authorization codes or credentials are included in this evidence.

The existing Mac Calendar connection also completed synchronization after renewing access following the ad-hoc app update. Direct Google Calendar was left disabled to preserve the user's existing calendar selection. Google refresh-token renewal across expiry, public verified Google sign-in, Slack and Jira live acceptance remain unverified. The generic release still does not contain publisher Google configuration.
