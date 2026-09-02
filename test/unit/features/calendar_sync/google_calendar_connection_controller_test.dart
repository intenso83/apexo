import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/calendar_sync/google_calendar_connection_controller.dart';
import 'package:apexo/features/calendar_sync/google_calendar_models.dart';
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

  test('automatic scope includes the whole clinic calendar for admins', () {
    final assigned = Appointment.fromJson({
      'id': 'assigned',
      'operatorsIDs': ['admin'],
      'date': 30000000,
    });
    final otherDoctor = Appointment.fromJson({
      'id': 'other',
      'operatorsIDs': ['doctor-b'],
      'date': 30000001,
    });
    final unassigned = Appointment.fromJson({
      'id': 'unassigned',
      'date': 30000002,
    });

    final result = GoogleCalendarConnectionController.appointmentsForSync(
      [assigned, otherDoctor, unassigned],
      'admin',
      scope: GoogleCalendarAppointmentScope.automatic,
      isAdmin: true,
    );

    expect(result.map((item) => item.id), [
      'assigned',
      'other',
      'unassigned',
    ]);
  });

  test('automatic scope remains assignment-only for a clinician', () {
    final assigned = Appointment.fromJson({
      'id': 'assigned',
      'operatorsIDs': ['doctor-a'],
      'date': 30000000,
    });
    final unassigned = Appointment.fromJson({
      'id': 'unassigned',
      'date': 30000001,
    });

    final result = GoogleCalendarConnectionController.appointmentsForSync(
      [assigned, unassigned],
      'doctor-a',
      scope: GoogleCalendarAppointmentScope.automatic,
      isAdmin: false,
    );

    expect(result.map((item) => item.id), ['assigned']);
  });

  test('explicit all-appointments scope also works for a clinician', () {
    final otherDoctor = Appointment.fromJson({
      'id': 'other',
      'operatorsIDs': ['doctor-b'],
      'date': 30000000,
    });
    final unassigned = Appointment.fromJson({
      'id': 'unassigned',
      'date': 30000001,
    });

    final result = GoogleCalendarConnectionController.appointmentsForSync(
      [otherDoctor, unassigned],
      'doctor-a',
      scope: GoogleCalendarAppointmentScope.allAppointments,
      isAdmin: false,
    );

    expect(result.map((item) => item.id), ['other', 'unassigned']);
  });
}
