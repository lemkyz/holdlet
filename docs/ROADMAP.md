# Roadmap

The priority is dependable daily use, with explicit provider limitations. An adapter being implemented is not the same as a production-approved integration.

## 0.1 developer alpha

- [x] Native menu-bar app and glass panel
- [x] Local follow-ups, completion, snooze and focus persistence
- [x] System notifications and login-item control
- [x] EventKit Calendar adapter
- [x] Google Desktop OAuth/PKCE and read-only Calendar/Gmail adapters
- [x] Internal Slack search adapter
- [x] Personal-token Jira Cloud adapter
- [x] Connection health and manual privacy mode
- [x] Credential-free sample data
- [x] Core tests and CI
- [ ] Live-account acceptance of Google, Slack and Jira
- [ ] Clean-machine notification/login-item/Calendar permission matrix
- [ ] Developer ID signing and Apple notarization

## Reliability and first public beta

- Real-world acceptance across Focus, full-screen apps, Spaces, external displays, sleep/wake and offline recovery
- Notification grouping, clear overdue recovery and optional configurable escalation
- Weekday/overnight work schedules; timezone changes while running
- Google pagination/multi-calendar support and browser account routing
- Slack OAuth distribution/approval strategy and event-based updates where allowed
- Jira OAuth 3LO; pagination and explicit due-date time policy
- Multi-account identity, bounded retention and a storage migration strategy
- Keyboard shortcut and compact pinned view
- Native UI tests and network failure simulation
- Signed updater, clean-machine installer, then Homebrew distribution

## Broader workplace coverage

1. Outlook + Microsoft Calendar
2. Teams (after tenant-permission validation)
3. GitHub/Linear review requests
4. Notion/Confluence document comments
5. Shared links and a meeting-preparation card
6. Optional Pip companion; identical capabilities with it hidden
7. Optional on-device/explicitly selected AI suggestions, with evidence and confirmation
8. Phone handoff and optional hosted notification relay

Corporate administration (managed preferences/MDM, retention controls, enterprise auth) is a separate track. No compliance certification, “never miss anything” guarantee or zero-battery-cost claim is made.
