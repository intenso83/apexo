import 'dart:async';
import 'dart:math';

import 'package:apexo/common_widgets/teeth_selector/tx_options.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/work_week_layout.dart';
import 'package:apexo/features/settings/settings_stores.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/utils/colors_without_yellow.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';

/// A five-day clinical calendar for desktop use.
///
/// Appointments can be moved across the week and resized in 15-minute steps.
class WorkWeekCalendarView extends StatefulWidget {
  final List<Appointment> items;
  final DateTime selectedDate;
  final bool showPayments;
  final void Function(Appointment item) onSelect;
  final void Function(Appointment item) onSetTime;
  final void Function(DateTime date) onAddNew;

  const WorkWeekCalendarView({
    super.key,
    required this.items,
    required this.selectedDate,
    required this.showPayments,
    required this.onSelect,
    required this.onSetTime,
    required this.onAddNew,
  });

  @override
  State<WorkWeekCalendarView> createState() => _WorkWeekCalendarViewState();
}

class _WorkWeekCalendarViewState extends State<WorkWeekCalendarView> {
  static const _startHour = 8;
  static const _endHour = 22;
  static const _hourHeight = 72.0;
  static const _timeGutterWidth = 66.0;
  static const _dayHeaderHeight = 54.0;
  static const _minimumCardHeight = 24.0;

  final _scrollController = ScrollController();
  Timer? _clockTimer;
  Appointment? _movingItem;
  DateTime? _moveOriginalDate;
  DateTime? _movePreviewDate;
  Offset _moveDelta = Offset.zero;
  double _moveDayWidth = 0;
  Appointment? _resizingItem;
  int? _resizeOriginalDuration;
  int? _resizePreviewDuration;
  double _resizeDeltaY = 0;

  double get _gridHeight => (_endHour - _startHour) * _hourHeight;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _displayDate(Appointment item) => identical(item, _movingItem)
      ? (_movePreviewDate ?? item.date)
      : item.date;

  int _displayDuration(Appointment item) => identical(item, _resizingItem)
      ? (_resizePreviewDuration ?? item.duration)
      : item.duration;

  void _startMoving(Appointment item, double dayWidth) {
    setState(() {
      _movingItem = item;
      _moveOriginalDate = item.date;
      _movePreviewDate = item.date;
      _moveDelta = Offset.zero;
      _moveDayWidth = dayWidth;
    });
  }

  void _updateMoving(Offset delta) {
    if (_movingItem == null || _moveOriginalDate == null) return;
    setState(() {
      _moveDelta += delta;
      _movePreviewDate = moveWorkWeekAppointment(
        original: _moveOriginalDate!,
        weekStart: startOfWorkWeek(widget.selectedDate),
        deltaX: _moveDelta.dx,
        deltaY: _moveDelta.dy,
        dayWidth: _moveDayWidth,
        hourHeight: _hourHeight,
        durationMinutes: _displayDuration(_movingItem!),
        startHour: _startHour,
        endHour: _endHour,
      );
    });
  }

  void _finishMoving() {
    final item = _movingItem;
    final preview = _movePreviewDate;
    final changed = item != null &&
        preview != null &&
        preview.millisecondsSinceEpoch != item.date.millisecondsSinceEpoch;
    setState(() {
      _movingItem = null;
      _moveOriginalDate = null;
      _movePreviewDate = null;
      _moveDelta = Offset.zero;
    });
    if (changed) {
      item.date = preview;
      widget.onSetTime(item);
    }
  }

  void _startResizing(Appointment item) {
    setState(() {
      _resizingItem = item;
      _resizeOriginalDuration = item.duration;
      _resizePreviewDuration = item.duration;
      _resizeDeltaY = 0;
    });
  }

  void _updateResizing(double deltaY) {
    if (_resizingItem == null || _resizeOriginalDuration == null) return;
    setState(() {
      _resizeDeltaY += deltaY;
      _resizePreviewDuration = resizeWorkWeekAppointment(
        start: _displayDate(_resizingItem!),
        originalDurationMinutes: _resizeOriginalDuration!,
        deltaY: _resizeDeltaY,
        hourHeight: _hourHeight,
        endHour: _endHour,
      );
    });
  }

  void _finishResizing() {
    final item = _resizingItem;
    final preview = _resizePreviewDuration;
    final changed = item != null && preview != null && preview != item.duration;
    setState(() {
      _resizingItem = null;
      _resizeOriginalDuration = null;
      _resizePreviewDuration = null;
      _resizeDeltaY = 0;
    });
    if (changed) {
      item.duration = preview;
      widget.onSetTime(item);
    }
  }

  Color _appointmentColor(Appointment appointment) {
    if (appointment.isDone) return Colors.green;
    if (appointment.isMissed) return Colors.red;
    if (appointment.therapyGroup.isNotEmpty) {
      return labelToColor(appointment.therapyGroup);
    }
    if (appointment.operatorsIDs.isEmpty) return Colors.blue;
    final operatorId = appointment.operatorsIDs.first;
    return colorsWithoutYellow[
        operatorId.hashCode.abs() % colorsWithoutYellow.length];
  }

