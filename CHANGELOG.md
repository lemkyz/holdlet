# Changelog

## 0.2.3-alpha - 2026-10-16

Move Keychain operations off the UI thread. Bound credential-read waiting to eight seconds without queuing repeated requests behind a stalled system authorization dialog. Pause Google background checks after a Keychain access failure until the user explicitly retries. Use an atomic compare-and-replace for refreshed Google tokens, preserving concurrent disconnect behavior. These changes do not unlock, reset or weaken the macOS Keychain.

## 0.2.2-alpha - 2026-10-16

Keep drawer gaps on one continuous native glass input surface and route padding scroll gestures to the drawer list. Default Gmail to Inbox; add All mail/Unread/Important filters, received dates, unread emphasis and older-page loading. Probe Gmail history every 15 seconds while awake and avoid downloading unchanged mail. Add focused, privacy-aware incoming notifications without alerting on imported old mail. Add an ordinary Jira setup wizard, scoped token gateway support, assigned/reported/watched scope choices and paginated issue search. Extend Google sign-in to fifteen minutes with actionable timeout recovery. This remains a developer alpha; true Gmail push, public provider OAuth and notarization are separate gates.

## 0.1.2-alpha - 2026-10-15

Replace the unexplained disabled Google sign-in button with an explicit setup action and Desktop client JSON import. Keep Gmail connected when using Mac Calendar; make direct Google Calendar a separate choice. Decode OAuth/API errors into actionable messages without exposing raw remote descriptions. Handle fragmented loopback requests and canceled authorization attempts. Add configuration, migration and HTTP-client tests. Remove long dash characters from repository prose and clarify which connections still require live-account acceptance.

## 0.1.1-alpha - 2026-10-15

Fix normal-mode startup when Foundation rejects the application identifier as a named UserDefaults suite. Use the standard application domain, keep the demo suite isolated, and add an actual bundled-app startup smoke test to CI. Includes the Turkish account setup guide and demo-to-normal-mode handoff from 0.1.0.

## 0.1.0-alpha - 2026-10-15

Initial native macOS developer alpha: Control Center-inspired glass panel; menu-bar countdown; local reminders and personal follow-up states; focus timer; notifications; launch-at-login; Mac Calendar; bring-your-own-client Google OAuth/Calendar/Gmail; internal Slack search; personal-token Jira Cloud; connection health; privacy mode; English/Turkish UI; synthetic demo; tests and build workflow.

Real external accounts, enterprise deployment and Developer ID/notarized distribution require further acceptance/setup. See the README and roadmap for explicit limits.
