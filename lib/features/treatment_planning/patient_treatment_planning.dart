import 'dart:convert';

import 'package:apexo/core/multi_stream_builder.dart';
import 'package:apexo/features/odontogram/treatment_target.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/settings/settings_stores.dart';
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
  String? selectedGroupID;
  String? selectedProcedureID;
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
            globalSettings.observableMap.stream,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPlanIdentity(plan),
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
        else
          ...plan.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildPlanItem(plan, item),
              )),
        const SizedBox(height: 2),
        _buildDiscountAndSummary(plan),
        const SizedBox(height: 10),
        _buildConsent(plan),
        const SizedBox(height: 10),
        _buildPlanActions(plan),
        const SizedBox(height: 30),
      ],
    );
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

  Widget _buildCatalogueComposer(
    TreatmentPlan plan,
    TreatmentCatalogueTranslations translations,
  ) {
    final groups =
        therapyGroups.ordered.where((group) => !group.hidden).toList();
    if (selectedGroupID == null && groups.isNotEmpty) {
      selectedGroupID = groups.first.id;
    }
    final procedures = procedureCatalog
        .forGroup(selectedGroupID ?? '')
        .where((procedure) => !procedure.hidden)
        .toList();
    if (selectedProcedureID == null ||
        !procedures.any((procedure) => procedure.id == selectedProcedureID)) {
      selectedProcedureID = procedures.isEmpty ? null : procedures.first.id;
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
                  child: ComboBox<String>(
                    key: const Key('treatment-plan-procedure-picker'),
                    isExpanded: true,
                    value: selectedProcedureID,
                    items: procedures
                        .map((procedure) => ComboBoxItem<String>(
                              value: procedure.id,
                              child: Text(translations.procedureName(
                                procedure,
                                plan.language,
                              )),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => selectedProcedureID = value),
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
    return Expander(
      key: ValueKey('treatment-plan-item-${item.id}'),
      initiallyExpanded: !completed,
      header: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayName(plan.language),
                  style: FluentTheme.of(context).typography.bodyStrong,
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.quantity} × ${_money(item.unitPrice)} · ${_money(item.net)}',
                  style: TextStyle(
                    color: Colors.grey[110],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color:
                  completed ? const Color(0xFFE2F6EF) : const Color(0xFFE8F3FB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(completed ? 'Ολοκληρωμένο' : 'Προγραμματισμένο'),
          ),
        ],
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _numberField(
                label: 'Ποσότητα',
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
                label: 'Έκπτωση γραμμής % (εσωτερικό)',
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
                label: 'Σταθερή έκπτωση (${currency()}) (εσωτερικό)',
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
          const SizedBox(height: 12),
          _buildTargetEditor(plan, item, completed),
          const SizedBox(height: 10),
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
          const SizedBox(height: 12),
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
                      Text('Μεταφορά ως ολοκληρωμένη θεραπεία'),
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
            SizedBox(
              width: 220,
              child: InfoLabel(
                label: 'Δόντι (FDI)',
                child: ComboBox<int>(
                  key: ValueKey('plan-item-tooth-${item.id}'),
                  isExpanded: true,
                  value: item.toothFdi,
                  items: _permanentTeeth
                      .map((fdi) => ComboBoxItem<int>(
                            value: fdi,
                            child: Text('$fdi'),
                          ))
                      .toList(),
                  onChanged: completed
                      ? null
                      : (value) {
                          item.toothFdi = value;
                          treatmentPlans.set(plan);
                        },
                ),
              ),
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
    final draftTooth = bridgeDraftTooth[item.id] ?? 11;
    final draftRole = bridgeDraftRole[item.id] ?? BridgeUnitRole.abutment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const InfoBar(
          title: Text('Χαρτογράφηση γέφυρας'),
          content: Text(
            'Χρειάζεται τουλάχιστον ένα στήριγμα και ένα ενδιάμεσο. Η χαρτογράφηση μεταφέρεται αυτούσια στο οδοντόγραμμα.',
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
                  label: 'Δόντι',
                  child: ComboBox<int>(
                    value: draftTooth,
                    isExpanded: true,
                    items: _permanentTeeth
                        .map((fdi) => ComboBoxItem<int>(
                              value: fdi,
                              child: Text('$fdi'),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() {
                      bridgeDraftTooth[item.id] = value ?? 11;
                    }),
                  ),
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
    final draftTooth = removableDraftTooth[item.id] ?? 11;
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
                  label: 'Δόντι',
                  child: ComboBox<int>(
                    value: draftTooth,
                    isExpanded: true,
                    items: _permanentTeeth
                        .map((fdi) => ComboBoxItem<int>(
                              value: fdi,
                              child: Text('$fdi'),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() {
                      removableDraftTooth[item.id] = value ?? 11;
                    }),
                  ),
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
    required ValueChanged<double?>? onChanged,
  }) {
    return SizedBox(
      width: 220,
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
    plan.items.add(item);
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

const _permanentTeeth = <int>[
  18,
  17,
  16,
  15,
  14,
  13,
  12,
  11,
  21,
  22,
  23,
  24,
  25,
  26,
  27,
  28,
  48,
  47,
  46,
  45,
  44,
  43,
  42,
  41,
  31,
  32,
  33,
  34,
  35,
  36,
  37,
  38,
];

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