  String _appointmentTime(Appointment appointment) {
    final start = _displayDate(appointment);
    final end = start.add(Duration(minutes: _displayDuration(appointment)));
    final format = DateFormat('HH:mm', locale.s.$code);
    return '${format.format(start)}–${format.format(end)}';
  }

  String _daySubtitle(DateTime day) {
    if (localSettings.calendarSystem == 'persian') {
      return DF.jalaliDate(day);
    }
    return DateFormat('dd/MM', locale.s.$code).format(day);
  }

  @override
  Widget build(BuildContext context) {
    final weekStart = startOfWorkWeek(widget.selectedDate);
    final days =
        List.generate(5, (index) => weekStart.add(Duration(days: index)));
    final now = DateTime.now();
    final theme = FluentTheme.of(context);

    return LayoutBuilder(builder: (context, constraints) {
      final dayWidth =
          max(120.0, (constraints.maxWidth - _timeGutterWidth) / days.length);
      final canvasWidth = _timeGutterWidth + dayWidth * days.length;

      return Column(
        children: [
          SizedBox(
            height: _dayHeaderHeight,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: SizedBox(
                width: canvasWidth,
                child: Row(
                  children: [
                    const SizedBox(
                      width: _timeGutterWidth,
                      child: Center(
                        child: Icon(FluentIcons.clock, size: 16),
                      ),
                    ),
                    ...days.map((day) {
                      final isToday = _isSameDay(day, now);
                      final count = widget.items
                          .where((item) => _isSameDay(item.date, day))
                          .length;
                      return Container(
                        width: dayWidth,
                        decoration: BoxDecoration(
                          color: isToday
                              ? theme.accentColor.withValues(alpha: 0.09)
                              : null,
                          border: Border(
                            left: BorderSide(
                              color: theme.resources.dividerStrokeColorDefault,
                            ),
                            bottom: BorderSide(
                              color: theme.resources.dividerStrokeColorDefault,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  DF.jalaliDayOfWeekAbbr(day),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  _daySubtitle(day),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.inactiveColor,
                                  ),
                                ),
                              ],
                            ),
                            if (count > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      theme.accentColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text('$count',
                                    style: const TextStyle(fontSize: 11)),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: SizedBox(
                  width: canvasWidth,
                  height: _gridHeight,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      ..._buildDayBackgrounds(days, dayWidth, theme, now),
                      ..._buildGridLines(canvasWidth, theme),
                      ..._buildEmptySlotTargets(days, dayWidth),
                      ..._buildAppointmentCards(days, dayWidth, theme),
                      ..._buildCurrentTimeLine(days, dayWidth, now),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  List<Widget> _buildDayBackgrounds(List<DateTime> days, double dayWidth,
      FluentThemeData theme, DateTime now) {
    return [
      for (var index = 0; index < days.length; index++)
        Positioned(
          left: _timeGutterWidth + dayWidth * index,
          top: 0,
          width: dayWidth,
          height: _gridHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _isSameDay(days[index], now)
                  ? theme.accentColor.withValues(alpha: 0.035)
                  : index.isOdd
                      ? (theme.brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.018)
                          : Colors.black.withValues(alpha: 0.018))
                      : theme.resources.solidBackgroundFillColorBase,
              border: Border(
                left: BorderSide(
                  color: theme.resources.dividerStrokeColorDefault,
                ),
              ),
            ),
          ),
        ),
    ];
  }

  List<Widget> _buildGridLines(double canvasWidth, FluentThemeData theme) {
    final widgets = <Widget>[];
    for (var halfHour = 0;
        halfHour <= (_endHour - _startHour) * 2;
        halfHour++) {
      final y = halfHour * _hourHeight / 2;
      final isHour = halfHour.isEven;
      widgets.add(Positioned(
        left: _timeGutterWidth,
        top: y,
        width: canvasWidth - _timeGutterWidth,
        child: Container(
          height: 1,
          color: theme.resources.dividerStrokeColorDefault
              .withValues(alpha: isHour ? 0.8 : 0.35),
        ),
      ));
      if (isHour && halfHour < (_endHour - _startHour) * 2) {
        final hour = _startHour + halfHour ~/ 2;
        widgets.add(Positioned(
          left: 4,
          top: max(0, y - 9),
          width: _timeGutterWidth - 10,
          child: Text(
            '${hour.toString().padLeft(2, '0')}:00',
            textAlign: TextAlign.end,
            style: TextStyle(fontSize: 11, color: theme.inactiveColor),
          ),
        ));
      }
    }
    return widgets;
  }

  List<Widget> _buildEmptySlotTargets(List<DateTime> days, double dayWidth) {
    return [
      for (var index = 0; index < days.length; index++)
        Positioned(
          left: _timeGutterWidth + dayWidth * index,
          top: 0,
          width: dayWidth,
          height: _gridHeight,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: (details) => widget.onAddNew(dateAtWorkWeekPosition(
              day: days[index],
              y: details.localPosition.dy,
              hourHeight: _hourHeight,
              startHour: _startHour,
              endHour: _endHour,
            )),
          ),
        ),
    ];
  }

  List<Widget> _buildAppointmentCards(
      List<DateTime> days, double dayWidth, FluentThemeData theme) {
    final widgets = <Widget>[];
    const rangeStart = _startHour * 60;
    const rangeEnd = _endHour * 60;

    for (var dayIndex = 0; dayIndex < days.length; dayIndex++) {
      final dayAppointments = widget.items
          .where((appointment) =>
              _isSameDay(_displayDate(appointment), days[dayIndex]))
          .where((appointment) {
        final date = _displayDate(appointment);
        final start = date.hour * 60 + date.minute;
        return start < rangeEnd &&
            start + _displayDuration(appointment) > rangeStart;
      });

      final placements = placeWorkWeekOverlaps(dayAppointments.map((item) {
        final date = _displayDate(item);
        final start = date.hour * 60 + date.minute;
        return WorkWeekInterval(
          value: item,
          startMinute: max(start, rangeStart),
          endMinute: min(start + max(15, _displayDuration(item)), rangeEnd),
        );
      }));

      for (final placement in placements) {
        final item = placement.value;
        final laneWidth = dayWidth / placement.laneCount;
        final color = _appointmentColor(item);
        final top = (placement.startMinute - rangeStart) / 60 * _hourHeight;
        final durationHeight =
            (placement.endMinute - placement.startMinute) / 60 * _hourHeight;
        final height = max(_minimumCardHeight, durationHeight - 2);
        final left = _timeGutterWidth +
            dayIndex * dayWidth +
            placement.lane * laneWidth +
            2;

        widgets.add(Positioned(
          left: left,
          top: top + 1,
          width: max(24, laneWidth - 4),
          height: height,
          child: Tooltip(
            message:
                '${item.title}\n${_appointmentTime(item)}\n${item.subtitleLine1}',
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(7, 4, 5, 6),
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      theme.resources.solidBackgroundFillColorBase,
                      color,
                      identical(item, _movingItem) ||
                              identical(item, _resizingItem)
                          ? 0.34
                          : 0.20,
                    ),
                    borderRadius: BorderRadius.circular(5),
                    border: Border(left: BorderSide(color: color, width: 4)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                            alpha: identical(item, _movingItem) ? 0.20 : 0.08),
                        blurRadius: identical(item, _movingItem) ? 8 : 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: ClipRect(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title.trim().isEmpty
                              ? txt('appointment')
                              : item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        if (height >= 38)
                          Text(
                            _appointmentTime(item),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 10, color: theme.inactiveColor),
                          ),
                        if (height >= 56 &&
                            item.subtitleLine1.trim().isNotEmpty)
                          Text(
                            item.subtitleLine1,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10),
                          ),
                        if (height >= 74 && widget.showPayments)
                          Text(
                            '${item.paid.toStringAsFixed(2)} / ${item.price.toStringAsFixed(2)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10),
                          ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  bottom: min(9, height),
                  child: MouseRegion(
                    cursor: identical(item, _movingItem)
                        ? SystemMouseCursors.grabbing
                        : SystemMouseCursors.move,
                    child: Listener(
                      key: ValueKey('work-week-appointment-${item.id}'),
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (_) => _startMoving(item, dayWidth),
                      onPointerMove: (event) => _updateMoving(event.delta),
                      onPointerUp: (_) => _finishMoving(),
                      onPointerCancel: (_) => _finishMoving(),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => widget.onSelect(item),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  right: 4,
                  bottom: 0,
                  height: min(9, height),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeUpDown,
                    child: Listener(
                      key: ValueKey('work-week-appointment-resize-${item.id}'),
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (_) => _startResizing(item),
                      onPointerMove: (event) => _updateResizing(event.delta.dy),
                      onPointerUp: (_) => _finishResizing(),
                      onPointerCancel: (_) => _finishResizing(),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ));
      }
    }
    return widgets;
  }

  List<Widget> _buildCurrentTimeLine(
      List<DateTime> days, double dayWidth, DateTime now) {
    final dayIndex = days.indexWhere((day) => _isSameDay(day, now));
    final minute = now.hour * 60 + now.minute;
    if (dayIndex == -1 || minute < _startHour * 60 || minute > _endHour * 60) {
      return const [];
    }
    final top = (minute - _startHour * 60) / 60 * _hourHeight;
    return [
      Positioned(
        left: _timeGutterWidth + dayIndex * dayWidth,
        top: top,
        width: dayWidth,
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFE53E3E),
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
                child: Container(height: 2, color: const Color(0xFFE53E3E))),
          ],
        ),
      ),
    ];
  }
}
