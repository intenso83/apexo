# Patient-only Android intake

The patient intake is a separate Flutter application in `intake_app/`. It is
not an Apexo flavor and does not link to Apexo screens, login state, stores, or
the PocketBase client SDK.

## Security boundary

- Android application id: `com.edimitrakopoulos.intake`
- Android label: `Patient Intake`
- Declared Android capability: Internet only
- No Apexo credentials are stored in the application.
- No collection list, view, create, update, or delete rule is exposed to a
  patient.
- Patient answers remain in memory, are sent only from the final confirmation
  screen, and are cleared after a successful response.
- Form settings are available only from the staff preparation screen, before a
  patient session starts. They are protected by a local password. The app stores
  a random salt and a PBKDF2-HMAC-SHA256 verifier, never the password itself,
  and temporarily locks settings after five incorrect attempts.
- The server accepts a submission only with a 15-character PocketBase record id
  created by authenticated staff. The id expires after 30 minutes and is marked
  used in the same transaction that stores the submission.
- A successful patient request returns only a receipt id. It cannot read a
  session, submission, patient, or medical-history record.

The app blocks its own Android back navigation and uses immersive mode during
the patient flow. For a reception tablet, also enable Android screen pinning.
True device-owner kiosk mode requires Android enterprise/device provisioning
and is intentionally not claimed by the app itself.

## Test build

`output/android/Dimitrakopoulos-Patient-Intake-test.apk` is built without an
`INTAKE_SERVER_URL`. It exercises the complete phone/tablet UI but deliberately
does not save or transmit answers. The completion screen says this explicitly.

The test build can be installed alongside Apexo because it has a separate
application id. Android 7.0 (API 24) or newer is required.

## Local form settings

Tap `Form settings` on the staff preparation screen. On first use, create a
password of at least eight characters. There is intentionally no recovery
backdoor; if the password is forgotten, clear the app's Android storage and
configure the form again.

The settings screen allows staff to:

- show or hide every optional personal field and medical-history question;
- drag entries into a different order or move them to another page;
- reorder, enable, disable, and rename pages in Greek, English, and German;
- add custom pages and delete them again after their entries have been moved;
- change the local settings password or restore the original layout.

Family name, first name, and date of birth are always enabled. At least one of
mobile, telephone, or email must remain enabled. The welcome/privacy step and
the review/confirmation/signature step are fixed. A saved configuration takes
effect on the next patient form and remains on that device until changed or the
Android app data is cleared.

The final step records both the patient's typed full name and normalized drawn
signature strokes from a finger or stylus. The server validates drawn points
before accepting the packet.

## Server deployment

The tested server extension targets PocketBase 0.40.1:

- `server/pocketbase/pb_migrations/1788372000_create_patient_intake.js`
- `server/pocketbase/pb_hooks/apexo_intake.pb.js`

Back up the production PocketBase data directory first. Copy these directories
to the PocketBase instance's configured `pb_migrations` and `pb_hooks`
directories, then restart PocketBase. Unapplied migrations run at startup by
default. If the production server is older than 0.40.1, upgrade and verify it
before deploying this extension rather than copying the tested files blindly.

The migration creates `intake_sessions` and `intake_submissions` with all five
API rules set to locked (`null`). Only custom routes touch them:

- `POST /api/apexo/intake/sessions` — authenticated `users` or `_superusers`
- `POST /api/apexo/intake/submit` — guest, one-time session required
- `GET /api/apexo/intake/submissions` — authenticated staff only
- `POST /api/apexo/intake/submissions/{id}/imported` — authenticated staff
- `POST /api/apexo/intake/submissions/{id}/rejected` — authenticated staff

Production must use a valid HTTPS URL. The Android manifest rejects cleartext
traffic, and the Dart submission client rejects non-HTTPS configuration.

## Production APK

After the server extension is deployed, build from `intake_app/`:

```powershell
flutter build apk --release --dart-define=INTAKE_SERVER_URL=https://clinic.example
```

Use the clinic's real PocketBase public HTTPS origin. Do not include a user,
password, token, or collection key in the build command.

The current Gradle release configuration uses the debug signing key for local
testing. Configure the practice's protected Android release keystore before a
permanent production rollout or managed-device distribution.

## Staff workflow in Apexo

The Patients screen contains a `Patient intake` command:

1. Staff selects `Prepare tablet session`; Apexo creates and copies a one-time
   session id.
2. Staff enters the id into the patient app and starts the form before handing
   over the tablet.
3. The patient completes the multi-page form and submits it.
4. Staff refreshes pending submissions in Apexo and reviews possible matches.
5. Staff explicitly chooses either a new patient or an existing patient.
6. For an existing patient, only currently empty personal fields are filled;
   existing values are never overwritten. A new immutable medical-history
   revision is added.
7. Apexo marks the server submission imported only after patient and medical
   history stores report that they are synchronized.

Question ids and the questionnaire version are shared with the DentalWin
migration model. A test verifies that every canonical question id appears in
the tablet schema and the server validator.
