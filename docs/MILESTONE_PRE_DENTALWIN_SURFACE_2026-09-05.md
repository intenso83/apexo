# SAVE: pre-DentalWin surface migration

Date: 2026-09-05

Git tag: `milestone/pre-dentalwin-surface-migration-2026-09-05`

This is the recovery point immediately before any implementation of the
DentalWin surface-rendering and surface-migration plan documented in
`DENTALWIN_SURFACE_MIGRATION_HANDOFF.md`.

The checkpoint includes the current Apexo source, tests, documentation, local
development tooling, shopping list, treatment/laboratory refinements, expense
item catalogue work, and the existing odontogram/treatment-planning beta.

It deliberately does not include generated build output, temporary files,
PocketBase runtime data, credentials, or patient data. Those are either
rebuildable or require a separate protected database backup.

No DentalWin surface schema, rendering-mask, staging, importer, asset, or
database implementation described by the handoff has begun at this point.

To create a separate recovery branch from this exact source state:

```powershell
git switch -c recovery/pre-dentalwin-surface-migration milestone/pre-dentalwin-surface-migration-2026-09-05
```

To inspect it without changing the current branch:

```powershell
git show milestone/pre-dentalwin-surface-migration-2026-09-05
```
