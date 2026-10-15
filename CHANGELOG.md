# Changelog

## 0.1.2-alpha - 2026-10-15

Replace the unexplained disabled Google sign-in button with an explicit setup action and Desktop client JSON import. Keep Gmail connected when using Mac Calendar; make direct Google Calendar a separate choice. Decode OAuth/API errors into actionable messages without exposing raw remote descriptions. Handle fragmented loopback requests and canceled authorization attempts. Add configuration, migration and HTTP-client tests. Remove long dash characters from repository prose and clarify which connections still require live-account acceptance.

## 0.1.1-alpha - 2026-10-15

Fix normal-mode startup when Foundation rejects the application identifier as a named UserDefaults suite. Use the standard application domain, keep the demo suite isolated, and add an actual bundled-app startup smoke test to CI. Includes the Turkish account setup guide and demo-to-normal-mode handoff from 0.1.0.

## 0.1.0-alpha - 2026-10-15

Initial native macOS developer alpha: Control Center-inspired glass panel; menu-bar countdown; local reminders and personal follow-up states; focus timer; notifications; launch-at-login; Mac Calendar; bring-your-own-client Google OAuth/Calendar/Gmail; internal Slack search; personal-token Jira Cloud; connection health; privacy mode; English/Turkish UI; synthetic demo; tests and build workflow.

Real external accounts, enterprise deployment and Developer ID/notarized distribution require further acceptance/setup. See the README and roadmap for explicit limits.
