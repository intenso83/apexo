import 'package:apexo/common_widgets/button_styles.dart';
import 'package:apexo/core/multi_stream_builder.dart';
import 'package:apexo/features/settings/settings_stores.dart';
import 'package:apexo/features/therapy_catalog/procedure_catalog_model.dart';
import 'package:apexo/features/therapy_catalog/therapy_catalog_store.dart';
import 'package:apexo/features/therapy_catalog/therapy_group_model.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/services/login.dart';
import 'package:apexo/services/perm.dart';
import 'package:fluent_ui/fluent_ui.dart';

import 'odontogram_assets.dart';
import 'odontogram_event_model.dart';
import 'odontogram_event_store.dart';

class PatientOdontogram extends StatefulWidget {
  const PatientOdontogram({
    super.key,
    required this.patientID,
  });

  final String patientID;

  @override
  State<PatientOdontogram> createState() => _PatientOdontogramState();
}

class _PatientOdontogramState extends State<PatientOdontogram> {
  int selectedFdi = 11;
  final selectedSurfaces = <DentalSurface>{};
  String selectedGroupID = '';
  String selectedProcedureID = '';
  OdontogramEventStatus selectedStatus = OdontogramEventStatus.planned;
  final notesController = TextEditingController();

  bool get canEdit => login.isAdmin || login.perm(Perm.patients).full;

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MStreamBuilder(
      streams: [
        odontogramEvents.observableMap.stream,
        therapyGroups.observableMap.stream,
        procedureCatalog.observableMap.stream,
      ],
      builder: (context, _) {
        final groups = therapyGroups.ordered
            .where((group) => !group.hidden)
            .toList(growable: false);
        if (!groups.any((group) => group.id == selectedGroupID)) {
          selectedGroupID = groups.firstOrNull?.id ?? '';
          selectedProcedureID = '';
        }
        final procedures = procedureCatalog
            .forGroup(selectedGroupID)
            .where((item) => !item.hidden)
            .toList(growable: false);
        if (!procedures.any((item) => item.id == selectedProcedureID)) {
          selectedProcedureID = procedures.firstOrNull?.id ?? '';
        }
        final events = odontogramEvents.forPatient(widget.patientID);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InfoBar(
              title: Text(txt('odontogramFoundation')),
              content: Text(txt('odontogramFoundationDescription')),
              severity: InfoBarSeverity.info,
            ),
            const SizedBox(height: 12),
            _OdontogramChart(
              selectedFdi: selectedFdi,
              events: events,
              onSelected: (fdi) => setState(() {
                selectedFdi = fdi;
                selectedSurfaces.clear();
              }),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final composer = _buildComposer(groups, procedures);
                final timeline = _EventTimeline(
                  events: events
                      .where((event) => event.toothFdi == selectedFdi)
                      .toList(),
                );
                if (constraints.maxWidth >= 820) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: composer),
                      const SizedBox(width: 12),
                      Expanded(child: timeline),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [composer, const SizedBox(height: 12), timeline],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildComposer(
    List<TherapyGroup> groups,
    List<ProcedureCatalogItem> procedures,
  ) {
    final selectedGroup = therapyGroups.get(selectedGroupID);
    final selectedProcedure = procedureCatalog.get(selectedProcedureID);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${txt('tooth')} $selectedFdi',
            style: FluentTheme.of(context).typography.subtitle,
          ),
          const SizedBox(height: 10),
          Text(txt('toothSurfaces')),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: DentalSurface.values.map((surface) {
              return ToggleButton(
                checked: selectedSurfaces.contains(surface),
                onChanged: canEdit
                    ? (selected) => setState(() {
                          if (surface == DentalSurface.wholeTooth && selected) {
                            selectedSurfaces
                              ..clear()
                              ..add(surface);
                          } else {
                            selectedSurfaces.remove(DentalSurface.wholeTooth);
                            if (selected) {
                              selectedSurfaces.add(surface);
                            } else {
                              selectedSurfaces.remove(surface);
                            }
                          }
                        })
                    : null,
                child: Text(_surfaceText(surface, selectedFdi)),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          InfoLabel(
            label: txt('therapyGroups'),
            child: ComboBox<String>(
              value: selectedGroupID.isEmpty ? null : selectedGroupID,
              isExpanded: true,
              items: groups
                  .map(
                    (group) => ComboBoxItem(
                      value: group.id,
                      child: Text(group.title),
                    ),
                  )
                  .toList(),
              onChanged: canEdit
                  ? (value) => setState(() {
                        selectedGroupID = value ?? '';
                        selectedProcedureID = '';
                      })
                  : null,
            ),
          ),
          const SizedBox(height: 9),
          InfoLabel(
            label: txt('procedureName'),
            child: ComboBox<String>(
              value: selectedProcedureID.isEmpty ? null : selectedProcedureID,
              isExpanded: true,
              items: procedures
                  .map(
                    (procedure) => ComboBoxItem(
                      value: procedure.id,
                      child: Text(procedure.title),
                    ),
                  )
                  .toList(),
              onChanged: canEdit
                  ? (value) => setState(() {
                        selectedProcedureID = value ?? '';
                      })
                  : null,
            ),
          ),
          if (groups.isEmpty) ...[
            const SizedBox(height: 8),
            InfoBar(
              title: Text(txt('catalogueRequiredFirst')),
              severity: InfoBarSeverity.warning,
            ),
          ],
          const SizedBox(height: 9),
          InfoLabel(
            label: txt('clinicalStatus'),
            child: ComboBox<OdontogramEventStatus>(
              value: selectedStatus,
              isExpanded: true,
              items: OdontogramEventStatus.values
                  .map(
                    (status) => ComboBoxItem(
                      value: status,
                      child: Text(txt('odontogramStatus_${status.name}')),
                    ),
                  )
                  .toList(),
              onChanged: canEdit
                  ? (value) => setState(() {
                        selectedStatus = value ?? selectedStatus;
                      })
                  : null,
            ),
          ),
          const SizedBox(height: 9),
          InfoLabel(
            label: txt('notes'),
            child: TextBox(
              controller: notesController,
              maxLines: 3,
              enabled: canEdit,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: canEdit &&
                    selectedGroup != null &&
                    selectedProcedure != null &&
                    selectedSurfaces.isNotEmpty
                ? () => _recordEvent(selectedGroup, selectedProcedure)
                : null,
            child: ButtonContent(
              FluentIcons.add_event,
              txt('recordOdontogramEvent'),
            ),
          ),
        ],
      ),
    );
  }

  String _surfaceText(DentalSurface surface, int fdi) {
    final fallback = OdontogramAssets.surfaceLabel(surface, fdi);
    final key = switch (surface) {
      DentalSurface.mesial => 'surfaceMesial',
      DentalSurface.distal => 'surfaceDistal',
      DentalSurface.facial => 'surfaceFacial',
      DentalSurface.oral =>
        fdi ~/ 10 <= 2 ? 'surfacePalatal' : 'surfaceLingual',
      DentalSurface.occlusalIncisal =>
        fallback == 'Incisal' ? 'surfaceIncisal' : 'surfaceOcclusal',
      DentalSurface.wholeTooth => 'surfaceWholeTooth',
    };
    return txt(key);
  }

  void _recordEvent(
    TherapyGroup group,
    ProcedureCatalogItem procedure,
  ) {
    final event = OdontogramEvent.fromJson({
      'patientID': widget.patientID,
      'toothFdi': selectedFdi,
      'surfaces': selectedSurfaces.map((surface) => surface.name).toList(),
      'procedureID': procedure.id,
      'procedureNameSnapshot': procedure.title,
      'therapyGroupID': group.id,
      'therapyGroupNameSnapshot': group.title,
      'priceSnapshot': procedure.basePrice,
      'eventKind': OdontogramEventKind.treatment.name,
      'status': selectedStatus.name,
      'recordedAt': (DateTime.now().millisecondsSinceEpoch / 60000).round(),
      'notes': notesController.text.trim(),
    });
    odontogramEvents.set(event);
    setState(() {
      selectedSurfaces.clear();
      notesController.clear();
    });
  }
}

class _OdontogramChart extends StatelessWidget {
  const _OdontogramChart({
    required this.selectedFdi,
    required this.events,
    required this.onSelected,
  });

  final int selectedFdi;
  final List<OdontogramEvent> events;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(context),
      padding: const EdgeInsets.all(10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _JawRow(
              fdiNumbers: OdontogramAssets.upperFdi,
              selectedFdi: selectedFdi,
              events: events,
              onSelected: onSelected,
            ),
            const SizedBox(height: 12),
            Container(height: 1, width: 960, color: Colors.grey[40]),
            const SizedBox(height: 12),
            _JawRow(
              fdiNumbers: OdontogramAssets.lowerFdi,
              selectedFdi: selectedFdi,
              events: events,
              onSelected: onSelected,
            ),
          ],
        ),
      ),
    );
  }
}

