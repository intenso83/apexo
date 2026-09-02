# Dimitrakopoulos patient intake

Standalone Android intake form for patients. This application deliberately has
its own application id and dependency graph; it must not import Apexo UI,
authentication, stores, or the PocketBase SDK.

Run the complete test-mode flow:

```powershell
flutter test
flutter run
```

Without `INTAKE_SERVER_URL`, the form clears its in-memory draft on completion
but does not transmit it. For production build and server deployment details,
see `../docs/PATIENT_INTAKE_ANDROID.md`.
