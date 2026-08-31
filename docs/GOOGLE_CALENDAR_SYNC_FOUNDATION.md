# Google Calendar sync foundation

Status: **live Web OAuth and manual synchronization implemented; private Google
Cloud credentials are still required for a real-account test**

This milestone includes the data model, Google Calendar API transport,
privacy-safe mapping, incremental-sync rules, conflict detection, per-user
Google account chooser, Connect/Reconnect/Disconnect controls, and manual
`Sync now`. It does not contain Google credentials or persist OAuth access or
refresh tokens.

## Multiple Apexo and Google accounts

- The clinic configures one public Google OAuth client ID for the Apexo
  installation.
- Every Apexo user connects their own Google or Google Workspace account from
  Settings. Google's OAuth account chooser determines which account is used.
- Calendar choice, sync direction, privacy mode, incremental token, status,
  and errors are stored separately under the Apexo account ID.
- A user's Google identity and sync settings are not reused by another Apexo
  login on the same computer.
- OAuth access tokens are held only in browser memory. They disappear after a
  page/browser restart and the user then explicitly reconnects. Apexo stores
  only the Google email, an opaque non-secret connection marker, and sync
  status under the Apexo account ID.
- Google Identity Services' browser token model does not issue a refresh token.
  An expired access token is renewed only from the user's Connect or Sync-now
  click, as required by Google's user-gesture rule.

## Safe default behaviour

- Only events created and privately marked by Apexo are read back. Personal
  Google events are not turned into patient appointments.
- The default event title is `Dental appointment`.
- Patient names are an explicit opt-in.
- Clinical notes, treatment names, teeth, phone numbers, prices, and payment
  information are never exported by the mapper.
- Deleting a Google event does not silently delete or archive the clinical
  appointment in Apexo. It creates a sync issue for review.
- A simultaneous edit in both systems creates a conflict instead of applying
  a last-write-wins overwrite.
- Archiving an Apexo appointment removes its linked Google event.
- Each user exports only appointments whose `operatorsIDs` contains that Apexo
  account ID. Removing the user from an appointment removes that user's linked
  Google event during the next manual sync.

## Duplicate prevention and ownership

Apexo generates a deterministic Google event ID from the clinic identity,
Apexo account ID, and appointment ID. An appointment keeps a separate Google
event link for every connected Apexo account, so one user's sync cannot
overwrite another user's event. Every event also receives private extended
properties:

- `apexoManaged=1`
- `apexoClinicId=<clinic identity>`
- `apexoAccountId=<Apexo account identity>`
- `apexoAppointmentId=<appointment ID>`

The private properties let the initial Calendar API query return only events
owned by this Apexo clinic. Google does not allow that filter together with an
incremental sync token, so later change pages are filtered locally and every
event without the matching Apexo ownership markers is ignored. The
deterministic ID makes a retry converge on the same event rather than creating
a second appointment.

## Incremental sync

The first run fetches the configured date window and stores Google's final
`nextSyncToken`. Later runs request only changes with that token. If Google
returns HTTP 410, Apexo discards the expired token and performs a full sync, as
required by the Calendar API.

The local sync token is not an OAuth credential and may safely persist in the
per-user device settings.

## Live connection checklist

1. Create or select a Google Cloud project for the dental practice.
2. Enable the Google Calendar API.
3. Configure the OAuth consent screen.
4. Create an OAuth client with application type **Web application**.
5. Add the exact Apexo test origin under **Authorized JavaScript origins**:
   `http://127.0.0.1:61110`. No redirect URI or client secret is used by this
   callback-based token flow.
6. While the OAuth app is in Testing, add each dentist's Gmail/Workspace
   account as an OAuth test user.
7. In Apexo Settings, enable Google Calendar and save the public client ID
   ending in `.apps.googleusercontent.com`. Never enter or commit a client
   secret in the Flutter client.
8. Each Apexo user opens their own Settings, presses **Connect Google
   account**, chooses their account, enables personal sync, and presses
   **Sync now**.
9. Start with a dedicated Google calendar ID if desired; `primary` targets the
   selected account's main calendar.

The requested scopes are `calendar.events` and `userinfo.email`. The latter is
used only to display and enforce which Google identity belongs to the current
Apexo user. Calendar-list permission is deliberately not requested because the
current UI accepts `primary` or a manually entered calendar ID.

## Production scheduling

The first live-test milestone exposes manual synchronization. A later
production milestone can add debounced sync after appointment changes and a
periodic refresh while an in-memory authorization remains valid. Google push
notifications require a public HTTPS webhook and are not guaranteed to deliver
every change, so they should be an optimisation rather than the source of
truth.

## Official references

- <https://developers.google.com/workspace/calendar/api/guides/sync>
- <https://developers.google.com/workspace/calendar/api/guides/create-events>
- <https://developers.google.com/workspace/calendar/api/guides/extended-properties>
- <https://developers.google.com/workspace/calendar/api/auth>
- <https://developers.google.com/identity/oauth2/web/guides/use-token-model>
- <https://developers.google.com/identity/gsi/web/guides/get-google-api-clientid>
- <https://developers.google.com/identity/protocols/oauth2/native-app>
- <https://developers.google.com/identity/protocols/oauth2/policies>
- <https://developers.google.com/workspace/calendar/api/guides/push>
