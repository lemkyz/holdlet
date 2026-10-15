# Roadmap

The outcome is a dependable daily companion with a simple setup. A checkbox means code exists and its listed acceptance evidence is available; it is not a claim that every corporate account is supported. See [product contract](PRODUCT.md) and [connection readiness](STATUS.md).

## 0.2: a companion you can find without opening a window

- [x] Persistent menu icon and screen-edge handle
- [x] Drag and snap to top, bottom, left or right; retain placement
- [x] Reposition after display changes and use another available screen if needed
- [x] Click/scroll open and close; Escape and pin behavior
- [x] Global Control + Option + H shortcut without keystroke monitoring
- [x] Three short reminder nudges and a Reduce Motion fallback
- [x] Due-date cue ledger; no historical mail storm on initial sync
- [x] Private countdown/overdue handle without mail or meeting titles
- [x] Setup checklist for Calendar, notifications and automatic start
- [x] Direct system-settings routes for rejected permissions and Internet Accounts
- [x] Keep developer credentials out of ordinary connection setup
- [x] Weekday selection, overnight shifts and local time-zone scheduling
- [x] Local reminders, waiting, snooze, completion, focus and privacy
- [x] Core, provider parsing and HTTP failure tests, native packaging and startup CI
- [ ] Physical multi-display, full-screen/Spaces and sleep/wake acceptance matrix
- [ ] VoiceOver, contrast, Reduce Motion and Reduce Transparency real-device matrix

## First public beta: ordinary account sign-in and trusted installation

| Priority | Deliverable | Acceptance |
|---|---|---|
| P0 | [Publisher-owned Google desktop registration and consent configuration](https://github.com/lemkyz/holdlet/issues/1) | Ordinary user signs in from the shipped app without a developer project; Calendar/Gmail each complete a successful sync; cancel, revoke, refresh and account mismatch are tested |
| P0 | [Developer ID signing and notarization](https://github.com/lemkyz/holdlet/issues/2) | Fresh Mac opens the download through the normal OS flow; updates preserve app identity and previously approved Calendar permissions |
| P0 | Stable installation and automatic-start acceptance | Installed app survives logout/login; settings show actual registered status; closing windows leaves it running |
| P0 | [Public Slack application and appropriate user-consent flow](https://github.com/lemkyz/holdlet/issues/3) | Allowed workspace can consent without pasted tokens; admin approval/rejection and missing scopes have useful recovery |
| P0 | [Atlassian OAuth 3LO and site selection](https://github.com/lemkyz/holdlet/issues/3) | User signs in without email/token fields; accessible sites, token refresh and revoked grants are covered |
| P1 | Provider pagination and bounded retention | Busy accounts neither truncate silently nor grow local state without bounds; retention is user-visible and migration is reversible |
| P1 | Account identity and multi-account storage | Items/credentials are namespaced by tenant/account; users can disconnect one account without affecting others |
| P1 | Signed update channel and rollback | Update authenticity verified; data migrations are backed up; failed update leaves last working version |
| P1 | Clear overdue recovery and alert grouping | Return from sleep/offline presents a useful summary without replaying every historical alert |
| P1 | Local performance budget | Measured idle CPU, memory, network and battery figures on representative Macs; no invented benchmarks |

External account gates cannot be replaced with placeholder keys or an apparently working button. No publisher credentials or Apple signing identity are present in the default repository. Publisher registration requires authorized provider-console access; it is a release prerequisite.

## Workplace coverage

| Order | Source | First useful capability | Gate |
|---|---|---|---|
| 1 | Google Workspace | Meetings, important mail, waiting replies | Registered/verified consent and live-account acceptance |
| 2 | Slack and Jira Cloud | Direct mentions, assigned work, deadlines | Public OAuth flows and tenant-policy acceptance |
| 3 | [Microsoft 365](https://github.com/lemkyz/holdlet/issues/4) | Outlook mail/calendar and Teams meetings | Entra app registration, least-privilege scopes and admin-consent matrix |
| 4 | GitHub and Linear | Requested reviews, assignments and blocked work | Scoped account consent, identity and webhooks/polling policy |
| 5 | Notion and Confluence | Mentions, document comments and action follow-ups | Workspace/page permissions and useful signal filtering |
| 6 | Cross-source brief | Meeting preparation, linked follow-ups and saved searches | Deduplication, provenance, no silent sending or task updates |
| 7 | Optional surfaces | Phone handoff, optional companion, desktop widgets | Same scheduling engine; main workflow remains useful without them |

Teams chat, all-day scheduling, multiple accounts, hosted push, universal binaries and the optional companion are not implemented in the current preview. Outlook/Exchange calendars already present in Calendar.app can be used through EventKit; this is distinct from a Microsoft API integration.

## Corporate administration

- Managed preferences/MDM with integration allowlists and tenant restrictions.
- Documented retention, local-data deletion, export and account revocation.
- Deployment packages and an administrator guide for required provider scopes.
- Approved proxy/network environments and clear stale/offline indicators.
- Team distribution and permissions without sharing personal tokens.
- Localization, keyboard-only navigation, VoiceOver and assistive-display support.
- Security review and incident-response process before compliance claims.

## Discovery and open-source quality

- Demonstrate a real signed app and a short synthetic-data interaction recording.
- Keep README, actual connection status and release notes aligned.
- Publish small reproducible issues and provider fixtures without customer data.
- Provide contribution guides, a security policy and release acceptance evidence.
- Validate with individual contributors, managers, remote teams and IT administrators before expanding scope.

Stars are an outcome of usefulness, trust and distribution, not a release acceptance test. No popularity, universal tenant compatibility, compliance certification or zero-missed-alert guarantee is promised.
