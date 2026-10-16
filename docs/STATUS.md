# What is ready

| Area | Evidence | Remaining work |
|---|---|---|
| Screen edge and setup | Native demo checks: open/close, right-edge selection, Settings remain navigable; pure layout/cue tests | Physical drag, external-display, Spaces and accessibility matrix |
| Global shortcut | OS registration and accessible availability state | Physical-key acceptance across other foreground apps |
| Mac Calendar | Live successful synchronization on 16 October 2026, including access renewal after an ad-hoc update | Broader device/recurrence/permission acceptance |
| Local reminders, focus, privacy | Native UI checks and core tests | Longer everyday use and notification matrix |
| Google configuration | Desktop JSON import and configuration/error tests | Publisher-owned OAuth app for ordinary sign-in |
| Gmail | Live Google consent and Gmail API synchronization on 16 October 2026 with the locally configured Desktop client and an approved test account | Public publisher verification, shipped configuration, refresh/revoke/account-switch acceptance |
| Direct Google Calendar | Adapter/parser/HTTP tests with synthetic data; optional integration remains disabled in the live profile | Successful live API sync and independent calendar-selection acceptance |
| Slack | Search adapter and synthetic decoding | Allowed workspace user token and live search acceptance |
| Jira Cloud | Normal setup wizard, scoped-token gateway, assigned/reported/watched scopes, pagination and transport tests | Real token consent and live issue acceptance; publisher browser OAuth |
| Distribution | Local ad-hoc build, app startup and CI | Developer ID signing and notarization |

Google, Slack and Jira remain experimental developer connections. Gmail live acceptance applies to the configured local app, not the generic downloadable release. A test fixture, a visible button or a successful build does not establish a working account connection. See [launch review in Turkish](LAUNCH-READINESS.tr.md) for release gates.

Google sign-in needs a registered Desktop OAuth application. For internal developer testing, import Google's client JSON under Diagnostics → Developer connections. Ordinary users should not create developer projects. A publisher can configure a shared build using `HOLDLET_GOOGLE_CLIENT_ID` and, where required, `HOLDLET_GOOGLE_CLIENT_SECRET` during packaging. Installed desktop clients are public clients; do not put user tokens in those build settings. Public distribution still needs the provider's applicable consent/verification process.

Selecting Mac Calendar now preserves Gmail. Direct Google Calendar is a separate toggle so the same events are not shown from both providers. Successful sign-in enables a sync attempt; each service is marked connected only after its API request succeeds.
