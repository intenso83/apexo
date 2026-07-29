# Phase 0 repository audit

Audit date: 2026-07-28. This is a code audit of commit `d06facb`; no patient data or
practice secrets were used. Claims marked **verified** were checked in source.
Runtime claims are separated because this environment did not contain Flutter/Dart
and network policy prevented downloading Flutter.

## Executive orientation

Apexo is a Flutter/Dart client, not a conventional frontend plus custom backend.
It uses a separately hosted PocketBase server (SQLite internally), dynamically
creates a small generic PocketBase schema on an administrator's first login, keeps
per-store JSON documents in local Hive boxes, and synchronizes changes to a generic
remote `data` collection. This is genuinely offline-capable after a successful
login/sync, but it is not yet a practice-ready clinical record architecture.

The present model is compact: patient demographics and whole-tooth state maps;
appointments also carry notes, tooth maps, prescriptions, price/payment, lab fields,
drawings, and attachments. There are no repository migration files, immutable audit
trail, structured medical-history/allergy/medication fields, treatment-plan entity,
document metadata entity, or safe batch-import ledger. Those gaps make a migration
foundation the recommended first implementation milestone.

## Architecture (verified against code)

| Area | Current implementation |
| --- | --- |
| UI/client | Flutter 3/Dart 3 single codebase using `fluent_ui`; targets Windows, web, Android, iOS, macOS, and Linux scaffolding. |
| Backend | No backend source is vendored. The client uses the PocketBase Dart SDK and expects a separately installed PocketBase server. |
| Database/schema | PocketBase's SQLite-backed database. On first admin login the client imports `data`, public appointment view, `profiles`, and `profiles_view` collection definitions from Dart constants. There are no versioned migration files. |
| Local/offline | Each logical store writes serialized model JSON to two Hive boxes (data and sync metadata) in the application files directory. Changes made offline are deferred and later synchronized. Web uses browser-backed Hive behavior. |
| Synchronization | `Store<Model>` combines `SaveLocal` and `SaveRemote`. Remote rows share one `data` collection and are namespaced by a `store` string. Pulls use PocketBase `updated` timestamps; writes use batches/upserts; realtime and reconnect callbacks trigger synchronization. This is last-write/version oriented, not a field-level conflict-review workflow. |
| Authentication | PocketBase password/token authentication against `_superusers` first and then `users`. A profile stores a JSON permission array. Nine indexed permission slots cover patients, appointments, post-op, stats, expenses, settings, photos, notes, and revenue, generally at none/limited/full levels. Enforcement is partly in client model/UI logic. |
| Patients | `Patient` extends the generic `Model` (`id`, `title`, archive flag). Fields are birth **year** (not full DOB), binary-coded gender, phone list, email, address, tags, free-text notes, whole-tooth state map, per-tooth extra-note map, and a patient link. Registration date and structured medical data are absent. Balance is computed from completed appointments. |
| Appointments/clinical records | `Appointment` links by `patientID`; includes operator IDs, pre/post-op notes, prescriptions, price/paid, date/duration/status, whole-tooth maps and extra notes, lab fields, drawings, and attachment names. Appointment completion doubles as the main chronological treatment/financial record. |
| Dental chart | SVG selector keyed by ISO/FDI-like tooth identifiers, including primary teeth. Patient maps hold existing/history state; appointment maps hold treatment. State is a string per whole tooth, with no surface-level model or separate diagnosis/plan/completion entities. |
| Files | Attachments are PocketBase file fields (`imgs`, up to 99 files and 150 MiB each) on generic data rows, with desktop/mobile local cached copies and thumbnails. Despite the name, non-image files can be attached. PocketBase can be configured for S3 storage. There is no dedicated document metadata, category, hash, retention, consent version, or file audit model. |
| Import/export | UI can paste patient and appointment CSV and calls `setAll` directly; exports selected patient/appointment JSON fields as CSV. There is also photo import by URL and PocketBase ZIP backup upload/download/restore. CSV import has no preview report, schema mapping, batch ID, duplicate review, dry run, transaction, or XLSX support. It is unsuitable for DentalWin production migration. |
| Localization | A custom dictionary (`txt`/`Txt`) supports English, Arabic, Spanish, Greek, and Persian. English and Greek source dictionaries each expose 592 keys by a source-level key comparison, with no missing/extra Greek keys. This checks key coverage, not translation accuracy. Greek date symbols are not explicitly initialized in `main.dart` (English, Arabic, and Spanish are). |
| Tests | `flutter_test` unit tests plus a custom Flutter integration-test harness. The documented unit suite is intentionally split because some tests cannot run in parallel. A localization auditor is provided as a standalone Dart script. |
| Deployment | Client builds are documented per platform. Server setup documentation assumes a separately installed, freshly initialized PocketBase and has cloud-hosting examples. No Dockerfile/Compose file or PocketBase binary/version pin exists in this repository. |
| License | GNU GPL version 3; upstream notices and attribution must remain. |

## Repository map

- `lib/main.dart`, `lib/app/`: startup, navigation, desktop/panel shell.
- `lib/core/`: base model, observable state, Hive persistence, PocketBase remote
  persistence, and synchronization store.
