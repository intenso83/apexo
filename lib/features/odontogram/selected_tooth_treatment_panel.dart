import 'dart:math' as math;

import 'package:apexo/features/settings/settings_stores.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:fluent_ui/fluent_ui.dart';

import 'odontogram_event_model.dart';
import 'treatment_target.dart';

/// Returns a newest-first snapshot of the events that reference [fdi].
///
/// [OdontogramEvent.referencesTooth] deliberately includes bridge and mapped
/// removable-prosthesis events, so the side panel remains useful for more than
/// simple single-tooth treatments.
List<OdontogramEvent> odontogramEventsForSelectedTooth(
  Iterable<OdontogramEvent> events,
  int fdi,
) {
  final selected = events
      .where((event) => event.referencesTooth(fdi))
      .toList(growable: false);
  selected.sort((a, b) {
    final byDate = b.recordedAt.compareTo(a.recordedAt);
    if (byDate != 0) return byDate;
    return b.id.compareTo(a.id);
  });
  return selected;
}

/// Compact, read-only history for the tooth currently selected in an
/// odontogram.
///
/// The widget does not query a store or duplicate records. It filters the
/// patient events supplied by its parent and bounds both the number of rows and
/// the list height, keeping it suitable for the unused space beside the chart.
class SelectedToothTreatmentPanel extends StatelessWidget {
  const SelectedToothTreatmentPanel({
    super.key,
    required this.selectedFdi,
    required this.events,
    this.maxVisibleEvents,
    this.maxListHeight = 360,
    this.onShowAll,
  })  : assert(maxVisibleEvents == null || maxVisibleEvents > 0),
        assert(maxListHeight > 0);

  final int selectedFdi;
  final Iterable<OdontogramEvent> events;

  /// Optional row cap before the overflow affordance.
  ///
  /// Leave this null to make every matching event available through the
  /// bounded, lazy scroll. Supply a cap only when [onShowAll] offers another
  /// route to the complete history.
  final int? maxVisibleEvents;

  /// Maximum height of the lazily built, independently scrollable row list.
  final double maxListHeight;

  /// Optional navigation to the complete patient timeline.
  final VoidCallback? onShowAll;

