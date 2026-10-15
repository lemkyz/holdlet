# What is ready

| Area | Evidence | Remaining work |
|---|---|---|
| Mac Calendar | User confirmed it connects | Broader device/recurrence/permission acceptance |
| Local reminders, focus, privacy | Native UI checks and core tests | Longer everyday use and notification matrix |
| Google configuration | Desktop JSON import and configuration/error tests | Publisher-owned OAuth app for ordinary sign-in |
| Gmail and direct Google Calendar | Adapter/parser/HTTP tests with synthetic data | Successful consent and sync with a real Google account |
| Slack | Search adapter and synthetic decoding | Allowed workspace user token and live search acceptance |
| Jira Cloud | Adapter and synthetic decoding | Real site/token and live issue acceptance |
| Distribution | Local ad-hoc build, app startup and CI | Developer ID signing and notarization |

Google, Slack and Jira are experimental developer connections. A test fixture, a visible button or a successful build does not establish a working account connection.

Google sign-in needs a registered Desktop OAuth application. For personal testing, import Google's client JSON in Settings. A publisher can configure a shared build using `HOLDLET_GOOGLE_CLIENT_ID` and, where required, `HOLDLET_GOOGLE_CLIENT_SECRET` during packaging. Installed desktop clients are public clients; do not put user tokens in those build settings. Public distribution still needs the provider's applicable consent/verification process.

Selecting Mac Calendar now preserves Gmail. Direct Google Calendar is a separate toggle so the same events are not shown from both providers. Successful sign-in enables a sync attempt; each service is marked connected only after its API request succeeds.
