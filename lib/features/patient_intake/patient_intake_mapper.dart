import 'package:apexo/features/medical_history/medical_history_model.dart';
import 'package:apexo/features/medical_history/medical_history_store.dart';
import 'package:apexo/features/patients/patient_contact.dart';
import 'package:apexo/features/patients/patient_model.dart';

import 'patient_intake_submission.dart';

class PatientIntakeMapper {
  const PatientIntakeMapper._();

  static Patient newPatient(PatientIntakeSubmission submission) {
    final p = submission.personal;
    final birthDate = parsePracticeDate(p['date_of_birth']?.toString());
    final surname = _text(p, 'family_name');
    final firstName = _text(p, 'given_name');
    final mobile = _text(p, 'mobile');
    final phone = _text(p, 'phone');
    final email = _text(p, 'email');
    final address = _text(p, 'address');
    return Patient.fromJson({
      'title':
          [surname, firstName].where((value) => value.isNotEmpty).join(' '),
      'surname': surname,
      'first_name': firstName,
      'patronymic': _text(p, 'father_name'),
      if (birthDate != null) ...{
        'birth': birthDate.year,
        'birth_date': _dateOnly(birthDate),
        'birth_date_precision': 'day',
      },
      'occupation': _text(p, 'occupation'),
      'place_of_origin_or_birth': _text(p, 'country_of_origin'),
      'address': address,
      'address_line': address,
      'postal_code': _text(p, 'postal_code'),
      'city': _text(p, 'city'),
      'amka': _text(p, 'amka'),
      'afm': _text(p, 'afm'),
      'doy': _text(p, 'doy'),
      'insurance': _text(p, 'insurance'),
      'email': email,
      'phone': [mobile, phone].where((value) => value.isNotEmpty).join(' '),
      'contacts': _contacts(mobile: mobile, phone: phone, email: email)
          .map((contact) => contact.toJson())
          .toList(),
      'registration_date': _dateOnly(DateTime.now()),
      'active_status': 'active',
      'legacy_custom_fields': {
        'intake_submission_id': submission.id,
      },
    });
  }

  static void mergeMissingPersonalData(
    Patient patient,
    PatientIntakeSubmission submission,
  ) {
    final incoming = newPatient(submission);
    if (patient.surname.isEmpty) patient.surname = incoming.surname;
    if (patient.firstName.isEmpty) patient.firstName = incoming.firstName;
    if (patient.title.isEmpty) patient.title = incoming.title;
    if (patient.patronymic.isEmpty) patient.patronymic = incoming.patronymic;
    if (patient.birthDate == null && incoming.birthDate != null) {
      patient.birthDate = incoming.birthDate;
      patient.birth = incoming.birth;
      patient.birthDatePrecision = incoming.birthDatePrecision;
    }
    if (patient.occupation.isEmpty) patient.occupation = incoming.occupation;
    if (patient.placeOfOriginOrBirth.isEmpty) {
      patient.placeOfOriginOrBirth = incoming.placeOfOriginOrBirth;
    }
    if (patient.addressLine.isEmpty) patient.addressLine = incoming.addressLine;
    if (patient.address.isEmpty) patient.address = incoming.address;
    if (patient.postalCode.isEmpty) patient.postalCode = incoming.postalCode;
    if (patient.city.isEmpty) patient.city = incoming.city;
    if (patient.amka.isEmpty) patient.amka = incoming.amka;
    if (patient.afm.isEmpty) patient.afm = incoming.afm;
    if (patient.doy.isEmpty) patient.doy = incoming.doy;
    if (patient.insurance.isEmpty) patient.insurance = incoming.insurance;
    if (patient.email.isEmpty) patient.email = incoming.email;

    final knownContacts = patient.contacts
        .map((contact) => _normalizedContact(contact.rawValue))
        .where((value) => value.isNotEmpty)
        .toSet();
    for (final contact in incoming.contacts) {
      if (knownContacts.add(_normalizedContact(contact.rawValue))) {
        patient.contacts.add(contact.copy());
      }
    }
    if (patient.phone.isEmpty && incoming.phone.isNotEmpty) {
      patient.phone = incoming.phone;
    }
    patient.legacyCustomFields['intake_submission_id'] = submission.id;
    patient.nullifyLabels();
  }

