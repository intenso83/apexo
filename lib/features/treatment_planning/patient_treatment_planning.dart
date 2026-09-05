import 'dart:convert';

import 'package:apexo/core/multi_stream_builder.dart';
import 'package:apexo/common_widgets/button_styles.dart';
import 'package:apexo/common_widgets/tag_input.dart';
import 'package:apexo/features/expenses/expenses_store.dart';
import 'package:apexo/features/labwork/laboratory_catalog_dialog.dart';
import 'package:apexo/features/odontogram/odontogram_assets.dart';
import 'package:apexo/features/odontogram/odontogram_event_model.dart';
import 'package:apexo/features/odontogram/odontogram_event_store.dart';
import 'package:apexo/features/odontogram/patient_odontogram.dart';
import 'package:apexo/features/odontogram/treatment_target.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/settings/settings_stores.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/features/therapy_catalog/therapy_catalog_store.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:fluent_ui/fluent_ui.dart';

import 'treatment_plan_branding_settings.dart';
import 'treatment_plan_completion.dart';
import 'treatment_plan_model.dart';
import 'treatment_plan_pdf.dart';
import 'treatment_plan_store.dart';
import 'treatment_plan_translations.dart';

class PatientTreatmentPlanning extends StatefulWidget {
  const PatientTreatmentPlanning({
    required this.patient,
    super.key,
  });

  final Patient patient;

  @override
  State<PatientTreatmentPlanning> createState() =>
      _PatientTreatmentPlanningState();
}

class _PatientTreatmentPlanningState extends State<PatientTreatmentPlanning> {
  late final Future<TreatmentCatalogueTranslations> translationsFuture;
  String? selectedPlanID;
  String? selectedItemID;
  String? selectedGroupID;
  String? selectedProcedureID;
  String? initializedProcedureGroupID;
  int draftSelectedFdi = 11;
  int? bridgeRangeAnchorFdi;
  final Map<String, int> bridgeDraftTooth = {};
  final Map<String, BridgeUnitRole> bridgeDraftRole = {};
  final Map<String, int> removableDraftTooth = {};
  final Map<String, RemovableComponentRole> removableDraftRole = {};

