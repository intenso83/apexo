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

  test('Google-only opaque events become busy blocks, managed events do not',
      () {
    final blocks = GoogleCalendarConnectionController.busyBlocksFromEvents([
      GoogleCalendarEvent(
        id: 'external-busy',
        status: 'confirmed',
        summary: 'Practice administration',
        description: '',
        start: DateTime(2026, 9, 2, 10),
        end: DateTime(2026, 9, 2, 11),
        htmlLink: 'https://calendar.google.com/event/external-busy',
      ),
      GoogleCalendarEvent(
        id: 'external-free',
        status: 'confirmed',
        summary: 'Available',
        description: '',
        start: DateTime(2026, 9, 2, 12),
        end: DateTime(2026, 9, 2, 13),
        transparency: 'transparent',
      ),
      GoogleCalendarEvent(
        id: 'managed',
        status: 'confirmed',
        summary: 'Dental appointment',
        description: '',
        start: DateTime(2026, 9, 2, 14),
        end: DateTime(2026, 9, 2, 15),
        privateProperties: const {'apexoManaged': '1'},
      ),
    ]);

    expect(blocks, hasLength(1));
    expect(blocks.single.id, 'external-busy');
    expect(blocks.single.title, 'Practice administration');
    expect(blocks.single.durationMinutes, 60);
  });
}
