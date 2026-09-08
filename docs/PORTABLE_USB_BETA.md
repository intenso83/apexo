# Portable USB beta plan

Status: **an empty, self-contained Windows test template is feasible; a real
patient migration remains a separate private and explicitly gated operation**

## Decision

Apexo can run from one encrypted USB drive at the practice and at home without
a paid or hosted PocketBase service. PocketBase is still required for real
records under the current architecture, but it can run locally from the same
USB drive at no service cost. The bundled server listens only on
`127.0.0.1:61110`, so it is not exposed to the practice LAN or the internet.

For the calendar-critical pilot, use the bundled **Apexo Web** interface in the
dedicated browser window opened by `Start-Apexo.cmd`. The launcher selects a
standard Microsoft Edge installation first and falls back to Google Chrome,
always with `Data\BrowserProfile` as its user-data directory. Apexo's primary
Hive/IndexedDB storage, authentication cache, and browser-local treatment plans
therefore travel with the encrypted USB instead of being written to the PC's
normal browser profile. Do not manually open the loopback URL in a normal
browser profile. The current native Windows build cannot authorize Google
Calendar; its authorization implementation is deliberately Web-only.

PocketBase serves both the web bundle and the API on the same fixed loopback
origin. This keeps the Google OAuth origin stable on both computers and avoids
requiring Python, Node, Docker, or an installed web server on the test PCs.

## Important limits

- One USB, one computer, one running Apexo server at a time. Never open the
  same `pb_data` from two processes or copy/synchronize it while PocketBase is
  running.
- This is transportable, not multi-site. The practice cannot use the database
  while the drive is at home. Simultaneous access later requires a properly
  secured hosted or practice-network server.
- The database, uploaded files, and dedicated browser profile travel on the
  USB. Treatment plans are currently local-first rather than synchronized to
  PocketBase, so they travel only because `Data\BrowserProfile` travels. They
  will be missing if Apexo is opened from a normal/incognito profile, if the
  profile is omitted during restore, or if browser storage is cleared.
- Google Calendar authorization remains device-sensitive. Apexo's Google
  access token is memory-only, and Edge/Chrome may protect Google cookies or
  other browser secrets with the Windows account/device. Expect to sign in,
  authorize, or reauthorize Google on each PC and after a browser restart,
  token expiry, browser update, or security challenge. A portable Apexo login
  cache must not be treated as portable Google authorization.
- The host supplies the Edge/Chrome executable. Keep both test PCs patched and
  on mutually compatible browser versions. Do not enable browser sync or save
  Apexo/Google passwords in the dedicated profile, import another browser
  profile, or use it for unrelated browsing.
- PocketBase's built-in static server does not apply the Cloudflare `_headers`
  file. The threaded DICOM WebAssembly viewer may therefore be unavailable in
  this browser-hosted portable mode. Patient and appointment/calendar testing
  does not depend on it; test Windows DICOM workflows separately.
- A `tel:` link can hand a number to the computer's registered calling app, but
  a Windows PC cannot place a cellular call unless Phone Link, Teams, or
  another call handler is installed and configured.
- A Google event's loopback patient link works only on a computer currently
  running this USB instance. It cannot open the patient record from a phone.
- The current released calendar synchronizer only imports Apexo-managed Google
  events. Confirm the separate “quick appointment created in Google Calendar”
  acceptance test before treating two-way quick entry as complete.
- Choose **Not Now** if the Web build asks to enable push notifications. The
  public push relay cannot call back to a `127.0.0.1` PocketBase server, so
  remote push is unavailable and relay enrollment is unnecessary in this
  portable mode. Calendar synchronization uses Google's API directly and does
  not depend on Apexo push notifications.

## Data-safety requirements

1. Use only trusted, patched Windows PCs on which you are authorized to handle
   the records. A compromised host can read the unlocked USB, browser session,
   and typed passwords. The dedicated profile avoids the normal host browser
   profile but is not anti-forensic: Windows, endpoint security, DNS, paging,
   and crash facilities may retain metadata or temporary traces.
   Printing and downloads can also write to host storage or spoolers; avoid
   them during the pilot, or explicitly choose an encrypted approved target.
2. Use a reliable SSD-class USB drive formatted for Windows and protected with
   BitLocker To Go. PocketBase's settings encryption flag does not encrypt the
   patient database or browser profile; full-volume encryption is required.
3. Store the BitLocker recovery key separately from the drive. Do not put an
   unencrypted recovery key, administrator password, or Google secret on the
   USB.
4. Keep both command windows open. Finish by first closing **every dedicated
   Apexo Edge/Chrome window**, then pressing Ctrl+C in the separate **Apexo
   Server** window, and finally waiting in the launcher window for the verified
   post-session backup before using Windows **Safely remove hardware**. Do not
   close the launcher first. The scripts never force-kill the browser or
   PocketBase; they wait or refuse a backup while either data set is in use.
5. The automatic `Backups` folder is on the same USB. It protects against some
   logical mistakes but not loss, theft, or drive failure. After every session,
   copy the newest ZIP and its `.sha256` file to a separate encrypted drive.
   The ZIP contains both `pb_data` and, after first launch, `BrowserProfile`, so
   it also contains browser-local records and potentially reusable session
   material and may be large. Protect it exactly like the live clinical drive.
   Backups are not auto-deleted; retain only the approved set after verifying
   independent encrypted copies, and remove obsolete archives deliberately.
6. Never email patient data, place it in a normal cloud-synchronization folder,
   or commit it to Git. Do not use FAT32 for a clinical database.
