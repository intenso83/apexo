import 'package:apexo/features/patients/patient_model.dart';

import 'google_calendar_models.dart';

class GoogleCalendarContactNotes {
  static const managedByApexo = 'Managed by Apexo.';

  String forPatient(
    Patient? patient,
    GoogleCalendarSyncPreferences preferences, {
    String patientUrl = '',
    String openPatientLabel = 'Open patient in Apexo',
  }) {
    if (patient == null) return managedByApexo;
    final lines = <String>[];
    if (preferences.includePhone &&
        patient.appointmentPhoneNumbers.isNotEmpty) {
      lines.add('Phone: ${patient.appointmentPhoneNumbers.join(' · ')}');
    }
    if (preferences.includeMobile &&
        patient.appointmentMobileNumbers.isNotEmpty) {
      lines.add('Mobile: ${patient.appointmentMobileNumbers.join(' · ')}');
    }
    if (preferences.includeEmail &&
        patient.appointmentEmailAddresses.isNotEmpty) {
      lines.add('Email: ${patient.appointmentEmailAddresses.join(' · ')}');
    }
    if (preferences.includeAddress && patient.appointmentAddress.isNotEmpty) {
      lines.add('Address: ${patient.appointmentAddress}');
    }
    if (patientUrl.isNotEmpty) {
      if (lines.isNotEmpty) lines.add('');
      lines.add('$openPatientLabel: $patientUrl');
    }
    return [...lines, managedByApexo].join('\n');
  }
}
