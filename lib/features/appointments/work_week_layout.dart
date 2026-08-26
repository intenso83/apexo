/// Pure layout helpers for the desktop work-week appointment calendar.
///
/// Keeping these calculations free of Flutter widgets makes the overlap and
/// time-positioning rules easy to verify without touching patient data.
class WorkWeekInterval<T> {
  final T value;
  final int startMinute;
  final int endMinute;

  const WorkWeekInterval({
    required this.value,
    required this.startMinute,
    required this.endMinute,
  });
}

class WorkWeekPlacement<T> {
  final T value;
  final int startMinute;
  final int endMinute;
  final int lane;
  final int laneCount;

  const WorkWeekPlacement({
    required this.value,
    required this.startMinute,
    required this.endMinute,
    required this.lane,
    required this.laneCount,
  });
}

DateTime startOfWorkWeek(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

DateTime dateAtWorkWeekPosition({
  required DateTime day,
  required double y,
  required double hourHeight,
  int startHour = 8,
  int endHour = 22,
  int snapMinutes = 15,
}) {
  final rawMinutes = startHour * 60 + (y / hourHeight * 60).round();
  final snapped = (rawMinutes / snapMinutes).round() * snapMinutes;
  final latest = endHour * 60 - snapMinutes;
  final minute = snapped.clamp(startHour * 60, latest);
  return DateTime(day.year, day.month, day.day, minute ~/ 60, minute % 60);
}

/// Returns the snapped preview time while an appointment is dragged across
/// the Monday-to-Friday grid. The result always fits inside working hours.
DateTime moveWorkWeekAppointment({
  required DateTime original,
  required DateTime weekStart,
  required double deltaX,
  required double deltaY,
  required double dayWidth,
  required double hourHeight,
  required int durationMinutes,
  int startHour = 8,
  int endHour = 22,
  int snapMinutes = 15,
}) {
  final originalDayIndex = original.weekday - DateTime.monday;
  final dayDelta = dayWidth <= 0 ? 0 : (deltaX / dayWidth).round();
  final dayIndex = (originalDayIndex + dayDelta).clamp(0, 4);

  final minuteDelta = hourHeight <= 0
      ? 0
      : ((deltaY / hourHeight * 60) / snapMinutes).round() * snapMinutes;
  final originalMinute = original.hour * 60 + original.minute;
  final earliest = startHour * 60;
  final latest = (endHour * 60 - durationMinutes.clamp(snapMinutes, 24 * 60))
      .clamp(earliest, endHour * 60 - snapMinutes);
  final minute = (originalMinute + minuteDelta).clamp(earliest, latest);
  final day = weekStart.add(Duration(days: dayIndex));
  return DateTime(day.year, day.month, day.day, minute ~/ 60, minute % 60);
}

/// Returns a quarter-hour duration while the lower edge of an appointment is
/// resized. The appointment cannot end later than the visible working day.
int resizeWorkWeekAppointment({
  required DateTime start,
  required int originalDurationMinutes,
  required double deltaY,
  required double hourHeight,
  int endHour = 22,
  int snapMinutes = 15,
}) {
  final minuteDelta = hourHeight <= 0
      ? 0
      : ((deltaY / hourHeight * 60) / snapMinutes).round() * snapMinutes;
  final startMinute = start.hour * 60 + start.minute;
  final maximum = (endHour * 60 - startMinute).clamp(snapMinutes, 24 * 60);
  return (originalDurationMinutes + minuteDelta).clamp(snapMinutes, maximum);
}

List<WorkWeekPlacement<T>> placeWorkWeekOverlaps<T>(
    Iterable<WorkWeekInterval<T>> intervals) {
  final sorted = intervals.where((i) => i.endMinute > i.startMinute).toList()
    ..sort((a, b) {
      final start = a.startMinute.compareTo(b.startMinute);
      if (start != 0) return start;
      return b.endMinute.compareTo(a.endMinute);
    });

  if (sorted.isEmpty) return const [];

  final placements = <WorkWeekPlacement<T>>[];
  var cluster = <({WorkWeekInterval<T> interval, int lane})>[];
  var clusterEnd = -1;
  var laneEnds = <int>[];

  void finishCluster() {
    if (cluster.isEmpty) return;
    final laneCount = laneEnds.length;
    for (final item in cluster) {
      placements.add(WorkWeekPlacement<T>(
        value: item.interval.value,
        startMinute: item.interval.startMinute,
        endMinute: item.interval.endMinute,
        lane: item.lane,
        laneCount: laneCount,
      ));
    }
    cluster = [];
    laneEnds = [];
    clusterEnd = -1;
  }

  for (final interval in sorted) {
    if (cluster.isNotEmpty && interval.startMinute >= clusterEnd) {
      finishCluster();
    }

    var lane = laneEnds.indexWhere((end) => interval.startMinute >= end);
    if (lane == -1) {
      laneEnds.add(interval.endMinute);
      lane = laneEnds.length - 1;
    } else {
      laneEnds[lane] = interval.endMinute;
    }
    cluster.add((interval: interval, lane: lane));
    if (interval.endMinute > clusterEnd) clusterEnd = interval.endMinute;
  }
  finishCluster();
  return placements;
}
