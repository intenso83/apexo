import 'package:apexo/features/appointments/work_week_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('work-week calendar layout', () {
    test('starts on Monday and keeps the selected calendar week', () {
      expect(startOfWorkWeek(DateTime(2026, 8, 27)), DateTime(2026, 8, 24));
      expect(startOfWorkWeek(DateTime(2026, 8, 30)), DateTime(2026, 8, 24));
      expect(startOfWorkWeek(DateTime(2026, 8, 31)), DateTime(2026, 8, 31));
    });

    test('overlapping appointments receive separate lanes', () {
      final result = placeWorkWeekOverlaps([
        const WorkWeekInterval(
            value: 'long', startMinute: 9 * 60, endMinute: 10 * 60),
        const WorkWeekInterval(
            value: 'overlap', startMinute: 9 * 60 + 15, endMinute: 9 * 60 + 45),
      ]);

      expect(result, hasLength(2));
      expect(result.map((item) => item.lane).toSet(), {0, 1});
      expect(result.every((item) => item.laneCount == 2), isTrue);
    });

    test('a lane is reused after an earlier appointment ends', () {
      final result = placeWorkWeekOverlaps([
        const WorkWeekInterval(
            value: 'first', startMinute: 9 * 60, endMinute: 9 * 60 + 30),
        const WorkWeekInterval(
            value: 'second', startMinute: 9 * 60 + 30, endMinute: 10 * 60),
      ]);

      expect(result.map((item) => item.lane), [0, 0]);
      expect(result.every((item) => item.laneCount == 1), isTrue);
    });

    test('empty-grid clicks snap to quarter hours inside working hours', () {
      final day = DateTime(2026, 8, 25);
      expect(
        dateAtWorkWeekPosition(day: day, y: 91, hourHeight: 72),
        DateTime(2026, 8, 25, 9, 15),
      );
      expect(
        dateAtWorkWeekPosition(day: day, y: 9999, hourHeight: 72),
        DateTime(2026, 8, 25, 21, 45),
      );
    });

    test('dragging snaps time and moves between weekdays', () {
      final moved = moveWorkWeekAppointment(
        original: DateTime(2026, 8, 25, 9),
        weekStart: DateTime(2026, 8, 24),
        deltaX: 220,
        deltaY: 90,
        dayWidth: 200,
        hourHeight: 72,
        durationMinutes: 60,
      );

      expect(moved, DateTime(2026, 8, 26, 10, 15));
    });

    test('dragging stays inside Monday-Friday and 08:00-22:00', () {
      final moved = moveWorkWeekAppointment(
        original: DateTime(2026, 8, 28, 20, 30),
        weekStart: DateTime(2026, 8, 24),
        deltaX: 9999,
        deltaY: 9999,
        dayWidth: 200,
        hourHeight: 72,
        durationMinutes: 60,
      );

      expect(moved, DateTime(2026, 8, 28, 21));
    });

    test('resizing snaps to quarter hours and stops at 22:00', () {
      expect(
        resizeWorkWeekAppointment(
          start: DateTime(2026, 8, 25, 10),
          originalDurationMinutes: 30,
          deltaY: 36,
          hourHeight: 72,
        ),
        60,
      );
      expect(
        resizeWorkWeekAppointment(
          start: DateTime(2026, 8, 25, 21),
          originalDurationMinutes: 30,
          deltaY: 9999,
          hourHeight: 72,
        ),
        60,
      );
    });
  });
}