- `lib/features/patients/`, `lib/features/appointments/`: primary clinical models,
  stores, screens, and edit panels.
- `lib/common_widgets/teeth_selector/`: SVG tooth chart and selectable clinical
  state/treatment controls.
- `lib/features/accounts/`, `lib/services/login.dart`, `lib/services/perm.dart`:
  PocketBase accounts, login, and indexed role permissions.
- `lib/features/settings/`: local/global settings and PocketBase backup, file-upload,
  SMTP, and S3 administration.
- `lib/services/localization/`: five dictionaries and localization audit utility;
  `el.dart` is the existing Greek translation and must be preserved.
- `lib/services/ai_services*`, `lib/services/g_audio_transcription.dart`: optional
  remote Apexo AI-worker integrations.
- `lib/services/notifications/`: Firebase/push-relay integration.
- `test/unit/`, `integration_test/`: unit and UI integration tests.
- `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`: Flutter platform
  runners. `pubspec.yaml`/`pubspec.lock` pin application dependencies.
- `manual.md`: user/server instructions. `README.md`: project and release overview.

## Reproducible development setup

### Recommended Windows 11 / WSL2 orientation

For this Flutter repository, use Windows Flutter for the Windows desktop target;
use WSL2 for supporting scripts/server work. A Windows build cannot be produced
inside Linux WSL. Do not use real data for setup.

1. Install the current Flutter stable SDK and prerequisites from Flutter's official
   installation documentation, then open a fresh terminal.
2. From the repository root, run these **safe, non-destructive** commands:

   ```powershell
   flutter doctor -v
   flutter pub get
   dart run lib/services/localization/verify.dart
   flutter analyze
   flutter test test/unit/utils_test
   flutter test test/unit/services_test
   flutter test test/unit/core_test/model_test.dart
   flutter test test/unit/core_test/multi_stream_builder_test.dart
   flutter test test/unit/core_test/observable_test.dart
   flutter test test/unit/core_test/save_local_test.dart
   flutter test test/unit/core_test/save_remote_test.dart
   flutter test test/unit/core_test/store_test.dart
   flutter build windows --debug
   flutter run -d windows
   ```

   `flutter pub get` modifies only generated dependency metadata/caches (the lockfile
   is already committed). The tests can write disposable local test files but do not
   target a practice database. `flutter run` starts the client; do not point it at a
   production server during development.

3. For web validation (also safe and without practice data):

   ```powershell
   flutter build web --release
   flutter run -d chrome
   ```

4. PocketBase is required to validate real login/sync. The repository does **not**
   pin a compatible PocketBase version or provide a local container. Until that is
   corrected, use only an isolated test server and synthetic data. First admin login
   mutates that server by creating/updating collections and enabling the batch API;
   it is therefore **not** a read-only step.

### Commands actually run in the audit environment

```bash
pwd
find .. -name AGENTS.md -print
find . -maxdepth 2 -mindepth 1 -not -path './.git/*' | sort
git status --short --branch
flutter --version
dart --version
find /opt /usr/local /root -maxdepth 4 -type f -name flutter -o -name dart
git clone --depth 1 --branch stable https://github.com/flutter/flutter.git /tmp/flutter
python3 <source-level English/Greek dictionary key comparison>
```

Source inspection also used `sed`, `find`, `rg`, `wc`, `git log`, and `uname` against
the files/modules listed above. `flutter --version` and `dart --version` failed with
“command not found.” The fallback Flutter clone failed because the environment's
network proxy returned HTTP 403. Consequently dependency installation, analyzer,
localization auditor, unit/integration tests, builds, and application startup could
not be executed here. The Python source comparison succeeded: English 592 keys,
Greek 592 keys, zero missing and zero extra. This is an environment blocker, not a
successful runtime verification.

## Security and data-integrity observations

### Critical/high priority

1. The `public` PocketBase view has empty list/view rules (unauthenticated access)
   and exposes appointment identifiers, attachment names, patient IDs, dates,
   prescriptions, prices, payments, status, and archive state. It appears intended
   for patient links, but its broad unauthenticated query is inappropriate for a
   clinical deployment without a scoped, expiring access design.
2. All authenticated users can read/write the generic `data` collection at the
   server-rule level (except global-settings writes). Fine-grained permissions are
   substantially client-enforced, so a legitimate low-privilege account could call
   PocketBase directly and bypass UI restrictions. Server-side authorization must
   become authoritative.
3. Production release errors are sent to Sentry, mobile/desktop startup initializes
   Firebase messaging, notifications use an Apexo-hosted relay, patient links use
   Apexo/Cloudflare endpoints, and optional transcription/AI uploads audio/images and
   clinical context to an Apexo worker. These external paths conflict with a strict
   offline/private-health-data posture unless explicitly disabled/replaced and
   documented. Some voice debug output includes full transcripts.
4. CSV import immediately mutates stores without validation/reporting/transactional
   batch semantics. It must not be used for unsupervised DentalWin or OCR migration.

### Important design risks

- No schema migration/version mechanism or pinned PocketBase server version makes
  reproducible upgrades and rollback uncertain. Runtime first-login schema mutation
  is difficult to review operationally.