7. Do not restore by copying selected SQLite or browser files. Verify the
   backup checksum, confirm PocketBase and the dedicated browser are stopped,
   then restore complete `pb_data` and `BrowserProfile` directories together
   into an isolated copy. Google reauthorization may still be required on a
   different Windows account or PC.

## Build the empty distributable template

Build the web application with the pinned Flutter toolchain, and supply a
clean PocketBase 0.40.1 Windows executable:

```powershell
flutter build web --release
.\tool\build_portable_usb_beta.ps1 `
  -PocketBaseExecutable 'C:\safe-tools\pocketbase.exe'
```

The script writes an empty ZIP under `output\portable-usb`. It refuses to
overwrite an existing release, requires PocketBase 0.40.1, scans the web input
for common database/credential file types, copies only explicit launcher and
server-extension allowlists, rejects a stale web build unless explicitly
overridden, records whether the Git tree was dirty, and records SHA-256
checksums. It never copies a `pb_data` directory.

Publish the generated ZIP's `.sha256` value through a separate trusted channel
and verify it before extraction. `Verify-Apexo.cmd` rejects changed, missing,
or added immutable App/Server/launcher files, but an attacker able to replace
both the bundle and its internal manifest could forge that internal check.

The template contains:

```text
Apexo-Portable-USB-Template-<version>/
  App/Web/                 compiled browser application
  Server/pocketbase.exe    local PocketBase 0.40.1 runtime
  Server/pb_hooks/         tracked server hooks
  Server/pb_migrations/    tracked server migrations
  Data/                    empty in the distributable template
  Backups/                 offline session backups (private instance only)
  Initialize-Apexo.cmd
  Portable-Browser.ps1     Edge/Chrome selection and profile safety checks
  Start-Apexo.cmd
  Backup-Apexo.cmd
  Verify-Apexo.cmd
```

## First synthetic test

1. Extract the template directly onto an encrypted test USB drive.
2. Run `Verify-Apexo.cmd` and confirm the state says `EMPTY TEMPLATE`.
3. Run `Initialize-Apexo.cmd` once. It prompts for a new bootstrap superuser
   email and password and does not save the password.
4. Run `Start-Apexo.cmd`. Keep its window open and use only the dedicated Edge
   or Chrome window it launches. Confirm that `Data\BrowserProfile` is created
   on the USB; the template itself must not contain that directory.
   `Start-Apexo.cmd` refuses to begin if Windows `tar.exe` is unavailable,
   because a complete portable browser-profile backup is mandatory.
5. In Apexo's login form, enter `http://127.0.0.1:61110` as the **Server URL**
   (with no `/api` or `/_/` suffix), then use the bootstrap credentials from
   step 3. The first superuser login lets Apexo create its normal collections.
   Open Apexo's Accounts screen, create a **normal user** with only the
   permissions required for the pilot, sign out, and use that account for all
   routine work.
   Reserve the bootstrap superuser for account/schema administration. If the
   normal user must own appointments, explicitly enable that user's
   operator/clinician setting (and no broader permissions).
6. Use synthetic patients and appointments only. Restart on the same PC, then
   stop cleanly, safely eject, move the USB to the second PC, and repeat.
7. On each PC, verify that the server records and browser-local treatment plans
   travel with the USB profile. Configure
   Google OAuth with authorized JavaScript origin
   `http://127.0.0.1:61110`, then authorize the Google account separately on
   each PC. Expect reauthorization; do not save its password or enable browser
   sync.
8. Verify both calendar directions, duplicate prevention, time zones,
   24-hour display, patient/contact mapping, and conflict handling before any
   clinical use.

PocketBase 0.40.1's supported superuser CLI accepts the initial password as a
positional process argument. The initializer prompts securely and never writes
the password to disk, but the value exists briefly in the PocketBase process's
command line and could be observed by another administrator on that Windows
computer. Initialize only on a trusted computer, then change the administrator
password through the loopback PocketBase dashboard before importing real data.
After the first bootstrap login, creating and using a least-privileged normal
Apexo account is mandatory; routine clinical work must not use a PocketBase
superuser.

## Serious migration gates

The generated ZIP is safe to distribute because it is empty. The later
migrated USB folder is private clinical media and must never replace or be
published as the template.

Proceed in this order:

1. Freeze and checksum a read-only copy of the DentalWin source. Keep the
   original system untouched and available for rollback/reference.
2. Create two independent encrypted backups: the source snapshot and the
   initialized-but-empty portable `pb_data` directory. Verify their hashes and
   perform a restore rehearsal into an isolated directory.
3. Run the existing migration dry run and review record counts, rejected rows,
   duplicates, identity mappings, Unicode names, dates/time zones, contact
   normalization, appointments, treatment history, files, and financial
   exclusions.
4. Import only into a **private copy** of the portable instance. Never import
   into the distributable template and never point the importer at an unknown
   or non-loopback server.
5. Reconcile source-to-target counts and representative patient files. Record
   the migration batch identifier and checksums. No discrepancy should be
   accepted silently.
6. Test the private migrated copy at one location with read-only/rehearsal
   activity first. Take another full offline backup before allowing new writes.
7. Define a cutover time. After cutover, enter new work in one system only;
   parallel edits in DentalWin and Apexo create an unmergeable split history.
8. Keep DentalWin and the verified pre-cutover backup available until the beta
   acceptance period is signed off. A production migration remains a separate
   approval.

The repository's detailed migration controls remain in
`DENTALWIN_MIGRATION_BLUEPRINT.md` and the phase verification documents. The
portable packaging scripts do not authorize or perform a real-data import.
