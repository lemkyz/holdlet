# Product contract

Holdlet keeps important work within reach without requiring a second inbox to be checked. It is a native Mac companion for people who move between meetings, mail and workplace tools. It is useful with only Calendar and local reminders; provider connections extend it.

## The everyday experience

1. Open the app. See a single setup screen with Calendar, notifications and automatic-start status.
2. Choose **Set up my Mac**. macOS requests the relevant permissions. Previously denied permissions lead directly to the matching settings page.
3. Close Settings. The menu icon and small screen-edge handle remain.
4. Drag the handle to any of four edges or another connected display. Placement is retained across normal restarts. A missing display falls back to an available screen.
5. Click the handle, scroll inward, or press Control + Option + H to open the drawer. Click again, scroll outward, press Escape or click outside to hide it. Pinning keeps the drawer open on outside clicks.
6. An approaching deadline nudges the handle three times. Reduce Motion uses a static highlight. The handle shows the next meeting countdown or overdue count without exposing a title.
7. Open a meeting, snooze a follow-up, mark work waiting or complete it. These are personal choices; Holdlet does not modify source-system tasks.

The edge entry point is separate from the drawer. Closing the drawer or Settings does not quit the app. Quitting intentionally ends syncing and the custom edge surface; automatic start launches it at the next login. Existing macOS notification requests remain subject to OS behavior. No app can deliver fresh synced work while this Mac is powered off.

## Connection contract

Ordinary users must never be asked for a developer client ID, JSON file, API token, application secret or Cloud project. Those fields are only for contributors/internal deployments in **Diagnostics → Developer connections**.

Calendar already synced to the Mac connects through EventKit permission. Another Google, Outlook or Exchange calendar can be added in macOS Internet Accounts. This does not provide Gmail or Teams chat access.

A public **Continue with Google/Slack/Atlassian/Microsoft** button must be backed by the publisher's registered app and an accepted end-to-end account flow. A missing registration is shown as unavailable in the preview, without a dead sign-in button or a developer-console assignment for the user. Tokens remain scoped to the consenting account and are disconnectable. Corporate administrators may still require approval; the product cannot eliminate a tenant's policy.

## Attention contract

- Due-date cues have stable IDs and a retained local delivery ledger.
- Newly connected mail/chat sources start with a baseline instead of a historical alert storm.
- Subsequent incoming items can cue once. New Gmail activity has a distinct fingerprint.
- Completed, snoozed and demo fixtures do not produce inappropriate deadline cues.
- Workday and overnight-shift rules use the Mac's local calendar/time zone. The after-midnight portion belongs to the shift's starting weekday.
- Local focus sessions silence incoming-message cues; intentional deadlines still surface.
- Custom edge sounds are controlled separately from system notifications. macOS Focus controls macOS notifications; Holdlet does not claim to read or bypass the user's Focus state.
- No surprise full-panel takeover. Alerts nudge the handle without activating another app or stealing keyboard focus.

## Design contract

Native Apple materials, neutral typography, small capsules and rounded modules. No default pet, chat box, gradient dashboard or decorative activity feed. System text and accessible contrast take precedence over transparency. Reduce Transparency and Reduce Motion have appropriate fallbacks. The drawer's controls remain ordinary accessible native/SwiftUI controls.

## Corporate release contract

A usable corporate release needs more than a connector parser: publisher registrations, administrator consent guidance, dependable signed distribution, a documented retention policy, account identity and revocation handling, tenant restrictions, accessibility and real-device acceptance. Until those gates pass, describe the download as a developer preview.