  @override
  Widget build(BuildContext context) {
    final selectedEvents = odontogramEventsForSelectedTooth(
      events,
      selectedFdi,
    );
    final visibleCount = maxVisibleEvents == null
        ? selectedEvents.length
        : math.min(selectedEvents.length, maxVisibleEvents!);
    final hiddenCount = selectedEvents.length - visibleCount;
    final listHeight = math.min(
      maxListHeight,
      visibleCount * 152.0 + math.max(0, visibleCount - 1) * 7.0,
    );

    return Container(
      key: const Key('selected-tooth-treatment-panel'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FluentTheme.of(context).cardColor,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: FluentTheme.of(context).resources.cardStrokeColorDefault,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(FluentIcons.history, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${txt('selectedTooth')} $selectedFdi',
                      key: const Key('selected-tooth-treatment-panel-title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FluentTheme.of(context).typography.subtitle,
                    ),
                    Text(
                      txt('toothEventHistory'),
                      style: FluentTheme.of(context).typography.caption,
                    ),
                  ],
                ),
              ),
              if (selectedEvents.isNotEmpty)
                Container(
                  key: const Key('selected-tooth-treatment-count'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: FluentTheme.of(context)
                        .accentColor
                        .withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${selectedEvents.length}',
                    style: FluentTheme.of(context).typography.caption,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (selectedEvents.isEmpty)
            Padding(
              key: const Key('selected-tooth-treatment-empty'),
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                txt('noOdontogramEvents'),
                textAlign: TextAlign.center,
                style: FluentTheme.of(context).typography.body,
              ),
            )
          else
            SizedBox(
              height: listHeight,
              child: ListView.separated(
                key: const Key('selected-tooth-treatment-list'),
                primary: false,
                itemCount: visibleCount,
                separatorBuilder: (_, __) => const SizedBox(height: 7),
                itemBuilder: (context, index) => _SelectedToothEventCard(
                  key: ValueKey(
                    'selected-tooth-event-${selectedEvents[index].id}',
                  ),
                  event: selectedEvents[index],
                  selectedFdi: selectedFdi,
                ),
              ),
            ),
          if (hiddenCount > 0) ...[
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: onShowAll == null
                  ? Text(
                      '+$hiddenCount',
                      key: const Key('selected-tooth-treatment-hidden-count'),
                      style: FluentTheme.of(context).typography.caption,
                    )
                  : HyperlinkButton(
                      key: const Key('selected-tooth-treatment-show-all'),
                      onPressed: onShowAll,
                      child:
                          Text('${txt('showAll')} (${selectedEvents.length})'),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectedToothEventCard extends StatelessWidget {
  const _SelectedToothEventCard({
    super.key,
    required this.event,
    required this.selectedFdi,
  });

  final OdontogramEvent event;
  final int selectedFdi;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(event.status);
    final target = _targetDescription(event, selectedFdi);
    final procedureName = event.procedureNameSnapshot.trim().isEmpty
        ? event.title
        : event.procedureNameSnapshot.trim();

    return Container(
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(width: 4, color: statusColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  procedureName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (event.materialColorArgb != null) ...[
                const SizedBox(width: 7),
                Tooltip(
                  message: txt('colorMap'),
                  child: Container(
                    key: Key('selected-tooth-material-${event.id}'),
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _opaqueColor(event.materialColorArgb!),
                      border: Border.all(
                        color: FluentTheme.of(context)
                            .resources
                            .cardStrokeColorDefault,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${txt('odontogramStatus_${event.status.name}')} · ${DF.allNumbers(event.recordedAt)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FluentTheme.of(context).typography.caption,
          ),
          if (target.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              target,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (event.laboratoryNameSnapshot.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${txt('laboratory')}: ${event.laboratoryNameSnapshot.trim()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FluentTheme.of(context).typography.caption,
            ),
          ],
          if (event.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              event.notes.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: FluentTheme.of(context).typography.caption,
            ),
          ],
        ],
      ),
    );
  }
}

String _targetDescription(OdontogramEvent event, int selectedFdi) {
  return switch (event.targetScope) {
    TreatmentTargetScope.patient => '',
    TreatmentTargetScope.tooth => event.surfaces.isEmpty
        ? txt('surfaceUnspecified')
        : event.surfaces.map(_storedSurfaceLabel).join(', '),
    TreatmentTargetScope.bridge => [
        txt('targetScope_bridge'),
        if (event.bridgeUnits.isEmpty)
          txt('mappingUnspecified')
        else
          ...event.bridgeUnits.map(
            (unit) => '${unit.toothFdi} ${txt('bridgeRole_${unit.role.name}')}',
          ),
      ].join(' · '),
    TreatmentTargetScope.removableProsthesis => [
        txt('targetScope_removableProsthesis'),
        if (event.removableComponents
            .where((component) => component.toothFdi == selectedFdi)
            .isEmpty)
          txt('dentalArch_${event.arch.name}')
        else
          ...event.removableComponents
              .where((component) => component.toothFdi == selectedFdi)
              .map(
                (component) => txt('removableRole_${component.role.name}'),
              ),
      ].join(' · '),
  };
}

String _storedSurfaceLabel(String stored) {
  return switch (stored) {
    'mesial' => txt('surfaceMesial'),
    'distal' => txt('surfaceDistal'),
    'facial' => txt('surfaceFacial'),
    'oral' => txt('surfaceOral'),
    'occlusalIncisal' => txt('surfaceOcclusalIncisal'),
    'wholeTooth' => txt('surfaceWholeTooth'),
    _ => stored,
  };
}

Color _statusColor(OdontogramEventStatus status) {
  return switch (status) {
    OdontogramEventStatus.existing => Colors.purple,
    OdontogramEventStatus.monitor => Colors.orange,
    OdontogramEventStatus.planned => Colors.blue,
    OdontogramEventStatus.completed => Colors.teal,
    OdontogramEventStatus.cancelled => Colors.grey,
  };
}

Color _opaqueColor(int argb) {
  final normalized = argb <= 0xFFFFFF ? 0xFF000000 | argb : argb;
  return Color(normalized);
}