  @override
  void initState() {
    super.initState();
    translationsFuture = TreatmentCatalogueTranslations.load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TreatmentCatalogueTranslations>(
      future: translationsFuture,
      builder: (context, translationsSnapshot) {
        if (!translationsSnapshot.hasData) {
          return const Center(child: Text('Φόρτωση καταλόγου θεραπειών…'));
        }
        final translations = translationsSnapshot.data!;
        return MStreamBuilder(
          streams: [
            treatmentPlans.observableMap.stream,
            therapyGroups.observableMap.stream,
            procedureCatalog.observableMap.stream,
            expenses.observableMap.stream,
            globalSettings.observableMap.stream,
            odontogramEvents.observableMap.stream,
          ],
          builder: (context, _) {
            final plans = treatmentPlans.forPatient(widget.patient.id);
            final selectedPlan = _selectedPlan(plans);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(plans, selectedPlan),
                const SizedBox(height: 10),
                if (plans.isEmpty)
                  _EmptyPlans(onCreate: _createPlan)
                else if (selectedPlan != null)
                  _buildPlan(selectedPlan, translations),
              ],
            );
          },
        );
      },
    );
  }

  TreatmentPlan? _selectedPlan(List<TreatmentPlan> plans) {
    if (plans.isEmpty) return null;
    if (selectedPlanID != null) {
      for (final plan in plans) {
        if (plan.id == selectedPlanID) return plan;
      }
    }
    selectedPlanID = plans.first.id;
    return plans.first;
  }

  Widget _buildHeader(
    List<TreatmentPlan> plans,
    TreatmentPlan? selectedPlan,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FluentTheme.of(context).resources.cardBackgroundFillColorDefault,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withAlpha(45)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Σχέδια θεραπείας',
            style: FluentTheme.of(context).typography.subtitle,
          ),
          if (plans.isNotEmpty)
            ComboBox<String>(
              value: selectedPlan?.id,
              items: plans
                  .map((plan) => ComboBoxItem<String>(
                        value: plan.id,
                        child: Text(plan.title),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => selectedPlanID = value),
            ),
          FilledButton(
            key: const Key('new-treatment-plan'),
            onPressed: _createPlan,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.add),
                SizedBox(width: 6),
                Text('Νέα εναλλακτική'),
              ],
            ),
          ),
          Button(
            onPressed: () => showTreatmentPlanBrandingSettings(context),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.settings),
                SizedBox(width: 6),
                Text('Ρυθμίσεις PDF'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlan(
    TreatmentPlan plan,
    TreatmentCatalogueTranslations translations,
  ) {
    final selectedItem = _selectedItem(plan);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPlanIdentity(plan),
        const SizedBox(height: 10),
        _buildPlanningOdontogram(plan, selectedItem),
        const SizedBox(height: 10),
        _buildCatalogueComposer(plan, translations),
        const SizedBox(height: 10),
        if (plan.items.isEmpty)
          const InfoBar(
            title: Text('Δεν έχουν προστεθεί θεραπείες'),
            content: Text(
              'Επιλέξτε ομάδα και θεραπεία από τον κατάλογο για να δημιουργήσετε το σχέδιο.',
            ),
          )
        else ...[
          _buildTreatmentWorkspace(plan, selectedItem),
          const SizedBox(height: 10),
        ],
        _buildPlanFooter(plan),
        const SizedBox(height: 30),
      ],
    );
  }

  TreatmentPlanItem? _selectedItem(TreatmentPlan plan) {
    if (selectedItemID != null) {
      for (final item in plan.items) {
        if (item.id == selectedItemID) return item;
      }
    }
    return null;
  }

  Widget _buildPlanIdentity(TreatmentPlan plan) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _PersistedTextBox(
                  key: ValueKey('plan-title-${plan.id}'),
                  label: 'Όνομα εναλλακτικής',
                  value: plan.title,
                  onChanged: (value) {
                    plan.title =
                        value.trim().isEmpty ? 'Εναλλακτική θεραπείας' : value;
                    treatmentPlans.set(plan);
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(FluentIcons.delete),
                onPressed: () async {
                  final confirmed = await _confirm(
                    'Διαγραφή εναλλακτικής',
                    'Το σχέδιο θα αρχειοθετηθεί και δεν θα εμφανίζεται στον ασθενή.',
                  );
                  if (!confirmed) return;
                  treatmentPlans.archive(plan.id);
                  setState(() => selectedPlanID = null);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Γλώσσα λίστας και PDF:'),
              ...TreatmentPlanLanguage.values.map((language) {
                final selected = plan.language == language;
                return selected
                    ? FilledButton(
                        onPressed: () {},
                        child: Text(_languageLabel(language)),
                      )
                    : Button(
                        onPressed: () {
                          plan.language = language;
                          treatmentPlans.set(plan);
                        },
                        child: Text(_languageLabel(language)),
                      );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlanningOdontogram(
    TreatmentPlan plan,
    TreatmentPlanItem? selectedItem,
  ) {
    final planEvents = plan.items
        .where((item) => item.status == TreatmentPlanItemStatus.planned)
        .map(_planItemAsOdontogramEvent)
        .toList(growable: false);
    final clinicalEvents = odontogramEvents.forPatient(widget.patient.id);
    final selectedTeeth = selectedItem == null
        ? <int>{draftSelectedFdi}
        : _itemTeeth(selectedItem).toSet();
    if (selectedTeeth.isEmpty) selectedTeeth.add(draftSelectedFdi);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PatientOdontogramChart(
          selectedFdis: selectedTeeth,
          bridgeUnits: selectedItem?.bridgeUnits ?? const <BridgeUnit>[],
          events: [...planEvents, ...clinicalEvents],
          onSelected: (fdi, extendSelection) =>
              _selectPlanningTooth(plan, fdi, extendSelection),
        ),
        const SizedBox(height: 6),
        const Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            _PlanningLegendItem(
              color: Color(0xFF1976D2),
              outlined: true,
              label: 'Σχεδιαζόμενη θεραπεία',
            ),
            _PlanningLegendItem(
              color: Color(0xFF00897B),
              label: 'Ολοκληρωμένη / υπάρχουσα θεραπεία',
            ),
          ],
        ),
      ],
    );
  }

  OdontogramEvent _planItemAsOdontogramEvent(TreatmentPlanItem item) {
    return OdontogramEvent.fromJson({
      'patientID': widget.patient.id,
      'targetScope': item.targetScope.name,
      if (item.toothFdi != null) 'toothFdi': item.toothFdi,
      if (item.surfaces.isNotEmpty) 'surfaces': item.surfaces,
      if (item.bridgeUnits.isNotEmpty)
        'bridgeUnits': item.bridgeUnits.map((unit) => unit.toJson()).toList(),
      if (item.arch != DentalArch.unspecified) 'arch': item.arch.name,
      if (item.removableComponents.isNotEmpty)
        'removableComponents': item.removableComponents
            .map((component) => component.toJson())
            .toList(),
      'procedureID': item.procedureID,
      'procedureNameSnapshot': item.procedureNameElSnapshot,
      'therapyGroupID': item.therapyGroupID,
      'therapyGroupNameSnapshot': item.therapyGroupNameSnapshot,
      if (item.odontogramOverlay != null)
        'overlayKind': item.odontogramOverlay!.name,
      'eventKind': OdontogramEventKind.treatment.name,
      'status': OdontogramEventStatus.planned.name,
      'recordedAt': (DateTime.now().millisecondsSinceEpoch / 60000).round(),
    });
  }

  List<int> _itemTeeth(TreatmentPlanItem item) => switch (item.targetScope) {
        TreatmentTargetScope.patient => const <int>[],
        TreatmentTargetScope.tooth =>
          item.toothFdi == null ? const <int>[] : <int>[item.toothFdi!],
        TreatmentTargetScope.bridge =>
          item.bridgeUnits.map((unit) => unit.toothFdi).toList(),
        TreatmentTargetScope.removableProsthesis => item.removableComponents
            .map((component) => component.toothFdi)
            .toList(),
      };

  void _selectPlanningTooth(
    TreatmentPlan plan,
    int fdi,
    bool extendSelection,
  ) {
    final item = _selectedItem(plan);
    var changed = false;
    setState(() {
      draftSelectedFdi = fdi;
      if (item == null || item.isCompleted) return;
      switch (item.targetScope) {
        case TreatmentTargetScope.patient:
          return;
        case TreatmentTargetScope.tooth:
          item.toothFdi = fdi;
          changed = true;
        case TreatmentTargetScope.bridge:
          bridgeDraftTooth[item.id] = fdi;
          final anchor = bridgeRangeAnchorFdi ?? fdi;
          if (extendSelection) {
            final range = _fdiRange(anchor, fdi);
            if (range != null) {
              item.bridgeUnits
                ..clear()
                ..addAll(range.indexed.map((entry) => BridgeUnit(
                      toothFdi: entry.$2,
                      role: _suggestedBridgeRole(entry.$1, range.length),
                    )));
              changed = true;
            }
          } else {
            bridgeRangeAnchorFdi = fdi;
          }
        case TreatmentTargetScope.removableProsthesis:
          removableDraftTooth[item.id] = fdi;
          if (item.arch == DentalArch.unspecified) {
            item.arch = fdi ~/ 10 <= 2 ? DentalArch.upper : DentalArch.lower;
            changed = true;
          }
      }
    });
    if (changed) treatmentPlans.set(plan);
  }

  Widget _buildTreatmentWorkspace(
    TreatmentPlan plan,
    TreatmentPlanItem? selectedItem,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ledger = _buildTreatmentLedger(plan, selectedItem);
        final inspector = _buildPlanItemInspector(plan, selectedItem);
        if (constraints.maxWidth >= 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: ledger),
              const SizedBox(width: 10),
              Expanded(flex: 5, child: inspector),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [ledger, const SizedBox(height: 10), inspector],
        );
      },
    );
  }

  Widget _buildTreatmentLedger(
    TreatmentPlan plan,
    TreatmentPlanItem? selectedItem,
  ) {
    return Container(
      decoration: _planningCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Θεραπείες εναλλακτικής',
                    style: FluentTheme.of(context).typography.subtitle,
                  ),
                ),
                Text('${plan.items.length} εγγραφές'),
              ],
            ),
          ),
          const Divider(size: 1),
          const _TreatmentLedgerHeader(),
          ...plan.items.map(
            (item) => _buildTreatmentLedgerRow(
              plan,
              item,
              selected: selectedItem?.id == item.id,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreatmentLedgerRow(
    TreatmentPlan plan,
    TreatmentPlanItem item, {
    required bool selected,
  }) {
    final accent = FluentTheme.of(context).accentColor;
    final completed = item.isCompleted;
    return GestureDetector(
      key: ValueKey('treatment-plan-ledger-row-${item.id}'),
      onTap: () => setState(() {
        selectedItemID = item.id;
        final teeth = _itemTeeth(item);
        if (teeth.isNotEmpty) draftSelectedFdi = teeth.first;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.09) : null,
          border: Border(
            left: BorderSide(
              color: completed ? const Color(0xFF00897B) : accent,
              width: selected ? 4 : 2,
            ),
            bottom: BorderSide(color: Colors.grey.withAlpha(35)),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Checkbox(
                checked: completed,
                onChanged: completed ? null : (_) => _completeItem(plan, item),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              flex: 5,
              child: Tooltip(
                message: item.displayName(plan.language),
                child: Text(
                  item.displayName(plan.language),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Text(
                _itemTargetLabel(item),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(child: Text('${item.quantity}', textAlign: TextAlign.end)),
            Expanded(
              flex: 2,
              child:
                  Text(_money(item.monetaryDiscount), textAlign: TextAlign.end),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _money(item.net),
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 6),
            if (!completed)
              Tooltip(
                message: txt('deleteTreatment'),
                child: IconButton(
                  key: ValueKey('delete-plan-item-${item.id}'),
                  icon: Icon(
                    FluentIcons.delete,
                    size: 15,
                    color: Colors.red,
                  ),
                  onPressed: () {
                    setState(() {
                      plan.items.removeWhere(
                        (candidate) => candidate.id == item.id,
                      );
                      if (selectedItemID == item.id) selectedItemID = null;
                    });
                    treatmentPlans.set(plan);
                  },
                ),
              ),
            Icon(
              completed ? FluentIcons.completed_solid : FluentIcons.edit,
              size: 14,
              color: completed ? const Color(0xFF00897B) : accent,
            ),
          ],
        ),
      ),
    );
  }

  String _itemTargetLabel(TreatmentPlanItem item) {
    return switch (item.targetScope) {
      TreatmentTargetScope.patient => 'Γενικό',
      TreatmentTargetScope.tooth => item.toothFdi == null
          ? 'Χωρίς δόντι'
          : '${item.toothFdi}${item.surfaces.isEmpty ? '' : ' · ${item.surfaces.map((surface) => _surfaceLabels[surface] ?? surface).join('/')}'}',
      TreatmentTargetScope.bridge => item.bridgeUnits.isEmpty
          ? 'Γέφυρα · χωρίς μονάδες'
          : item.bridgeUnits.map((unit) => unit.toothFdi).join('–'),
      TreatmentTargetScope.removableProsthesis =>
        '${_archLabel(item.arch)}${item.removableComponents.isEmpty ? '' : ' · ${item.removableComponents.length} στοιχεία'}',
    };
  }

  Widget _buildPlanItemInspector(
    TreatmentPlan plan,
    TreatmentPlanItem? item,
  ) {
    if (item == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: _planningCardDecoration(context),
        child: const InfoBar(
          title: Text('Επιλέξτε μια θεραπεία'),
          content: Text(
            'Η επιλεγμένη γραμμή επεξεργάζεται εδώ. Η επιλογή δοντιού γίνεται απευθείας από το οδοντόγραμμα.',
          ),
        ),
      );
    }
    return _buildPlanItem(plan, item);
  }

  Widget _buildPlanFooter(TreatmentPlan plan) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F6F3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBBDDD7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _PlanTotalPill(label: 'Αρχικό σύνολο', value: _money(plan.gross)),
              _PlanTotalPill(
                label: 'Σύνολο έκπτωσης',
                value: _money(plan.totalDiscount),
                color: const Color(0xFFD97706),
              ),
              _PlanTotalPill(
                label: 'Τελικό σύνολο',
                value: _money(plan.total),
                color: const Color(0xFF00897B),
                strong: true,
              ),
              _buildPlanActions(plan),
            ],
          ),
          const SizedBox(height: 8),
          Expander(
            header: const Text('Εκπτώσεις, συναίνεση και υπογεγραμμένο αρχείο'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDiscountAndSummary(plan),
                const SizedBox(height: 10),
                _buildConsent(plan),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogueComposer(
    TreatmentPlan plan,
    TreatmentCatalogueTranslations translations,
  ) {
    final groups =
        therapyGroups.ordered.where((group) => !group.hidden).toList();
    if (!groups.any((group) => group.id == selectedGroupID)) {
      selectedGroupID = groups.firstOrNull?.id;
      selectedProcedureID = null;
    }
    final procedures = procedureCatalog
        .forGroup(selectedGroupID ?? '')
        .where((procedure) => !procedure.hidden)
        .toList();
    if (initializedProcedureGroupID != selectedGroupID) {
      initializedProcedureGroupID = selectedGroupID;
      selectedProcedureID = null;
    } else if (selectedProcedureID != null &&
        !procedures.any((procedure) => procedure.id == selectedProcedureID)) {
      selectedProcedureID = null;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FluentTheme.of(context).resources.cardBackgroundFillColorDefault,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withAlpha(45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Προσθήκη από τον κατάλογο θεραπειών',
            style: FluentTheme.of(context).typography.bodyStrong,
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: InfoLabel(
                  label: 'Ομάδα',
                  child: ComboBox<String>(
                    isExpanded: true,
                    value: selectedGroupID,
                    items: groups
                        .map((group) => ComboBoxItem<String>(
                              value: group.id,
                              child: Text(translations.groupName(
                                group.title,
                                plan.language,
                              )),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() {
                      selectedGroupID = value;
                      selectedProcedureID = null;
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: InfoLabel(
                  label: 'Θεραπεία',
                  child: TagInputWidget(
                    key: const Key('treatment-plan-procedure-picker'),
                    strict: true,
                    limit: 1,
                    multiline: false,
                    placeholder: txt('catalogueSearch'),
                    initialValue: procedures
                        .where(
                            (procedure) => procedure.id == selectedProcedureID)
                        .map((procedure) => TagInputItem(
                              value: procedure.id,
                              label: translations.procedureName(
                                procedure,
                                plan.language,
                              ),
                              searchText:
                                  '${procedure.title} ${procedure.sourceCode}',
                            ))
                        .toList(),
                    suggestions: procedures
                        .map((procedure) => TagInputItem(
                              value: procedure.id,
                              label: translations.procedureName(
                                procedure,
                                plan.language,
                              ),
                              searchText:
                                  '${procedure.title} ${procedure.sourceCode}',
                            ))
                        .toList(),
                    onChanged: (items) => setState(() {
                      selectedProcedureID =
                          items.isEmpty ? null : items.first.value;
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                key: const Key('add-treatment-plan-item'),
                onPressed: selectedProcedureID == null
                    ? null
                    : () => _addProcedure(plan, translations),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.add),
                    SizedBox(width: 6),
                    Text('Προσθήκη'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlanItem(TreatmentPlan plan, TreatmentPlanItem item) {
    final completed = item.isCompleted;
    final procedure = procedureCatalog.get(item.procedureID);
    return Container(
      key: ValueKey('treatment-plan-item-${item.id}'),
      padding: const EdgeInsets.all(12),
      decoration: _planningCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.displayName(plan.language),
                  style: FluentTheme.of(context).typography.subtitle,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: completed
                      ? const Color(0xFFE2F6EF)
                      : const Color(0xFFE8F3FB),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(completed ? 'Ολοκληρωμένο' : 'Προγραμματισμένο'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _numberField(
                label: 'Ποσότητα',
                width: 145,
                value: item.quantity.toDouble(),
                min: 1,
                max: 999,
                onChanged: completed
                    ? null
                    : (value) {
                        item.quantity = (value ?? 1).round().clamp(1, 999);
                        treatmentPlans.set(plan);
                      },
              ),
              _numberField(
                label: 'Τιμή μονάδας (${currency()})',
                width: 175,
                value: item.unitPrice,
                min: 0,
                onChanged: completed
                    ? null
                    : (value) {
                        item.unitPrice = value ?? 0;
                        treatmentPlans.set(plan);
                      },
              ),
              _numberField(
                label: 'Έκπτωση % (εσωτερικό)',
                width: 175,
                value: item.discountPercent,
                min: 0,
                max: 100,
                onChanged: completed
                    ? null
                    : (value) {
                        item.discountPercent = value ?? 0;
                        treatmentPlans.set(plan);
                      },
              ),
              _numberField(
                label: 'Έκπτωση ${currency()} (εσωτερικό)',
                width: 175,
                value: item.discountAmount,
                min: 0,
                onChanged: completed
                    ? null
                    : (value) {
                        item.discountAmount = value ?? 0;
                        treatmentPlans.set(plan);
                      },
              ),
            ],
          ),
          if (procedure != null &&
              procedureCatalog.requiresLaboratory(procedure)) ...[
            const SizedBox(height: 12),
            _buildLaboratoryEditor(plan, item, completed),
          ],
          const SizedBox(height: 12),
          _buildTargetEditor(plan, item, completed),
          const SizedBox(height: 8),
          _PersistedTextBox(
            key: ValueKey('plan-item-notes-${item.id}'),
            label: 'Σημειώσεις',
            value: item.notes,
            enabled: !completed,
            multiline: true,
            onChanged: (value) {
              item.notes = value;
              treatmentPlans.set(plan);
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (!completed)
                FilledButton(
                  key: ValueKey('complete-plan-item-${item.id}'),
                  onPressed: () => _completeItem(plan, item),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.completed),
                      SizedBox(width: 6),
                      Text('Ολοκλήρωση τώρα'),
                    ],
                  ),
                ),
              const Spacer(),
              if (!completed)
                IconButton(
                  icon: const Icon(FluentIcons.delete),
                  onPressed: () {
                    plan.items
                        .removeWhere((candidate) => candidate.id == item.id);
                    selectedItemID = null;
                    treatmentPlans.set(plan);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLaboratoryEditor(
    TreatmentPlan plan,
    TreatmentPlanItem item,
    bool completed,
  ) {
    final laboratories = expenses.laboratories;
    final selected = laboratories.any((lab) => lab.id == item.laboratoryID)
        ? item.laboratoryID
        : null;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(FluentIcons.manufacturing, size: 17),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  txt('laboratoryAssignment'),
                  style: FluentTheme.of(context).typography.bodyStrong,
                ),
              ),
              Button(
                onPressed: completed
                    ? null
                    : () => showLaboratoryCatalogDialog(
                          context,
                          selectedLaboratoryID: item.laboratoryID,
                        ),
                child: ButtonContent(
                  FluentIcons.settings,
                  txt('laboratoryCatalogue'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (laboratories.isEmpty)
            InfoBar(
              title: Text(txt('noLaboratories')),
              content: Text(txt('createLaboratoryFirst')),
              severity: InfoBarSeverity.warning,
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: InfoLabel(
                    label: txt('laboratory'),
                    child: ComboBox<String>(
                      isExpanded: true,
                      value: selected,
                      placeholder: Text(txt('selectLaboratory')),
                      items: laboratories
                          .map((lab) => ComboBoxItem<String>(
                                value: lab.id,
                                child: Text(lab.supplierName),
                              ))
                          .toList(),
                      onChanged: completed
                          ? null
                          : (value) {
                              final laboratory = expenses.get(value ?? '');
                              item.laboratoryID = value ?? '';
                              item.laboratoryNameSnapshot =
                                  laboratory?.supplierName ?? '';
                              item.laboratoryCost = expenses.laboratoryPrice(
                                    item.laboratoryID,
                                    item.procedureID,
                                  ) ??
                                  0;
                              treatmentPlans.set(plan);
                            },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _numberField(
                  label: '${txt('laboratoryCost')} (${currency()})',
                  width: 175,
                  value: item.laboratoryCost,
                  min: 0,
                  onChanged: completed || selected == null
                      ? null
                      : (value) {
                          item.laboratoryCost = value ?? 0;
                          treatmentPlans.set(plan);
                        },
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTargetEditor(
    TreatmentPlan plan,
    TreatmentPlanItem item,
    bool completed,
  ) {
    switch (item.targetScope) {
      case TreatmentTargetScope.patient:
        return const InfoBar(
          title: Text('Γενική θεραπεία ασθενή'),
          content: Text('Δεν απαιτείται επιλογή δοντιού.'),
        );
      case TreatmentTargetScope.tooth:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoBar(
              key: ValueKey('plan-item-tooth-${item.id}'),
              title: Text(
                item.toothFdi == null
                    ? 'Δεν έχει επιλεγεί δόντι'
                    : 'Δόντι ${item.toothFdi}',
              ),
              content: Text(
                completed
                    ? 'Η χαρτογράφηση έχει κλειδωθεί μετά την ολοκλήρωση.'
                    : 'Κάντε κλικ στο επιθυμητό δόντι στο οδοντόγραμμα για άμεση αλλαγή.',
              ),
              severity: item.toothFdi == null
                  ? InfoBarSeverity.warning
                  : InfoBarSeverity.info,
            ),
            if (item.handlingMode == ProcedureHandlingMode.surfaceBased) ...[
              const SizedBox(height: 10),
              const Text('Επιφάνειες (προαιρετικές)'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _surfaceLabels.entries.map((entry) {
                  final selected = item.surfaces.contains(entry.key);
                  return selected
                      ? FilledButton(
                          onPressed: completed
                              ? null
                              : () {
                                  item.surfaces.remove(entry.key);
                                  treatmentPlans.set(plan);
                                },
                          child: Text(entry.value),
                        )
                      : Button(
                          onPressed: completed
                              ? null
                              : () {
                                  item.surfaces.add(entry.key);
                                  treatmentPlans.set(plan);
                                },
                          child: Text(entry.value),
                        );
                }).toList(),
              ),
            ],
          ],
        );
      case TreatmentTargetScope.bridge:
        return _buildBridgeTarget(plan, item, completed);
      case TreatmentTargetScope.removableProsthesis:
        return _buildRemovableTarget(plan, item, completed);
    }
  }

  Widget _buildBridgeTarget(
    TreatmentPlan plan,
    TreatmentPlanItem item,
    bool completed,
  ) {
    final draftTooth = bridgeDraftTooth[item.id] ?? draftSelectedFdi;
    final draftRole = bridgeDraftRole[item.id] ?? BridgeUnitRole.abutment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const InfoBar(
          title: Text('Χαρτογράφηση γέφυρας'),
          content: Text(
            'Κλικ σε δόντι για επιλογή. Shift + κλικ σε δεύτερο δόντι δημιουργεί αυτόματα το εύρος με στηρίγματα στα άκρα και ενδιάμεσα μεταξύ τους.',
          ),
        ),
        const SizedBox(height: 8),
        if (!completed)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              SizedBox(
                width: 110,
                child: InfoLabel(
                  label: 'Επιλεγμένο δόντι',
                  child: _SelectedPlanningTooth(fdi: draftTooth),
                ),
              ),
              SizedBox(
                width: 210,
                child: InfoLabel(
                  label: 'Ρόλος',
                  child: ComboBox<BridgeUnitRole>(
                    value: draftRole,
                    isExpanded: true,
                    items: BridgeUnitRole.values
                        .map((role) => ComboBoxItem<BridgeUnitRole>(
                              value: role,
                              child: Text(_bridgeRoleLabel(role)),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() {
                      bridgeDraftRole[item.id] =
                          value ?? BridgeUnitRole.abutment;
                    }),
                  ),
                ),
              ),
              Button(
                onPressed: () {
                  item.bridgeUnits.removeWhere(
                    (unit) => unit.toothFdi == draftTooth,
                  );
                  item.bridgeUnits.add(BridgeUnit(
                    toothFdi: draftTooth,
                    role: draftRole,
                  ));
                  treatmentPlans.set(plan);
                },
                child: const Text('Προσθήκη μονάδας'),
              ),
            ],
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: item.bridgeUnits
              .map((unit) => _TargetChip(
                    label: '${unit.toothFdi} · ${_bridgeRoleLabel(unit.role)}',
                    onRemove: completed
                        ? null
                        : () {
                            item.bridgeUnits.remove(unit);
                            treatmentPlans.set(plan);
                          },
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildRemovableTarget(
    TreatmentPlan plan,
    TreatmentPlanItem item,
    bool completed,
  ) {
    final draftTooth = removableDraftTooth[item.id] ?? draftSelectedFdi;
    final draftRole =
        removableDraftRole[item.id] ?? RemovableComponentRole.replacedTooth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 240,
          child: InfoLabel(
            label: 'Οδοντικό τόξο',
            child: ComboBox<DentalArch>(
              value: item.arch,
              isExpanded: true,
              items: DentalArch.values
                  .where((arch) => arch != DentalArch.unspecified)
                  .map((arch) => ComboBoxItem<DentalArch>(
                        value: arch,
                        child: Text(_archLabel(arch)),
                      ))
                  .toList(),
              onChanged: completed
                  ? null
                  : (value) {
                      item.arch = value ?? DentalArch.unspecified;
                      item.removableComponents.removeWhere((component) =>
                          !archContainsTooth(item.arch, component.toothFdi));
                      treatmentPlans.set(plan);
                    },
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text('Επιμέρους στοιχεία (προαιρετικά)'),
        const SizedBox(height: 6),
        if (!completed)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              SizedBox(
                width: 110,
                child: InfoLabel(
                  label: 'Επιλεγμένο δόντι',
                  child: _SelectedPlanningTooth(fdi: draftTooth),
                ),
              ),
              SizedBox(
                width: 220,
                child: InfoLabel(
                  label: 'Ρόλος',
                  child: ComboBox<RemovableComponentRole>(
                    value: draftRole,
                    isExpanded: true,
                    items: RemovableComponentRole.values
                        .map((role) => ComboBoxItem<RemovableComponentRole>(
                              value: role,
                              child: Text(_removableRoleLabel(role)),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() {
                      removableDraftRole[item.id] =
                          value ?? RemovableComponentRole.replacedTooth;
                    }),
                  ),
                ),
              ),
              Button(
                onPressed: item.arch == DentalArch.unspecified ||
                        !archContainsTooth(item.arch, draftTooth)
                    ? null
                    : () {
                        item.removableComponents.removeWhere((component) =>
                            component.toothFdi == draftTooth &&
                            component.role == draftRole);
                        item.removableComponents.add(RemovableComponent(
                          toothFdi: draftTooth,
                          role: draftRole,
                        ));
                        treatmentPlans.set(plan);
                      },
                child: const Text('Προσθήκη στοιχείου'),
              ),
            ],
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: item.removableComponents
              .map((component) => _TargetChip(
                    label:
                        '${component.toothFdi} · ${_removableRoleLabel(component.role)}',
                    onRemove: completed
                        ? null
                        : () {
                            item.removableComponents.remove(component);
                            treatmentPlans.set(plan);
                          },
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildDiscountAndSummary(TreatmentPlan plan) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F6F3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBBDDD7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Οικονομική σύνοψη',
            style: FluentTheme.of(context).typography.subtitle,
          ),
          const SizedBox(height: 8),
          const InfoBar(
            title: Text('Εσωτερικές τιμές έκπτωσης'),
            content: Text(
              'Το ποσοστό δεν εμφανίζεται στο PDF του ασθενή. Το PDF δείχνει μόνο χρηματικά ποσά έκπτωσης και το άθροισμά τους.',
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _numberField(
                label: 'Έκπτωση συνολικού σχεδίου %',
                value: plan.wholeDiscountPercent,
                min: 0,
                max: 100,
                onChanged: (value) {
                  plan.wholeDiscountPercent = value ?? 0;
                  treatmentPlans.set(plan);
                },
              ),
              _numberField(
                label: 'Σταθερή έκπτωση σχεδίου (${currency()})',
                value: plan.wholeDiscountAmount,
                min: 0,
                onChanged: (value) {
                  plan.wholeDiscountAmount = value ?? 0;
                  treatmentPlans.set(plan);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _summaryRow('Αρχικό σύνολο', plan.gross),
          _summaryRow('Εκπτώσεις θεραπειών', -plan.itemDiscountTotal),
          _summaryRow('Έκπτωση συνολικού σχεδίου', -plan.wholePlanDiscount),
          const Divider(),
          _summaryRow('Σύνολο έκπτωσης', -plan.totalDiscount, strong: true),
          _summaryRow('Τελικό σύνολο', plan.total, strong: true),
        ],
      ),
    );
  }

  Widget _buildConsent(TreatmentPlan plan) {
    final consentText = plan.consentText(plan.language);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FluentTheme.of(context).resources.cardBackgroundFillColorDefault,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withAlpha(45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Συναίνεση', style: FluentTheme.of(context).typography.subtitle),
          const SizedBox(height: 10),
          SizedBox(
            width: 320,
            child: InfoLabel(
              label: 'Κατάσταση',
              child: ComboBox<TreatmentPlanConsentStatus>(
                isExpanded: true,
                value: plan.consentStatus,
                items: TreatmentPlanConsentStatus.values
                    .map((status) => ComboBoxItem<TreatmentPlanConsentStatus>(
                          value: status,
                          child: Text(_consentLabel(status)),
                        ))
                    .toList(),
                onChanged: (value) {
                  plan.consentStatus =
                      value ?? TreatmentPlanConsentStatus.notAgreed;
                  plan.consentRecordedAt =
                      plan.consentStatus == TreatmentPlanConsentStatus.notAgreed
                          ? null
                          : DateTime.now();
                  treatmentPlans.set(plan);
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          _PersistedTextBox(
            key: ValueKey('consent-${plan.id}-${plan.language.name}'),
            label: 'Κείμενο συναίνεσης στη γλώσσα του PDF',
            value: consentText,
            multiline: true,
            onChanged: (value) {
              switch (plan.language) {
                case TreatmentPlanLanguage.el:
                  plan.consentTextEl = value;
                case TreatmentPlanLanguage.en:
                  plan.consentTextEn = value;
                case TreatmentPlanLanguage.de:
                  plan.consentTextDe = value;
              }
              treatmentPlans.set(plan);
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Button(
                onPressed: () => _attachSignedDocument(plan),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.attach),
                    SizedBox(width: 6),
                    Text('Επισύναψη υπογεγραμμένου αρχείου'),
                  ],
                ),
              ),
              if (plan.signedAttachmentName.isNotEmpty)
                _TargetChip(
                  label: plan.signedAttachmentName,
                  onRemove: () {
                    plan.signedAttachmentName = '';
                    plan.signedAttachmentPath = '';
                    plan.signedAttachmentBase64 = '';
                    treatmentPlans.set(plan);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlanActions(TreatmentPlan plan) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton(
          key: const Key('preview-treatment-plan-pdf'),
          onPressed: plan.items.isEmpty
              ? null
              : () async {
                  try {
                    await previewTreatmentPlanPdf(
                      plan: plan,
                      patient: widget.patient,
                    );
                  } catch (error) {
                    _showMessage(
                      'Αποτυχία δημιουργίας PDF',
                      error.toString(),
                      InfoBarSeverity.error,
                    );
                  }
                },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.pdf),
              SizedBox(width: 6),
              Text('Προεπισκόπηση / εκτύπωση PDF'),
            ],
          ),
        ),
        Button(
          onPressed: () {
            treatmentPlans.set(plan);
            _showMessage(
              'Αποθηκεύτηκε',
              'Το σχέδιο θεραπείας αποθηκεύτηκε τοπικά.',
              InfoBarSeverity.success,
            );
          },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.save),
              SizedBox(width: 6),
              Text('Αποθήκευση σχεδίου'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _numberField({
    required String label,
    required double value,
    required double min,
    double? max,
    double width = 220,
    required ValueChanged<double?>? onChanged,
  }) {
    return SizedBox(
      width: width,
      child: InfoLabel(
        label: label,
        child: NumberBox<double>(
          value: value,
          min: min,
          max: max,
          mode: SpinButtonPlacementMode.inline,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _summaryRow(String label, double amount, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style:
                  strong ? FluentTheme.of(context).typography.bodyStrong : null,
            ),
          ),
          Text(
            _money(amount),
            style:
                strong ? FluentTheme.of(context).typography.bodyStrong : null,
          ),
        ],
      ),
    );
  }

  void _createPlan() {
    final index = treatmentPlans.forPatient(widget.patient.id).length + 1;
    final plan = TreatmentPlan.fromJson({
      'patientID': widget.patient.id,
      'title': 'Εναλλακτική $index',
      'language': TreatmentPlanLanguage.el.name,
      'consentTextEl': globalSettings.treatmentPlanConsentEl,
      'consentTextEn': globalSettings.treatmentPlanConsentEn,
      'consentTextDe': globalSettings.treatmentPlanConsentDe,
    });
    treatmentPlans.set(plan);
    setState(() => selectedPlanID = plan.id);
  }

  List<int>? _fdiRange(int start, int end) {
    for (final jaw in [OdontogramAssets.upperFdi, OdontogramAssets.lowerFdi]) {
      final startIndex = jaw.indexOf(start);
      final endIndex = jaw.indexOf(end);
      if (startIndex < 0 || endIndex < 0) continue;
      final first = startIndex < endIndex ? startIndex : endIndex;
      final last = startIndex < endIndex ? endIndex : startIndex;
      return jaw.sublist(first, last + 1);
    }
    return null;
  }

  BridgeUnitRole _suggestedBridgeRole(int index, int length) {
    if (length == 2) {
      return index == 0 ? BridgeUnitRole.abutment : BridgeUnitRole.pontic;
    }
    return index == 0 || index == length - 1
        ? BridgeUnitRole.abutment
        : BridgeUnitRole.pontic;
  }

  void _addProcedure(
    TreatmentPlan plan,
    TreatmentCatalogueTranslations translations,
  ) {
    final procedure = procedureCatalog.get(selectedProcedureID ?? '');
    if (procedure == null) return;
    final translation = translations.forProcedure(procedure);
    final decision = procedureCatalog.handlingDecision(procedure);
    final item = TreatmentPlanItem()
      ..procedureID = procedure.id
      ..procedureNameElSnapshot = procedure.title
      ..procedureNameEnSnapshot = translation?.english ?? procedure.title
      ..procedureNameDeSnapshot = translation?.german ?? procedure.title
      ..therapyGroupID = procedure.therapyGroupID
      ..therapyGroupNameSnapshot =
          therapyGroups.get(procedure.therapyGroupID)?.title ?? ''
      ..handlingMode = decision.mode
      ..odontogramOverlay = procedureCatalog.overlayFor(procedure)
      ..unitPrice = procedure.basePrice
      ..surfaces = [...decision.mode.automaticSurfaces];
    switch (item.targetScope) {
      case TreatmentTargetScope.patient:
        break;
      case TreatmentTargetScope.tooth:
        item.toothFdi = draftSelectedFdi;
      case TreatmentTargetScope.bridge:
        item.bridgeUnits = [
          BridgeUnit(
            toothFdi: draftSelectedFdi,
            role: BridgeUnitRole.abutment,
          ),
        ];
        bridgeDraftTooth[item.id] = draftSelectedFdi;
        bridgeRangeAnchorFdi = draftSelectedFdi;
      case TreatmentTargetScope.removableProsthesis:
        item.arch =
            draftSelectedFdi ~/ 10 <= 2 ? DentalArch.upper : DentalArch.lower;
        removableDraftTooth[item.id] = draftSelectedFdi;
    }
    plan.items.add(item);
    selectedItemID = item.id;
    treatmentPlans.set(plan);
  }

  Future<void> _completeItem(
    TreatmentPlan plan,
    TreatmentPlanItem item,
  ) async {
    if (item.targetValidationErrors().isNotEmpty) {
      _showMessage(
        'Λείπει η περιοχή θεραπείας',
        'Συμπληρώστε το δόντι ή τη χαρτογράφηση πριν μεταφέρετε τη θεραπεία ως ολοκληρωμένη.',
        InfoBarSeverity.warning,
      );
      return;
    }
    final confirmed = await _confirm(
      'Ολοκλήρωση θεραπείας',
      'Η θεραπεία θα καταχωριστεί στο οδοντόγραμμα με την τρέχουσα ημερομηνία και ώρα. Δεν θα δημιουργηθεί πληρωμή ή χρέωση υπολοίπου.',
    );
    if (!confirmed) return;
    try {
      completeTreatmentPlanItem(plan: plan, itemID: item.id);
      _showMessage(
        'Η θεραπεία ολοκληρώθηκε',
        'Μεταφέρθηκε στο ιστορικό θεραπειών και στο οδοντόγραμμα.',
        InfoBarSeverity.success,
      );
    } catch (error) {
      _showMessage(
        'Δεν ολοκληρώθηκε η θεραπεία',
        error.toString(),
        InfoBarSeverity.error,
      );
    }
  }

  Future<void> _attachSignedDocument(TreatmentPlan plan) async {
    final result = await file_picker.FilePicker.pickFiles(
      type: file_picker.FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) {
      _showMessage(
        'Δεν επισυνάφθηκε το αρχείο',
        'Δεν ήταν δυνατή η ανάγνωση του αρχείου. Δοκιμάστε ξανά.',
        InfoBarSeverity.error,
      );
      return;
    }
    const maximumBytes = 15 * 1024 * 1024;
    if (file.bytes!.length > maximumBytes) {
      _showMessage(
        'Το αρχείο είναι πολύ μεγάλο',
        'Χρησιμοποιήστε PDF ή εικόνα έως 15 MB.',
        InfoBarSeverity.warning,
      );
      return;
    }
    plan.signedAttachmentName = file.name;
    plan.signedAttachmentPath = file.path ?? '';
    plan.signedAttachmentBase64 = base64Encode(file.bytes!);
    treatmentPlans.set(plan);
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Ακύρωση'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Επιβεβαίωση'),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _showMessage(String title, String content, InfoBarSeverity severity) {
    if (!mounted) return;
    displayInfoBar(
      context,
      builder: (_, close) => InfoBar(
        title: Text(title),
        content: Text(content),
        severity: severity,
        onClose: close,
      ),
    );
  }
}

class _EmptyPlans extends StatelessWidget {
  const _EmptyPlans({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 50),
        child: Column(
          children: [
            Icon(
              FluentIcons.health,
              size: 52,
              color: FluentTheme.of(context).accentColor,
            ),
            const SizedBox(height: 12),
            Text(
              'Δεν υπάρχει ακόμη σχέδιο θεραπείας',
              style: FluentTheme.of(context).typography.subtitle,
            ),
            const SizedBox(height: 6),
            const Text(
              'Δημιουργήστε διαφορετικές εναλλακτικές και παρουσιάστε τις στον ασθενή.',
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onCreate,
              child: const Text('Δημιουργία πρώτης εναλλακτικής'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersistedTextBox extends StatefulWidget {
  const _PersistedTextBox({
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.multiline = false,
    super.key,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final bool multiline;

  @override
  State<_PersistedTextBox> createState() => _PersistedTextBoxState();
}

class _PersistedTextBoxState extends State<_PersistedTextBox> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _PersistedTextBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != controller.text) {
      controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InfoLabel(
      label: widget.label,
      child: TextBox(
        controller: controller,
        enabled: widget.enabled,
        minLines: widget.multiline ? 2 : 1,
        maxLines: widget.multiline ? 4 : 1,
        onChanged: widget.onChanged,
      ),
    );
  }
}

class _TargetChip extends StatelessWidget {
  const _TargetChip({required this.label, this.onRemove});

  final String label;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F3FB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (onRemove != null) ...[
            const SizedBox(width: 5),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(FluentIcons.chrome_close, size: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _TreatmentLedgerHeader extends StatelessWidget {
  const _TreatmentLedgerHeader();

  @override
  Widget build(BuildContext context) {
    final style = FluentTheme.of(context).typography.caption?.copyWith(
          fontWeight: FontWeight.w600,
          color: Colors.grey[120],
        );
    return Container(
      color: FluentTheme.of(context).resources.subtleFillColorSecondary,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          const SizedBox(width: 34),
          Expanded(flex: 5, child: Text('Θεραπεία', style: style)),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: Text('Στόχος', style: style)),
          Expanded(child: Text('Ποσ.', style: style, textAlign: TextAlign.end)),
          Expanded(
            flex: 2,
            child: Text('Έκπτωση', style: style, textAlign: TextAlign.end),
          ),
          Expanded(
            flex: 2,
            child: Text('Σύνολο', style: style, textAlign: TextAlign.end),
          ),
          const SizedBox(width: 20),
        ],
      ),
    );
  }
}

class _PlanningLegendItem extends StatelessWidget {
  const _PlanningLegendItem({
    required this.color,
    required this.label,
    this.outlined = false,
  });

  final Color color;
  final String label;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 15,
          height: 15,
          decoration: BoxDecoration(
            color: color.withValues(alpha: outlined ? 0.22 : 0.72),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: color,
              width: outlined ? 2 : 1,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: FluentTheme.of(context).typography.caption),
      ],
    );
  }
}

class _PlanTotalPill extends StatelessWidget {
  const _PlanTotalPill({
    required this.label,
    required this.value,
    this.color = const Color(0xFF2563EB),
    this.strong = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedPlanningTooth extends StatelessWidget {
  const _SelectedPlanningTooth({required this.fdi});

  final int fdi;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: FluentTheme.of(context).accentColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: FluentTheme.of(context).accentColor.withValues(alpha: 0.45),
        ),
      ),
      child: Text('$fdi', style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

BoxDecoration _planningCardDecoration(BuildContext context) => BoxDecoration(
      color: FluentTheme.of(context).resources.cardBackgroundFillColorDefault,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey.withAlpha(45)),
    );

const _surfaceLabels = <String, String>{
  'mesial': 'Εγγύς',
  'distal': 'Άπω',
  'facial': 'Προσωπική / παρειακή',
  'oral': 'Υπερώια / γλωσσική',
  'occlusalIncisal': 'Μασητική / κοπτική',
};

String _languageLabel(TreatmentPlanLanguage language) => switch (language) {
      TreatmentPlanLanguage.el => '🇬🇷 Ελληνικά',
      TreatmentPlanLanguage.en => '🇬🇧 English',
      TreatmentPlanLanguage.de => '🇩🇪 Deutsch',
    };

String _bridgeRoleLabel(BridgeUnitRole role) => switch (role) {
      BridgeUnitRole.abutment => 'Στήριγμα',
      BridgeUnitRole.pontic => 'Ενδιάμεσο',
      BridgeUnitRole.implantAbutment => 'Επιεμφυτευματικό στήριγμα',
    };

String _removableRoleLabel(RemovableComponentRole role) => switch (role) {
      RemovableComponentRole.replacedTooth => 'Δόντι αντικατάστασης',
      RemovableComponentRole.clasp => 'Άγκιστρο',
      RemovableComponentRole.rest => 'Ερεισμα',
      RemovableComponentRole.attachment => 'Σύνδεσμος',
      RemovableComponentRole.implantSupport => 'Στήριξη εμφυτεύματος',
    };

String _archLabel(DentalArch arch) => switch (arch) {
      DentalArch.upper => 'Άνω γνάθος',
      DentalArch.lower => 'Κάτω γνάθος',
      DentalArch.both => 'Και οι δύο γνάθοι',
      DentalArch.unspecified => 'Δεν έχει οριστεί',
    };

String _consentLabel(TreatmentPlanConsentStatus status) => switch (status) {
      TreatmentPlanConsentStatus.notAgreed => 'Δεν έχει συμφωνηθεί',
      TreatmentPlanConsentStatus.verbalAgreement => 'Προφορική συμφωνία',
      TreatmentPlanConsentStatus.signedAgreement => 'Υπογεγραμμένη συμφωνία',
    };

String _money(double value) => '${value.toStringAsFixed(2)} ${currency()}';