class _JawRow extends StatelessWidget {
  const _JawRow({
    required this.fdiNumbers,
    required this.selectedFdi,
    required this.events,
    required this.onSelected,
  });

  final List<int> fdiNumbers;
  final int selectedFdi;
  final List<OdontogramEvent> events;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: fdiNumbers.map((fdi) {
        final toothEvents = events.where((event) => event.toothFdi == fdi);
        final latest = toothEvents.firstOrNull;
        return _ToothColumn(
          fdi: fdi,
          selected: fdi == selectedFdi,
          eventCount: toothEvents.length,
          latestStatus: latest?.status,
          onPressed: () => onSelected(fdi),
        );
      }).toList(),
    );
  }
}

class _ToothColumn extends StatelessWidget {
  const _ToothColumn({
    required this.fdi,
    required this.selected,
    required this.eventCount,
    required this.latestStatus,
    required this.onPressed,
  });

  final int fdi;
  final bool selected;
  final int eventCount;
  final OdontogramEventStatus? latestStatus;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = FluentTheme.of(context).accentColor;
    return Semantics(
      label: '${txt('tooth')} $fdi',
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 58,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.10) : null,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: selected ? accent : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Text(
                '$fdi',
                style: TextStyle(
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              for (final view in OdontogramView.values)
                _ToothAssetImage(fdi: fdi, view: view),
              SizedBox(
                height: 18,
                child: eventCount == 0
                    ? null
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: _statusColor(latestStatus!)
                              .withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$eventCount',
                          style: TextStyle(
                            color: _statusColor(latestStatus!),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToothAssetImage extends StatelessWidget {
  const _ToothAssetImage({required this.fdi, required this.view});

  final int fdi;
  final OdontogramView view;

  @override
  Widget build(BuildContext context) {
    final asset = OdontogramAssets.resolve(fdi, view);
    final image = Image.asset(
      asset.assetPath,
      width: 48,
      height: 48,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
    );
    if (!asset.flipHorizontally) return image;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(-1, 1, 1),
      child: image,
    );
  }
}

class _EventTimeline extends StatelessWidget {
  const _EventTimeline({required this.events});

  final List<OdontogramEvent> events;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            txt('toothEventHistory'),
            style: FluentTheme.of(context).typography.subtitle,
          ),
          const SizedBox(height: 10),
          if (events.isEmpty)
            Text(txt('noOdontogramEvents'))
          else
            ...events.map(
              (event) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _statusColor(event.status).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border(
                    left: BorderSide(
                      width: 4,
                      color: _statusColor(event.status),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.procedureNameSnapshot,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${event.therapyGroupNameSnapshot} · ${txt('odontogramStatus_${event.status.name}')} · ${DF.allNumbers(event.recordedAt)}',
                      style: FluentTheme.of(context).typography.caption,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.surfaces.isEmpty
                          ? txt('surfaceUnspecified')
                          : event.surfaces.map(_storedSurfaceLabel).join(', '),
                    ),
                    if (event.notes.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(event.notes),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
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
}

BoxDecoration _cardDecoration(BuildContext context) => BoxDecoration(
      color: FluentTheme.of(context).cardColor,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(
        color: FluentTheme.of(context).resources.cardStrokeColorDefault,
      ),
    );

Color _statusColor(OdontogramEventStatus status) {
  return switch (status) {
    OdontogramEventStatus.existing => Colors.purple,
    OdontogramEventStatus.monitor => Colors.orange,
    OdontogramEventStatus.planned => Colors.blue,
    OdontogramEventStatus.completed => Colors.teal,
    OdontogramEventStatus.cancelled => Colors.grey,
  };
}
