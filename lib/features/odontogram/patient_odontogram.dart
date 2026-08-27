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
import 'treatment_target.dart';

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
  TreatmentTargetScope selectedTargetScope = TreatmentTargetScope.tooth;
  final bridgeUnits = <BridgeUnit>[];
  BridgeUnitRole selectedBridgeRole = BridgeUnitRole.abutment;
  DentalArch selectedArch = DentalArch.upper;
  final removableComponents = <RemovableComponent>[];
  RemovableComponentRole selectedRemovableRole =
      RemovableComponentRole.replacedTooth;
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
          _applyProcedureDefaults(procedures.firstOrNull);
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
                if (selectedTargetScope == TreatmentTargetScope.tooth) {
                  selectedSurfaces.clear();
                }
              }),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final composer = _buildComposer(groups, procedures);
                final timeline = _EventTimeline(events: events);
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
            txt('treatmentTarget'),
            style: FluentTheme.of(context).typography.subtitle,
          ),
          const SizedBox(height: 10),
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
              onChanged:
                  canEdit ? (value) => _selectProcedure(value ?? '') : null,
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
            label: txt('treatmentTargetType'),
            child: ComboBox<TreatmentTargetScope>(
              key: const Key('treatment-target-scope'),
              value: selectedTargetScope,
              isExpanded: true,
              items: TreatmentTargetScope.values
                  .map(
                    (scope) => ComboBoxItem(
                      value: scope,
                      child: Text(txt('targetScope_${scope.name}')),
                    ),
                  )
                  .toList(),
              onChanged: canEdit
                  ? (value) => setState(() {
                        selectedTargetScope =
                            value ?? TreatmentTargetScope.tooth;
                        if (selectedTargetScope != TreatmentTargetScope.tooth) {
                          selectedSurfaces.clear();
                        }
                      })
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          _buildTargetEditor(selectedProcedure),
          if (!_targetConfigurationValid) ...[
            const SizedBox(height: 8),
            InfoBar(
              title: Text(txt('targetMappingIncomplete')),
              content: Text(txt('targetMappingIncompleteDescription')),
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
            key: const Key('record-treatment-event'),
            onPressed: canEdit &&
                    selectedGroup != null &&
                    selectedProcedure != null &&
                    _targetConfigurationValid
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

  Widget _buildTargetEditor(ProcedureCatalogItem? procedure) {
    return switch (selectedTargetScope) {
      TreatmentTargetScope.patient => InfoBar(
          title: Text(txt('patientLevelTreatment')),
          content: Text(txt('patientLevelTreatmentDescription')),
          severity: InfoBarSeverity.info,
        ),
      TreatmentTargetScope.tooth => _buildSurfaceEditor(procedure),
      TreatmentTargetScope.bridge => _buildBridgeEditor(),
      TreatmentTargetScope.removableProsthesis => _buildRemovableEditor(),
    };
  }

  Widget _buildSurfaceEditor(ProcedureCatalogItem? procedure) {
    if (procedure?.surfaceSelectionMode == SurfaceSelectionMode.notApplicable) {
      return InfoBar(
        title: Text('${txt('tooth')} $selectedFdi'),
        content: Text(txt('surfaceSelectionNotApplicable')),
        severity: InfoBarSeverity.info,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${txt('tooth')} $selectedFdi · ${txt('toothSurfaces')}'),
        const SizedBox(height: 7),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ToggleButton(
              key: const Key('surface-unspecified'),
              checked: selectedSurfaces.isEmpty,
              onChanged:
                  canEdit ? (_) => setState(selectedSurfaces.clear) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(txt('surfaceUnspecified')),
              ),
            ),
            ...DentalSurface.values.map(
              (surface) => ToggleButton(
                key: Key('surface-${surface.name}'),
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(_surfaceText(surface, selectedFdi)),
                ),
              ),
            ),
          ],
        ),
        if (procedure != null && procedure.defaultSurfaces.isNotEmpty) ...[
          const SizedBox(height: 7),
          Text(
            '${txt('catalogueSurfacePreset')}: '
            '${procedure.defaultSurfaces.map(_surfaceLabelForPreset).join(', ')}',
            style: FluentTheme.of(context).typography.caption,
          ),
        ],
      ],
    );
  }

  Widget _buildBridgeEditor() {
    final ordered = [...bridgeUnits]..sort(
        (a, b) => OdontogramAssets.permanentFdi
            .indexOf(a.toothFdi)
            .compareTo(OdontogramAssets.permanentFdi.indexOf(b.toothFdi)),
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoBar(
          title: Text(txt('bridgeUnitMapping')),
          content: Text(
            bridgeUnits.isEmpty
                ? txt('bridgeWithoutUnitsDescription')
                : txt('bridgeUnitMappingDescription'),
          ),
          severity: InfoBarSeverity.info,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            SizedBox(
              width: 110,
              child: InfoLabel(
                label: txt('selectedTooth'),
                child: _SelectedToothValue(fdi: selectedFdi),
              ),
            ),
            SizedBox(
              width: 210,
              child: InfoLabel(
                label: txt('bridgeUnitRole'),
                child: ComboBox<BridgeUnitRole>(
                  value: selectedBridgeRole,
                  isExpanded: true,
                  items: BridgeUnitRole.values
                      .map(
                        (role) => ComboBoxItem(
                          value: role,
                          child: Text(txt('bridgeRole_${role.name}')),
                        ),
                      )
                      .toList(),
                  onChanged: canEdit
                      ? (value) => setState(() {
                            selectedBridgeRole =
                                value ?? BridgeUnitRole.abutment;
                          })
                      : null,
                ),
              ),
            ),
            FilledButton(
              key: const Key('add-bridge-unit'),
              onPressed: canEdit ? _addBridgeUnit : null,
              child: Text(txt('addOrUpdateBridgeUnit')),
            ),
          ],
        ),
        if (ordered.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...ordered.map(
            (unit) => _MappingRow(
              title:
                  '${txt('tooth')} ${unit.toothFdi} · ${txt('bridgeRole_${unit.role.name}')}',
              onRemove: canEdit
                  ? () => setState(
                        () => bridgeUnits.removeWhere(
                          (item) => item.toothFdi == unit.toothFdi,
                        ),
                      )
                  : null,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRemovableEditor() {
    final ordered = [...removableComponents]
      ..sort((a, b) => a.toothFdi.compareTo(b.toothFdi));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoBar(
          title: Text(txt('removableProsthesisMapping')),
          content: Text(
            removableComponents.isEmpty
                ? txt('removableWithoutComponentsDescription')
                : txt('removableProsthesisMappingDescription'),
          ),
          severity: InfoBarSeverity.info,
        ),
        const SizedBox(height: 8),
        InfoLabel(
          label: txt('dentalArch'),
          child: ComboBox<DentalArch>(
            key: const Key('removable-arch'),
            value: selectedArch,
            isExpanded: true,
            items: DentalArch.values
                .map(
                  (arch) => ComboBoxItem(
                    value: arch,
                    child: Text(txt('dentalArch_${arch.name}')),
                  ),
                )
                .toList(),
            onChanged: canEdit
                ? (value) => setState(() {
                      selectedArch = value ?? DentalArch.unspecified;
                    })
                : null,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            SizedBox(
              width: 110,
              child: InfoLabel(
                label: txt('selectedTooth'),
                child: _SelectedToothValue(fdi: selectedFdi),
              ),
            ),
            SizedBox(
              width: 240,
              child: InfoLabel(
                label: txt('removableComponentRole'),
                child: ComboBox<RemovableComponentRole>(
                  value: selectedRemovableRole,
                  isExpanded: true,
                  items: RemovableComponentRole.values
                      .map(
                        (role) => ComboBoxItem(
                          value: role,
                          child: Text(txt('removableRole_${role.name}')),
                        ),
                      )
                      .toList(),
                  onChanged: canEdit
                      ? (value) => setState(() {
                            selectedRemovableRole =
                                value ?? RemovableComponentRole.replacedTooth;
                          })
                      : null,
                ),
              ),
            ),
            FilledButton(
              key: const Key('add-removable-component'),
              onPressed: canEdit ? _addRemovableComponent : null,
              child: Text(txt('addProstheticComponent')),
            ),
          ],
        ),
        if (ordered.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...ordered.map(
            (component) => _MappingRow(
              title:
                  '${txt('tooth')} ${component.toothFdi} · ${txt('removableRole_${component.role.name}')}',
              onRemove: canEdit
                  ? () => setState(
                        () => removableComponents.removeWhere(
                          (item) =>
                              item.toothFdi == component.toothFdi &&
                              item.role == component.role,
                        ),
                      )
                  : null,
            ),
          ),
        ],
      ],
    );
  }

  bool get _targetConfigurationValid {
    if (selectedTargetScope == TreatmentTargetScope.bridge &&
        bridgeUnits.isNotEmpty) {
      if (bridgeUnits.length < 2 ||
          bridgeUnits.map((unit) => unit.toothFdi).toSet().length !=
              bridgeUnits.length) {
        return false;
      }
      final hasPontic =
          bridgeUnits.any((unit) => unit.role == BridgeUnitRole.pontic);
      final hasSupport = bridgeUnits.any(
        (unit) =>
            unit.role == BridgeUnitRole.abutment ||
            unit.role == BridgeUnitRole.implantAbutment,
      );
      return hasPontic && hasSupport;
    }
    if (selectedTargetScope == TreatmentTargetScope.removableProsthesis) {
      return removableComponents.every(
        (component) => archContainsTooth(selectedArch, component.toothFdi),
      );
    }
    return true;
  }

  void _selectProcedure(String procedureID) {
    setState(() {
      selectedProcedureID = procedureID;
      _applyProcedureDefaults(procedureCatalog.get(procedureID));
    });
  }

  void _applyProcedureDefaults(ProcedureCatalogItem? procedure) {
    if (procedure == null) return;
    selectedTargetScope = procedure.effectiveTargetScope;
    selectedSurfaces
      ..clear()
      ..addAll(
        DentalSurface.values.where(
          (surface) => procedure.defaultSurfaces.contains(surface.name),
        ),
      );
    if (procedure.surfaceSelectionMode == SurfaceSelectionMode.notApplicable ||
        selectedTargetScope != TreatmentTargetScope.tooth) {
      selectedSurfaces.clear();
    }
  }

  void _addBridgeUnit() {
    setState(() {
      bridgeUnits.removeWhere((unit) => unit.toothFdi == selectedFdi);
      bridgeUnits.add(
        BridgeUnit(toothFdi: selectedFdi, role: selectedBridgeRole),
      );
    });
  }

  void _addRemovableComponent() {
    setState(() {
      removableComponents.removeWhere(
        (component) =>
            component.toothFdi == selectedFdi &&
            component.role == selectedRemovableRole,
      );
      removableComponents.add(
        RemovableComponent(
          toothFdi: selectedFdi,
          role: selectedRemovableRole,
        ),
      );
    });
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

  String _surfaceLabelForPreset(String stored) {
    for (final surface in DentalSurface.values) {
      if (surface.name == stored) return _surfaceText(surface, selectedFdi);
    }
    return stored;
  }

  void _recordEvent(
    TherapyGroup group,
    ProcedureCatalogItem procedure,
  ) {
    final event = OdontogramEvent.fromJson({
      'patientID': widget.patientID,
      'targetScope': selectedTargetScope.name,
      if (selectedTargetScope == TreatmentTargetScope.tooth)
        'toothFdi': selectedFdi,
      if (selectedTargetScope == TreatmentTargetScope.tooth)
        'surfaces': selectedSurfaces.map((surface) => surface.name).toList(),
      if (selectedTargetScope == TreatmentTargetScope.bridge)
        'bridgeUnits': bridgeUnits.map((unit) => unit.toJson()).toList(),
      if (selectedTargetScope == TreatmentTargetScope.removableProsthesis)
        'arch': selectedArch.name,
      if (selectedTargetScope == TreatmentTargetScope.removableProsthesis)
        'removableComponents':
            removableComponents.map((component) => component.toJson()).toList(),
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
      bridgeUnits.clear();
      removableComponents.clear();
      notesController.clear();
    });
  }
}

class _MappingRow extends StatelessWidget {
  const _MappingRow({required this.title, required this.onRemove});

  final String title;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: FluentTheme.of(context).accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(child: Text(title)),
          IconButton(
            icon: const Icon(FluentIcons.chrome_close, size: 12),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _SelectedToothValue extends StatelessWidget {
  const _SelectedToothValue({required this.fdi});

  final int fdi;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: AlignmentDirectional.centerStart,
      decoration: BoxDecoration(
        color: FluentTheme.of(context).resources.controlFillColorDisabled,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: FluentTheme.of(context).resources.controlStrokeColorDefault,
        ),
      ),
      child: Text('$fdi'),
    );
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
        final toothEvents = events.where((event) => event.drawsOnTooth(fdi));
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
            txt('treatmentEventHistory'),
            style: FluentTheme.of(context).typography.subtitle,
          ),
          const SizedBox(height: 10),
          if (events.isEmpty)
            Text(txt('noTreatmentEvents'))
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
                      _targetDescription(event),
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

  String _targetDescription(OdontogramEvent event) {
    return switch (event.targetScope) {
      TreatmentTargetScope.patient => txt('targetScope_patient'),
      TreatmentTargetScope.tooth => '${txt('tooth')} ${event.toothFdi} · '
          '${event.surfaces.isEmpty ? txt('surfaceUnspecified') : event.surfaces.map(_storedSurfaceLabel).join(', ')}',
      TreatmentTargetScope.bridge => event.bridgeUnits.isEmpty
          ? '${txt('targetScope_bridge')} · ${txt('mappingUnspecified')}'
          : event.bridgeUnits
              .map(
                (unit) =>
                    '${unit.toothFdi} ${txt('bridgeRole_${unit.role.name}')}',
              )
              .join(' · '),
      TreatmentTargetScope.removableProsthesis => [
          txt('dentalArch_${event.arch.name}'),
          if (event.removableComponents.isEmpty)
            txt('mappingUnspecified')
          else
            event.removableComponents
                .map(
                  (component) =>
                      '${component.toothFdi} ${txt('removableRole_${component.role.name}')}',
                )
                .join(' · '),
        ].join(' · '),
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