- Timestamp-based synchronization and generic JSON rows have no visible conflict
  review, immutable change audit, foreign-key constraints, or field-level history.
- Authentication tokens and cached clinical data are persisted locally; no explicit
  at-rest encryption was found. Workstation disk encryption, session timeout/lock,
  cache lifecycle, and stolen-device response require design and verification.
- File URLs are constructed directly and the file field is declared unprotected.
  Authorization behavior needs an end-to-end test. Local caches also need encryption
  and cleanup policy. A dedicated metadata record plus private PocketBase/S3 objects
  is recommended for future documents; large CBCT/STL datasets may instead use a
  controlled external store/reference with integrity and availability checks.
- Backup creation/restore exists, but restore is destructive and the audit found no
  automated restore test, encryption requirement, off-site rotation runbook, or
  documented recovery objective.
- Patient birth is only a year; gender has two numeric states; registration date,
  allergies, medication, alerts, consent provenance, and a structured timeline are
  absent. Do not force legacy data into semantically incorrect fields.
- Repository `.gitignore` covers a few local files but does not explicitly reject
  DentalWin/Access (`.mdb`, `.accdb`), SQLite/PocketBase data, XLSX/CSV migration
  working files, or common backup/archive patterns. A careful allowlist/fixture
  strategy is needed without hiding legitimate project assets.

## Greek localization status

**Verified:** `El` extends the English locale class and supplies a complete parallel
dictionary by key count (592/592 in the simple source parser). Greek is already in
the locale selection list. It was not recreated or edited. **Not verified:** native
Greek review, layout quality, runtime auditor output, or Greek date/calendar behavior.
The wording of newer AI/privacy strings deserves professional review, especially
claims about remote processing. Greek date symbols should be initialized/tested.

## Three candidate first milestones

### 1. Safe migration and data-governance foundation — **recommended first**

- **Practical value:** establishes non-negotiable provenance, idempotency, validation,
  dry-run, duplicate review, and audit primitives before any DentalWin data is mapped.
- **Modules:** new versioned PocketBase migration mechanism/schema; import batch,
  source-record mapping and redacted result models/services; synthetic fixtures and
  documentation. Existing `core` persistence and CSV import must be integrated rather
  than silently bypassed.
- **Risk:** medium: it introduces durable schema, but is additive and can be built in
  an isolated database before patient data exists.
- **Migration impact:** positive and foundational; no legacy database is required for
  this milestone, and no production import occurs.
- **Tests:** migration up/down/recovery on disposable PocketBase; transaction failure;
  identical batch replay; cross-batch additivity; duplicate flagging; Greek Unicode
  and ambiguous date cases; redacted reports; count reconciliation.
- **Why first:** every later clinical or import feature needs stable provenance and
  audit semantics. Building an ad-hoc extractor first would institutionalize today's
  unsafe direct-import path.

### 2. Security/offline deployment baseline

- **Practical value:** pins PocketBase, provides reproducible local-network deployment,
  moves authorization server-side, closes the public appointment exposure, inventories
  outbound services, and establishes backup/restore verification.
- **Modules:** PocketBase rules/migrations, deployment configuration, login/session,
  notifications/AI/Sentry feature gates, backup runbook and integration tests.
- **Risk:** medium-high because tightening rules can break sync and patient-link flows.
- **Migration impact:** none to legacy data; requires a controlled migration of current
  server rules and extensive rollback testing.
- **Tests:** role-by-role direct API denial tests, file URL tests, offline/reconnect
  scenarios, clean install, upgrade, encrypted backup and full restore drill.
- **Why not first:** it is urgently required before production, but combining it with
  migration primitives would be too broad. Begin immediately after (or narrowly in
  parallel with) the additive migration foundation; never deploy real records before
  completing it.

### 3. Structured patient safety summary

- **Practical value:** adds registration date, allergies, medications, conditions,
  and prominent alerts so clinicians see essential information quickly in Greek or
  English.
- **Modules:** patient model/schema migration, patient panel and summary, localization,
  search, export, audit/provenance layer.
- **Risk:** medium-high: incorrect clinical overwrites or hidden alerts have direct
  patient-safety consequences.
- **Migration impact:** new optional fields and mapping targets; existing free text is
  preserved, never auto-parsed or deleted.
- **Tests:** backward-compatible serialization, validation, permissions, alert display,
  Greek/English UI, export/backup/restore, and concurrent/offline edits.
- **Why not first:** it has high daily value, but should be built on an audit-capable,
  versioned schema so future intake and DentalWin imports can stage changes safely.

## Recommended sequence and current blockers

Start with milestone 1, then security/deployment baseline, then structured patient
safety data. Before implementation, provide a **sanitized schema-only** DentalWin
export (no names, addresses, notes, telephone numbers, or other patient values), or a
synthetic `.mdb` with the same tables/relationships. Do not provide the production
backup yet. Also establish a Windows Flutter workstation so the commands above can
produce a real green/red baseline. PocketBase compatibility cannot be fully verified
until its exact intended version is identified and an isolated server is available.
