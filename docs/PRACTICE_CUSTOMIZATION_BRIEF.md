# Practice customization brief

## Purpose and scope

This fork will adapt Apexo, rather than replace it, into a dependable self-hosted
dental practice system for a multi-room private practice in Thessaloniki. The
practice must control its database and clinical files, ordinary work must continue
without an Internet connection, and the fork should remain straightforward to
rebase on upstream Apexo. Greek and English are first-class interface languages.
Greek tax reporting, AADE, electronic invoicing, and myDATA are explicitly out of
scope; internal estimates, charges, payments, and balances remain in scope.

## Product priorities

In descending order: protect patient data; prevent loss or corruption; support
reliable daily clinical work; preserve legacy information; make frequent desktop
workflows efficient; keep the fork maintainable; improve presentation; then add
experimental features.

The staff experience should be a dense, clear desktop working tool with fast
patient search and a persistent patient context. Tablet layouts are primarily for
patient demographics, medical/dental history, consent, and signatures. Patient
submissions must enter a review queue rather than silently overwriting the record.

Longer-term clinical scope includes demographics, alerts, histories, chronological
notes, appointments, FDI dental charting, diagnoses, planned and completed work,
implant workflows, treatment plans, fees/payments, and controlled documents. Large
clinical files should normally live in application-controlled file/object storage
with database metadata, integrity hashes, and authorization checks, rather than as
large JSON/database blobs.

## Privacy and operational constraints

- Never commit real patient data, DentalWin databases/backups, credentials, keys,
  clinical files, identifiable screenshots, or sensitive logs. Tests use synthetic
  identities only.
- No patient data may be sent to cloud OCR or other third-party services without
  explicit approval. Core operation must not depend on a paid/proprietary API.
- Production services stay on the private network or behind deliberately configured
  HTTPS access; the database is never exposed directly to the public Internet.
- Use individual authentication, least-privilege roles, an audit trail for important
  changes, secure sessions/passwords, controlled file access, and tested encrypted
  backups. Self-hosting alone is not a claim of GDPR compliance.
- Keep application code, configuration/secrets, database files, uploaded documents,
  and backups separate. Document and test both backup and restore.
- Preserve GPL-3.0 licensing and upstream attribution. Keep changes modular, avoid
  unrelated rewrites, add migrations rather than editing released migrations, and
  retain Greek and English strings for new behavior.

## Migration and OCR safety contract

DentalWin `.mdb` sources are always read-only and all experiments use copies. Before
a real import, analyze the supplied sanitized schema, document every source-to-target
mapping and ambiguity, extract to an inspectable intermediate format, validate, dry
run with synthetic/sanitized data, and reconcile counts and relationships in a test
database.

Every import has an immutable batch ID and preserves source IDs in a mapping table.
It is transactional, repeatable/idempotent, additive across batches, and produces a
redacted report of accepted/rejected rows, warnings, and possible duplicates.
Possible duplicates require human review and are never automatically merged.
Absence from a later source never deletes an Apexo record. Critical failures stop
safely, and rollback/recovery is documented. Greek text and European dates require
explicit validation; registration dates must not be inferred from treatment or file
dates.

Paper intake follows scan -> local OCR -> XLSX human review -> validation -> approved
import. CSV may be an interchange option, but reviewed XLSX is accepted directly.
Later OCR batches must not erase earlier approved facts.

## Definition of done

Where applicable, work includes validated implementation, error handling, automated
tests, a forward database migration and recovery plan, Greek and English strings,
permission/privacy review, documentation, proof that existing data is retained, and
exact manual verification steps. No feature is complete merely because its screen
renders.
