# Apexo portable USB beta

This is an **empty distributable template**. It contains the Apexo Web build,
PocketBase, and safe launch/backup scripts. It contains no patient data,
browser profile, passwords, OAuth tokens, or initialized database.

Use it only on a trusted Windows PC with Microsoft Edge (preferred) or Google
Chrome installed. Put the extracted folder on a reliable, fully encrypted USB
drive (for example, BitLocker To Go); encryption protects the drive at rest but
does not make an untrusted or infected PC safe.

1. Run `Verify-Apexo.cmd` and confirm it reports `EMPTY TEMPLATE`.
2. Run `Initialize-Apexo.cmd` once to create the bootstrap superuser.
3. Run `Start-Apexo.cmd`. Always use the dedicated browser window it opens;
   do not open Apexo in a normal browser profile. Apexo's Hive/IndexedDB data,
   login cache, and browser-local treatment plans are kept on the USB under
   `Data\BrowserProfile`. Start refuses if Windows `tar.exe` is unavailable,
   because that profile must be included in complete backups.
4. Sign in once with the bootstrap superuser so Apexo can initialize its
   collections. In Apexo's Accounts screen, immediately create a normal user
   with only the permissions needed for daily work. Sign out and use that
   least-privileged account for routine sessions; reserve the superuser for
   administration. If the user must own appointments, explicitly enable that
   normal user's operator/clinician setting (and no broader permissions).
5. If asked about notifications, choose **Not Now**; remote push cannot reach a
   loopback-only USB server.
6. When finished, **first close every dedicated Apexo Edge/Chrome window**.
   Then press Ctrl+C in the **Apexo Server** window. The launcher never
   force-closes the browser or PocketBase and will wait/refuse to back up while
   either still uses the data.
7. Wait for the verified post-session backup. It includes `pb_data` and the
   portable browser profile. Then use Windows **Safely remove hardware**.

Google Calendar authorization is device-sensitive. Its access token is not a
durable part of the portable profile, and Chromium protects some cookies with
the Windows account/device. Expect to sign in, authorize, or reauthorize Google
on each test PC and after restarts or token expiry. Never save the Google or
Apexo password in the browser, enable browser sync/import, or use the dedicated
profile for unrelated browsing.

The dedicated profile keeps Apexo's primary browser storage on the USB, but it
is not a forensic privacy tool: Windows, security software, DNS, paging, and
crash facilities may retain metadata or temporary traces. Use only synthetic
records until the migration rehearsal and restore test are complete. Read
`PORTABLE_USB_BETA.md` before placing any real patient data on the drive.
