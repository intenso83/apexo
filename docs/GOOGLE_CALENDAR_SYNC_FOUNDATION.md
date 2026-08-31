# Google Calendar sync foundation

Status: **foundation implemented; live OAuth connection intentionally disabled**

This milestone adds the data model, Google Calendar API transport, privacy-safe
mapping, incremental-sync rules, conflict detection, and administrative
configuration needed for Google Calendar sync. It does not contain Google
credentials or persist OAuth access/refresh tokens.

## Multiple Apexo and Google accounts

- The clinic configures one public Google OAuth client ID for the Apexo
  installation.
- Every Apexo user connects their own Google or Google Workspace account from
  Settings. Google's OAuth account chooser determines which account is used.
- Calendar choice, sync direction, privacy mode, incremental token, status,
  and errors are stored separately under the Apexo account ID.
- A user's Google identity and sync settings are not reused by another Apexo
  login on the same computer.
- OAuth access and refresh tokens are never stored in ordinary Apexo settings.
  The live connector must keep them in platform-secure storage under an opaque
  per-user credential reference.

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

The local sync token is not an OAuth credential. OAuth access and refresh
tokens still need a platform-secure token store.

## Live connection checklist

1. Create or select a Google Cloud project for the dental practice.
2. Enable the Google Calendar API.
3. Configure the OAuth consent screen.
4. Create an OAuth client for the actual Apexo runtime. The current local
   browser build needs a Web client and authorised local origin/redirect URI;
   a future native Windows build should use the installed-app flow with PKCE.
5. Enter the public OAuth client ID under Apexo Settings. Never enter or commit
   a client secret in the Flutter client.
6. Add platform-secure token persistence and a Connect/Disconnect flow.
7. Request the narrow `calendar.events` scope. Add calendar-list scope only if
   the UI later offers a calendar picker.
8. Run a private test with a dedicated Google calendar before enabling the
   primary calendar.

## Production scheduling

For the local application, run sync after sign-in, after appointment changes,
on manual request, and periodically while Apexo is open. Google push
notifications require a public HTTPS webhook and are not guaranteed to deliver
every change, so they should be an optimisation rather than the source of
truth.

## Official references

- <https://developers.google.com/workspace/calendar/api/guides/sync>
- <https://developers.google.com/workspace/calendar/api/guides/create-events>
- <https://developers.google.com/workspace/calendar/api/guides/extended-properties>
- <https://developers.google.com/workspace/calendar/api/auth>
- <https://developers.google.com/identity/protocols/oauth2/native-app>
- <https://developers.google.com/identity/protocols/oauth2/policies>
- <https://developers.google.com/workspace/calendar/api/guides/push>