  static MedicalHistoryRevision medicalHistory(
    PatientIntakeSubmission submission,
    String patientId,
  ) {
    final history = submission.medicalHistory;
    final rawAnswers = Map<String, dynamic>.from(
      history['answers'] as Map? ?? const {},
    );
    final previous = medicalHistoryRevisions.latestForPatient(patientId);
    return MedicalHistoryRevision.fromJson({
      'patient_id': patientId,
      'questionnaire_version':
          submission.packet['questionnaire_version']?.toString(),
      'revision_number': (previous?.revisionNumber ?? 0) + 1,
      if (previous != null) 'previous_revision_id': previous.id,
      'source': MedicalHistorySource.tablet,
      'status': MedicalHistoryStatus.confirmed,
      'language_code': submission.packet['language_code']?.toString() ?? 'el',
      'created_at':
          (submission.receivedAt ?? DateTime.now().toUtc()).toIso8601String(),
      'submitted_at': submission.packet['submitted_at']?.toString() ??
          submission.receivedAt?.toIso8601String(),
      'patient_confirmed': submission.packet['patient_confirmed'] == true,
      'signature': Map<String, dynamic>.from(
        submission.packet['signature'] as Map? ?? const {},
      ),
      'reason_for_visit': history['reason_for_visit'],
      'present_condition': history['present_condition'],
      'treating_physician': history['treating_physician'],
      'diseases_surgeries': history['diseases_surgeries'],
      'general_notes': history['general_notes'],
      'answers': rawAnswers,
      'provenance': {
        'intake_submission_id': submission.id,
        'source_application': 'com.edimitrakopoulos.intake',
      },
    });
  }

  static List<Patient> likelyMatches(
    PatientIntakeSubmission submission,
    Iterable<Patient> candidates,
  ) {
    final p = submission.personal;
    final amka = _normalizedContact(_text(p, 'amka'));
    final afm = _normalizedContact(_text(p, 'afm'));
    final email = _normalizedContact(_text(p, 'email'));
    final phones = {
      _normalizedContact(_text(p, 'mobile')),
      _normalizedContact(_text(p, 'phone')),
    }..remove('');
    final surname = _normalizedName(_text(p, 'family_name'));
    final firstName = _normalizedName(_text(p, 'given_name'));
    final birth = parsePracticeDate(_text(p, 'date_of_birth'));

    final scored = <(Patient, int)>[];
    for (final patient in candidates) {
      var score = 0;
      if (amka.isNotEmpty && _normalizedContact(patient.amka) == amka) {
        score = 100;
      } else if (afm.isNotEmpty && _normalizedContact(patient.afm) == afm) {
        score = 95;
      }
      final patientContacts = patient.prototypeContacts
          .map((contact) => _normalizedContact(contact.rawValue))
          .toSet();
      if (email.isNotEmpty && patientContacts.contains(email)) score += 70;
      if (phones.any(patientContacts.contains)) score += 60;
      final sameName = surname.isNotEmpty &&
          firstName.isNotEmpty &&
          _normalizedName(patient.surname) == surname &&
          _normalizedName(patient.firstName) == firstName;
      if (sameName) score += 35;
      if (birth != null &&
          patient.birthDate != null &&
          _dateOnly(patient.birthDate!) == _dateOnly(birth)) {
        score += 25;
      }
      if (score > 0) scored.add((patient, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.map((entry) => entry.$1).toList(growable: false);
  }

  static DateTime? parsePracticeDate(String? input) {
    final value = input?.trim() ?? '';
    if (value.isEmpty) return null;
    final iso = DateTime.tryParse(value);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);
    final parts = value.split(RegExp(r'[/.-]'));
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  static String _text(Map<String, dynamic> values, String key) =>
      values[key]?.toString().trim() ?? '';

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static String _normalizedName(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String _normalizedContact(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9@.+]'), '');

  static List<PatientContact> _contacts({
    required String mobile,
    required String phone,
    required String email,
  }) {
    return [
      if (mobile.isNotEmpty)
        PatientContact.fromJson({
          'type': PatientContactType.mobile,
          'raw_value': mobile,
          'normalized_value': _normalizedContact(mobile),
          'is_primary': true,
        }),
      if (phone.isNotEmpty)
        PatientContact.fromJson({
          'type': PatientContactType.phone,
          'raw_value': phone,
          'normalized_value': _normalizedContact(phone),
        }),
      if (email.isNotEmpty)
        PatientContact.fromJson({
          'type': PatientContactType.email,
          'raw_value': email,
          'normalized_value': email.toLowerCase(),
        }),
    ];
  }
}
