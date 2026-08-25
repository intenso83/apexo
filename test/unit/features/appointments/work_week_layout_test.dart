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
        DateTime(2026, 8, 25, 20, 45),
      );
    });
  });
}
