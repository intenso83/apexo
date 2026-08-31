import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/calendar_sync/google_calendar_connection_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only appointments assigned to the current Apexo user are selected', () {
    final assigned = Appointment.fromJson({
      'id': 'assigned',
      'operatorsIDs': ['doctor-a'],
      'date': 30000000,
    });
    final shared = Appointment.fromJson({
      'id': 'shared',
      'operatorsIDs': ['doctor-b', 'doctor-a'],
      'date': 30000001,
    });
    final otherDoctor = Appointment.fromJson({
      'id': 'other',
      'operatorsIDs': ['doctor-b'],
      'date': 30000002,
    });
    final unassigned = Appointment.fromJson({
      'id': 'unassigned',
      'date': 30000003,
    });

    final result = GoogleCalendarConnectionController.assignedAppointments(
      [assigned, shared, otherDoctor, unassigned],
      'doctor-a',
    );

    expect(result.map((item) => item.id), ['assigned', 'shared']);
  });

  test('an empty Apexo account id never selects appointments', () {
    final appointment = Appointment.fromJson({
      'id': 'assigned',
      'operatorsIDs': [''],
      'date': 30000000,
    });

    expect(
      GoogleCalendarConnectionController.assignedAppointments(
        [appointment],
        '',
      ),
      isEmpty,
    );
  });
}
