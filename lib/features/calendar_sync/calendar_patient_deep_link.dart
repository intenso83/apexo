import 'dart:async';

import 'package:apexo/app/routes.dart';
import 'package:apexo/features/patients/open_patient_panel.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/services/launch.dart';
import 'package:flutter/foundation.dart';

/// Opens a patient panel when Apexo is reached through a Google Calendar
/// event link such as `?openPatient=<patient id>`.
///
/// The identifier is not an authentication token: Apexo still requires the
/// user to be signed in and authorized before the patient can be opened.
class CalendarPatientDeepLink {
  Timer? _retryTimer;
  bool _started = false;
  int _attempts = 0;

  void start() {
    if (!kIsWeb || _started) return;
    final patientId = Uri.base.queryParameters['openPatient']?.trim() ?? '';
    if (patientId.isEmpty) return;
    _started = true;
    _tryOpen(patientId);
    _retryTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      _tryOpen(patientId);
    });
  }

  void _tryOpen(String patientId) {
    _attempts++;
    if (_attempts > 240) {
      _retryTimer?.cancel();
      return;
    }
    if (launch.open() != Open.staff) return;
    final patient = patients.get(patientId);
    if (patient == null) return;

    _retryTimer?.cancel();
    routes.navigate('patients');
    openPatient(patient);
  }
}

final calendarPatientDeepLink = CalendarPatientDeepLink();
