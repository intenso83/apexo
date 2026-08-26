import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/events_work_week_widget.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget calendar(Appointment appointment, void Function(Appointment) onSet) {
    return FluentApp(
      home: SizedBox(
        width: 1200,
        height: 800,
        child: WorkWeekCalendarView(
          items: [appointment],
          selectedDate: DateTime(2026, 8, 25),
          showPayments: false,
          onSelect: (_) {},
          onSetTime: onSet,
          onAddNew: (_) {},
        ),
      ),
    );
  }

  testWidgets('dragging moves an appointment by day and quarter-hour time',
      (tester) async {
    final appointment = Appointment.fromJson({
      'id': 'drag-me',
      'date': DateTime(2026, 8, 25, 9).millisecondsSinceEpoch / 60000,
      'duration': 30,
    });
    var saves = 0;
    await tester.pumpWidget(calendar(appointment, (_) => saves++));

    final card = find.byKey(const ValueKey('work-week-appointment-drag-me'));
    expect(card, findsOneWidget);
    final gesture = await tester.startGesture(tester.getCenter(card));
    // The default widget-test viewport gives each weekday about 147 px.
    await gesture.moveBy(const Offset(150, 72));
    await gesture.up();
    await tester.pump();

    expect(appointment.date, DateTime(2026, 8, 26, 10));
    expect(saves, 1);
  });

  testWidgets('dragging the lower handle resizes in quarter-hour steps',
      (tester) async {
    final appointment = Appointment.fromJson({
      'id': 'resize-me',
      'date': DateTime(2026, 8, 25, 10).millisecondsSinceEpoch / 60000,
      'duration': 30,
    });
    var saves = 0;
    await tester.pumpWidget(calendar(appointment, (_) => saves++));

    final handle =
        find.byKey(const ValueKey('work-week-appointment-resize-resize-me'));
    expect(handle, findsOneWidget);
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await gesture.moveBy(const Offset(0, 36));
    await gesture.up();
    await tester.pump();

    expect(appointment.duration, 60);
    expect(saves, 1);
  });
}
