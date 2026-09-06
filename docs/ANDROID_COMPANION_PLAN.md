# Apexo Android companion plan

Status: **planned; deliberately deferred until the desktop migration beta is validated**

Decision date: 2026-09-06

The Android application will remain part of the existing Flutter codebase. It
will be a focused staff companion, not a second full Apexo product and not a
pixel-scaled copy of the desktop interface.

## Owner decisions

- The periodontal chart is excluded from Android. It is neither displayed nor
  edited in the first mobile releases.
- Calendar interoperability is essential, not optional.
- Staff must be able to select an Apexo patient when creating an appointment.
- A linked Google Calendar event must use the patient's name and include the
  contact details enabled for export: telephone, mobile, email, and address.
- Staff must also be able to create a quick event with the normal Google
  Calendar application.
- Tapping a telephone number in Apexo must open the phone dialler.
- Names, telephone numbers, email addresses, and other displayed contact text
  must support normal Android text selection and copy/paste.
- Android is not part of the first DentalWin migration test phase. Desktop/Web
  portability and migration safety take priority.

## Proposed first Android scope

1. Agenda/day calendar with foreground refresh and a visible synchronization
   state.
2. Create and edit an appointment: patient, clinician, date, 24-hour time,
   duration, status, and short notes.
3. Patient search and compact patient summary.
4. Tap-to-call telephone and mobile numbers, email launch, and selectable
   contact text.
5. Read-only medical and treatment history.
6. Read-only odontogram with selected-tooth history.
7. Shopping-list cards with variation, quantity, purchased state, and
   yellow/red priority.
8. Lab-work cards with simple due/status updates.

Treatment-plan authoring, detailed odontogram entry, catalogue administration,
expenses, statistics, accounts, backups, migrations, DICOM, and the periodontal
chart remain desktop-first.

## Google Calendar design

The current Google authorization implementation is Web-only. Android therefore
needs its own authorization and token storage before it can provide the required
calendar behaviour. Tokens must be protected by Android Keystore-backed secure
storage and must never be placed in PocketBase rows or source code.

Use one dedicated Google calendar for Apexo. This gives the normal Google
Calendar application a safe, understandable boundary:

- An appointment created in Apexo is written to the dedicated calendar and is
  marked with private Apexo identifiers for duplicate prevention.
- An appointment edited in Google Calendar updates its linked Apexo appointment
  when synchronization runs.
- A new event created directly in that dedicated calendar appears in Apexo as
  an **unlinked calendar appointment**. Because an ordinary Google event has no
  trustworthy Apexo patient ID, the user links it to a patient in Apexo before
  patient details are attached. An exact unique name may be suggested but must
  not be silently accepted.
- From an Apexo patient, an **Open in Google Calendar** quick action may launch
  Android's standard event editor with the patient, time, and contact details
  already prepared. The ordinary Calendar application still owns the final
  save action.
- Personal events and events in other calendars are shown, at most, as private
  busy blocks; they are not converted into patient records.

Google descriptions may contain the owner's explicitly requested contact
details. The interface must make that disclosure clear because those details
then exist in the selected Google account as well as Apexo. Clinical notes,
treatments, teeth, prices, and payments remain excluded.

## Synchronization expectations

- Synchronize on app launch/resume, after an appointment save, after returning
  from the Google Calendar editor, and on pull-to-refresh.
- Display pending, success, conflict, and error states rather than promising
  continuous Android background execution.
- Use deterministic event identifiers/private markers and preserve the existing
  conflict-review behaviour.
- Use a bounded appointment date window and patient-specific lazy loading so a
  phone does not download the whole clinic database at every login.

## Mobile security gate

Before real patient data is placed on a phone:

- require the clinic's stable HTTPS PocketBase address; `127.0.0.1` refers to
  the phone itself;
- use a normal dentist account, never a PocketBase/System Admin account;
- protect tokens and cached clinical data with Android secure storage and an
  app re-authentication/biometric gate;
- disable the present unauthenticated offline-cache fallback until it is made
  safe;
- use generic lock-screen notification text without patient names;
- enforce server-side role permissions, not only hidden mobile controls; and
- distribute a signed release/AAB, not a debug APK.

## Delivery order

1. Complete and validate the desktop/Web migration beta.
2. Add a compile-time mobile feature profile and secure session/cache layer.
3. Implement the agenda, patient/contact, Google Calendar, shopping, and lab
   card interfaces.
4. Run a doctor-only Android beta against an HTTPS test clinic.
5. Add optional mobile editing only when chairside testing demonstrates a real
   need.
