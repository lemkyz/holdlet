# Connect your tools

## Everyday setup

Open **Settings → General → Set up my Mac**. Holdlet requests Calendar/notification permission and enables launch at login. Rejected permissions lead directly to their macOS settings pages. In **Connections**, choose calendars already synced to this Mac, or open **Internet Accounts** using the add-calendar button. Google, Outlook, Exchange and iCloud calendars in Calendar.app share this path.

Close Settings: the edge handle and menu icon stay available. Drag the handle to any edge/display, click or scroll inward to open, and use Escape or outward scrolling to hide. Control + Option + H is the default global shortcut. Quitting intentionally stops syncing; automatic start runs at the next login.

No developer project or pasted token is required for everyday use. Public Gmail/Slack/Jira sign-in is unavailable in this preview until publisher registrations are completed. This is separate from Calendar.app support.

## Internal developer connections

The following instructions are only for contributors/internal testing. Open **Settings → Diagnostics → Developer connections** to reach the credential fields. They are not part of ordinary onboarding.

Never paste tokens into GitHub issues or chat. Google credentials are saved to Keychain after authorization succeeds; importing a client file only fills the in-memory form.

## Mac Calendar - quickest path

1. Add your Google, Exchange or iCloud account to Apple's Calendar app if needed.
2. Holdlet → Settings → Connections → Mac Calendar → Allow access.
3. Select the calendars to watch. With no explicit selection, all available calendars are used.
4. Events already synced with Calendar.app appear after refresh. Holdlet does not write events.

Mac Calendar and direct Google Calendar are alternative event sources, but Gmail is independent. Connecting Google while Mac Calendar is active preserves it and connects Gmail. Turn on **Use direct Google Calendar** to switch event sources. Switching back to Mac Calendar does not disconnect Gmail.

## Google Calendar and Gmail

1. Create/select a Google Cloud project you control.
2. Enable the **Google Calendar API** and **Gmail API**.
3. Configure the OAuth consent screen. For a personal test project in Testing mode, add your own Google account as a test user.
4. Create an OAuth client of type **Desktop app**. A Web client is not interchangeable.
5. Download that client's JSON file. In Holdlet choose **Set up Google connection** and select the file. The app fills the matching ID and secret together and rejects Web client files. Manual fields remain under developer configuration. Do not commit the downloaded client JSON.
6. Select **Sign in with Google**, complete the external browser flow, and return to Holdlet. Holdlet binds a temporary `127.0.0.1` port, verifies `state`, and exchanges the code with a PKCE verifier.

Scopes:

```
https://www.googleapis.com/auth/calendar.events.readonly
https://www.googleapis.com/auth/gmail.readonly
```

The Calendar adapter reads only the primary calendar. Gmail searches using your query (default: `is:unread is:important newer_than:7d`) and fetches thread metadata/headers, not full bodies. Gmail `readonly` is broader than metadata-only access: it is requested because query-based search needs it. This distinction is intentional and must be visible during consent.

Testing-mode refresh-token lifetime and Workspace admin policies can require reauthorization. Public distribution of a shared OAuth app requires Google's applicable verification process; open-source status does not bypass it.

Use an item's menu → **Waiting for reply** to track a Gmail thread even after it no longer matches the search query. When the latest non-SENT/non-DRAFT message ID changes, the thread returns to Active. This means “new incoming activity,” not a guarantee that the message semantically answers your question. Slack waiting states remain manual.

Gmail web links use account slot `/u/0/`; if multiple Google browser accounts are signed in, switch to the connected account before opening a thread. Multi-account browser routing is not implemented.

References: [native OAuth](https://developers.google.com/identity/protocols/oauth2/native-app), [Gmail scopes](https://developers.google.com/workspace/gmail/api/auth/scopes), [Gmail thread metadata](https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.threads/get).

## Slack - internal personal setup

1. Create/install an internal Slack app in a workspace where your administrator allows it.
2. Add the **user token scope** `search:read`. A bot token is insufficient for this adapter.
3. Obtain the user OAuth token through Slack's approved app setup/install flow.
4. Paste it into Holdlet → Connections → Slack. The token is never included in URLs.
5. Choose a narrow native Slack search query. Example: `to:me after:2026-10-01`. The default `to:me after:{weekAgo}` replaces `{weekAgo}` with the local date seven days before each sync.
6. Select **Test and connect**. Holdlet only saves the token after a successful search.

This reads matching messages visible to your user; it does not read everything, monitor arbitrary notifications, or determine whether you replied. More than 100 matches yields an error instead of silently hiding results. Narrow the query. Retention policies, plan limits and admin permissions still apply. Respect provider policy; this is not a workaround for Marketplace distribution requirements. A public managed Slack integration is a separate milestone.

References: [search.messages](https://docs.slack.dev/reference/methods/search.messages/), [search:read](https://docs.slack.dev/reference/scopes/search.read/), [rate limits](https://docs.slack.dev/apis/web-api/rate-limits/).

## Jira Cloud - personal token setup

1. Use an **unscoped personal API token** from your Atlassian account. This alpha uses site-based Basic authentication; scoped API gateway tokens need a different adapter and are not supported.
2. Enter an HTTPS site such as `https://your-company.atlassian.net`, your Atlassian account email and the token.
3. Select **Test and connect**.

Query: `assignee = currentUser() AND statusCategory != Done ORDER BY duedate ASC, updated DESC`. Reads summary, status and due date via `/rest/api/3/search/jql`. It does not update Jira. Maximum 100 open assigned issues; larger result sets report an error. Date-only due dates are shown at **17:00 in this Mac's time zone**; Jira does not supply a precise time in that field.

Reference: [Atlassian token authentication](https://developer.atlassian.com/cloud/jira/platform/basic-auth-for-rest-apis/).

## Disconnect and revoke

Disconnect removes local records/keys and pending reminders for the source. For a Google Calendar/Mac Calendar switch, see the separate behavior above. To revoke provider access entirely, also use your Google account's connected-app settings, Slack app management, or Atlassian API-token settings. Removing the app does not necessarily revoke remote grants.

## Delivery expectations

Sync is periodic (3 minutes while awake), not push. Calendar.app's own upstream synchronization adds delay. The app keeps the previous snapshot on errors and shows connection health. Narrow queries when result caps are reached. On sleep, the OS controls background execution; on wake the app refreshes and shows open work. Test notification permission, Focus and your usual screen/display configuration. Local reminders remain usable without any connected account.
