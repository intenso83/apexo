import 'package:apexo/features/calendar_sync/google_calendar_contact_notes.dart';
import 'package:apexo/features/calendar_sync/google_calendar_models.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const defaults = GoogleCalendarSyncPreferences(
    enabled: true,
    calendarId: 'primary',
    clinicId: 'clinic',
    accountId: 'user',
  );

  test('exports only enabled contact fields and never patient notes', () {
    final patient = Patient.fromJson({
      'title': 'Patient Name',
      'notes': 'Clinical note that must stay in Apexo',
      'address_line': '10 Example Street',
      'city': 'Thessaloniki',
      'contacts': [
        {'type': 'home_phone', 'raw_value': '+30 2310 111111'},
        {'type': 'mobile', 'raw_value': '+30 690 2222222'},
        {'type': 'email', 'raw_value': 'patient@example.test'},
      ],
    });

    final notes = GoogleCalendarContactNotes().forPatient(patient, defaults);

    expect(notes, contains('Phone: +30 2310 111111'));
    expect(notes, contains('Mobile: +30 690 2222222'));
    expect(notes, contains('Email: patient@example.test'));
    expect(notes, isNot(contains('10 Example Street')));
    expect(notes, isNot(contains('Clinical note')));
    expect(notes, endsWith(GoogleCalendarContactNotes.managedByApexo));
  });

  test('address can be explicitly enabled while other fields are disabled', () {
    final patient = Patient.fromJson({
      'address_line': '10 Example Street',
      'city': 'Thessaloniki',
      'contacts': [
        {'type': 'mobile', 'raw_value': '+30 690 2222222'},
      ],
    });
    const preferences = GoogleCalendarSyncPreferences(
      enabled: true,
      calendarId: 'primary',
      clinicId: 'clinic',
      accountId: 'user',
      includePhone: false,
      includeMobile: false,
      includeEmail: false,
      includeAddress: true,
    );

    final notes = GoogleCalendarContactNotes().forPatient(patient, preferences);

    expect(notes, contains('Address: 10 Example Street, Thessaloniki'));
    expect(notes, isNot(contains('+30 690 2222222')));
  });

  test('does not repeat a structured mobile as a legacy phone', () {
    final patient = Patient.fromJson({
      'phone': '+4917699267148',
      'contacts': [
        {'type': 'phone', 'raw_value': '+4917699267148'},
        {'type': 'mobile', 'raw_value': '+4917699267148'},
      ],
    });

    final notes = GoogleCalendarContactNotes().forPatient(patient, defaults);

    expect(notes, isNot(contains('Phone:')));
    expect(notes, contains('Mobile: +4917699267148'));
  });

  test('adds a clickable Apexo patient URL without exposing clinical notes',
      () {
    final patient = Patient.fromJson({
      'title': 'Patient Name',
      'notes': 'Never export this clinical note',
    });

    final notes = GoogleCalendarContactNotes().forPatient(
      patient,
      defaults,
      patientUrl: 'http://127.0.0.1:61110/?openPatient=patient-1',
      openPatientLabel: 'Open patient in Apexo',
    );

    expect(
      notes,
      contains(
        'Open patient in Apexo: '
        'http://127.0.0.1:61110/?openPatient=patient-1',
      ),
    );
    expect(notes, isNot(contains('Never export')));
  });
}
