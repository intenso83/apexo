import 'package:apexo/common_widgets/button_styles.dart';
import 'package:apexo/core/multi_stream_builder.dart';
import 'package:apexo/features/odontogram/odontogram_assets.dart';
import 'package:apexo/features/odontogram/treatment_target.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/services/login.dart';
import 'package:fluent_ui/fluent_ui.dart';

import 'procedure_catalog_model.dart';
import 'therapy_catalog_store.dart';
import 'therapy_group_model.dart';

class TherapyCatalogScreen extends StatefulWidget {
  const TherapyCatalogScreen({super.key});

  @override
  State<TherapyCatalogScreen> createState() => _TherapyCatalogScreenState();
}

class _TherapyCatalogScreenState extends State<TherapyCatalogScreen> {
  String selectedGroupID = '';
  String search = '';

  @override
  Widget build(BuildContext context) {
    return MStreamBuilder(
      streams: [
        therapyGroups.observableMap.stream,
        procedureCatalog.observableMap.stream,
      ],
      builder: (context, _) {
        final groups = therapyGroups.ordered;
        if (selectedGroupID.isEmpty && groups.isNotEmpty) {
          selectedGroupID = groups.first.id;
        }
        final selected = therapyGroups.get(selectedGroupID);
        var procedures = selected == null
            ? <ProcedureCatalogItem>[]
            : procedureCatalog.forGroup(selected.id);
        final normalizedSearch = search.trim().toLowerCase();
        if (normalizedSearch.isNotEmpty) {
          procedures = procedures
              .where((item) =>
                  item.title.toLowerCase().contains(normalizedSearch) ||
                  item.sourceCode.toLowerCase().contains(normalizedSearch))
              .toList();
        }
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InfoBar(
                title: Text(txt('therapyCatalogueFoundation')),
                content: Text(txt('therapyCatalogueDescription')),
                severity: InfoBarSeverity.info,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 285,
                      child: _GroupPane(
                        groups: groups,
                        selectedGroupID: selectedGroupID,
                        onSelected: (id) => setState(() {
                          selectedGroupID = id;
                          search = '';
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ProcedurePane(
                        group: selected,
                        procedures: procedures,
                        search: search,
                        onSearch: (value) => setState(() => search = value),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GroupPane extends StatelessWidget {
  const _GroupPane({
    required this.groups,
    required this.selectedGroupID,
    required this.onSelected,
  });

  final List<TherapyGroup> groups;
  final String selectedGroupID;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _paneDecoration(context),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  txt('therapyGroups'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (login.isAdmin)
                IconButton(
                  icon: const Icon(FluentIcons.add),
                  onPressed: () => _showGroupDialog(context),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: groups.isEmpty
                ? Center(child: Text(txt('noTherapyGroups')))
                : ListView.separated(
                    itemCount: groups.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 5),
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      final selected = group.id == selectedGroupID;
                      return ListTile.selectable(
                        selected: selected,
                        leading: Container(
                          width: 10,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Color(group.colorValue),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        title: Text(
                          group.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${procedureCatalog.forGroup(group.id).length} ${txt('procedures').toLowerCase()}',
                        ),
                        trailing: group.hidden
                            ? const Icon(FluentIcons.hide3, size: 14)
                            : null,
                        onPressed: () => onSelected(group.id),
                        onSelectionChange: (_) => onSelected(group.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProcedurePane extends StatelessWidget {
  const _ProcedurePane({
    required this.group,
    required this.procedures,
    required this.search,
    required this.onSearch,
  });

  final TherapyGroup? group;
  final List<ProcedureCatalogItem> procedures;
  final String search;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _paneDecoration(context),
      padding: const EdgeInsets.all(12),
      child: group == null
          ? Center(child: Text(txt('noTherapyGroups')))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(group!.colorValue),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group!.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (group!.sourceID.isNotEmpty)
                            Text('DentalWin #${group!.sourceID}'),
                        ],
                      ),
                    ),
                    if (login.isAdmin) ...[
                      Button(
                        onPressed: () => _showGroupDialog(context, group!),
                        child: ButtonContent(
                          FluentIcons.edit,
                          txt('editTherapyGroup'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => _showProcedureDialog(context, group!),
                        child: ButtonContent(
                          FluentIcons.add,
                          txt('addProcedure'),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                TextBox(
                  placeholder: txt('catalogueSearch'),
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(FluentIcons.search),
                  ),
                  onChanged: onSearch,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: procedures.isEmpty
                      ? Center(child: Text(txt('noProcedures')))
                      : ListView.separated(
                          itemCount: procedures.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final item = procedures[index];
                            return ListTile(
                              title: Text(item.title),
                              subtitle: Wrap(
                                spacing: 12,
                                runSpacing: 4,
                                children: [
                                  if (item.sourceCode.isNotEmpty)
                                    Text('#${item.sourceCode}'),
                                  Text(
                                    '${txt('price')}: ${item.basePrice.toStringAsFixed(2)}',
                                  ),
                                  if (item.durationMinutes != null)
                                    Text(
                                      '${txt('duration')}: ${item.durationMinutes} min',
                                    ),
                                  Text(
                                    '${txt('toothRequired')}: ${_flag(item.toothRequired)}',
                                  ),
                                  Text(
                                    '${txt('procedureHandlingMode')}: ${_handlingLabel(item)}',
                                  ),
                                  if (procedureCatalog
                                      .handlingDecision(item)
                                      .needsReview)
                                    Text(
                                      txt('procedureHandlingNeedsReview'),
                                      style: TextStyle(
                                        color: Colors.orange.dark,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )
                                  else if (procedureCatalog
                                      .handlingDecision(item)
                                      .inferred)
                                    Text(txt('procedureHandlingSuggested')),
                                  if (item.defaultSurfaces.isNotEmpty)
                                    Text(
                                      '${txt('catalogueSurfacePreset')}: ${item.defaultSurfaces.map(_surfaceLabel).join(', ')}',
                                    ),
                                ],
                              ),
                              trailing: login.isAdmin
                                  ? IconButton(
                                      icon: const Icon(FluentIcons.edit),
                                      onPressed: () => _showProcedureDialog(
                                        context,
                                        group!,
                                        item,
                                      ),
                                    )
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  String _flag(bool? value) => value == null
      ? txt('unknownFromSource')
      : value
          ? txt('yes')
          : txt('no');

  String _handlingLabel(ProcedureCatalogItem item) => txt(
        'procedureHandling_${procedureCatalog.handlingDecision(item).mode.name}',
      );

  String _surfaceLabel(String stored) {
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

BoxDecoration _paneDecoration(BuildContext context) => BoxDecoration(
      color: FluentTheme.of(context).cardColor,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: FluentTheme.of(context).resources.cardStrokeColorDefault,
      ),
    );

String _catalogueSurfaceLabel(DentalSurface surface) {
  final key = switch (surface) {
    DentalSurface.mesial => 'surfaceMesial',
    DentalSurface.distal => 'surfaceDistal',
    DentalSurface.facial => 'surfaceFacial',
    DentalSurface.oral => 'surfaceOral',
    DentalSurface.occlusalIncisal => 'surfaceOcclusalIncisal',
    DentalSurface.wholeTooth => 'surfaceWholeTooth',
  };
  return txt(key);
}

Future<void> _showGroupDialog(
  BuildContext context, [
  TherapyGroup? existing,
]) async {
  final name = TextEditingController(text: existing?.title ?? '');
  var selectedColor = Color(existing?.colorValue ?? 0xFF0F8B8D);
  var hidden = existing?.hidden ?? false;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => ContentDialog(
        title: Text(
          existing == null ? txt('addTherapyGroup') : txt('editTherapyGroup'),
        ),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InfoLabel(
                label: txt('groupName'),
                child: TextBox(controller: name, autofocus: true),
              ),
              const SizedBox(height: 12),
              ColorPicker(
                color: selectedColor,
                onChanged: (color) => selectedColor = color,
                isAlphaEnabled: false,
                isMoreButtonVisible: false,
                isHexInputVisible: true,
                isAlphaSliderVisible: false,
                isAlphaTextInputVisible: false,
              ),
              const SizedBox(height: 8),
              Checkbox(
                checked: hidden,
                content: Text(txt('hidden')),
                onChanged: (value) =>
                    setDialogState(() => hidden = value ?? false),
              ),
            ],
          ),
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(txt('cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              final group = existing?.copy(false) ?? TherapyGroup.fromJson({});
              group.title = name.text.trim();
              group.colorValue = selectedColor.toARGB32();
              group.hidden = hidden;
              if (existing == null) {
                group.displayOrder = therapyGroups.ordered.length;
              }
              therapyGroups.set(group);
              Navigator.pop(dialogContext);
            },
            child: Text(txt('save')),
          ),
        ],
      ),
    ),
  );
  name.dispose();
}

Future<void> _showProcedureDialog(
  BuildContext context,
  TherapyGroup group, [
  ProcedureCatalogItem? existing,
]) async {
  final name = TextEditingController(text: existing?.title ?? '');
  final price = TextEditingController(
    text: existing == null ? '' : existing.basePrice.toString(),
  );
  final duration = TextEditingController(
    text: existing?.durationMinutes?.toString() ?? '',
  );
  ProcedureHandlingMode? handlingMode = existing == null
      ? null
      : procedureCatalog.handlingDecision(existing).mode;
  final defaultSurfaces = <DentalSurface>{
    ...DentalSurface.values.where(
      (surface) => existing?.defaultSurfaces.contains(surface.name) ?? false,
    ),
  };
  var hidden = existing?.hidden ?? false;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => ContentDialog(
        title: Text(
          existing == null ? txt('addProcedure') : txt('editProcedure'),
        ),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InfoLabel(
                  label: txt('procedureName'),
                  child: TextBox(controller: name, autofocus: true),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: InfoLabel(
                        label: txt('price'),
                        child: TextBox(controller: price),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InfoLabel(
                        label: '${txt('duration')} (min)',
                        child: TextBox(controller: duration),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                InfoLabel(
                  label: '${txt('procedureHandlingMode')} *',
                  child: ComboBox<ProcedureHandlingMode>(
                    key: const Key('procedure-handling-mode'),
                    value: handlingMode,
                    isExpanded: true,
                    placeholder: Text(txt('procedureHandlingChoose')),
                    items: ProcedureHandlingMode.values
                        .map(
                          (mode) => ComboBoxItem(
                            value: mode,
                            child: Text(txt('procedureHandling_${mode.name}')),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setDialogState(() {
                      handlingMode = value;
                      if (value != ProcedureHandlingMode.surfaceBased) {
                        defaultSurfaces.clear();
                      }
                    }),
                  ),
                ),
                if (handlingMode != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    txt('procedureHandlingDescription_${handlingMode!.name}'),
                    style: FluentTheme.of(context).typography.caption,
                  ),
                ] else ...[
                  const SizedBox(height: 6),
                  Text(
                    txt('procedureHandlingRequired'),
                    style: TextStyle(color: Colors.orange.dark),
                  ),
                ],
                if (handlingMode == ProcedureHandlingMode.surfaceBased) ...[
                  const SizedBox(height: 10),
                  Text(txt('catalogueSurfacePreset')),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      ToggleButton(
                        checked: defaultSurfaces.isEmpty,
                        onChanged: (_) => setDialogState(defaultSurfaces.clear),
                        child: Text(txt('surfaceUnspecified')),
                      ),
                      ...DentalSurface.values
                          .where(
                            (surface) => surface != DentalSurface.wholeTooth,
                          )
                          .map(
                            (surface) => ToggleButton(
                              checked: defaultSurfaces.contains(surface),
                              onChanged: (selected) => setDialogState(() {
                                if (selected) {
                                  defaultSurfaces.add(surface);
                                } else {
                                  defaultSurfaces.remove(surface);
                                }
                              }),
                              child: Text(_catalogueSurfaceLabel(surface)),
                            ),
                          ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    txt('catalogueSurfacePresetDescription'),
                    style: FluentTheme.of(context).typography.caption,
                  ),
                ],
                const SizedBox(height: 8),
                Checkbox(
                  checked: hidden,
                  content: Text(txt('hidden')),
                  onChanged: (value) =>
                      setDialogState(() => hidden = value ?? false),
                ),
              ],
            ),
          ),
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(txt('cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty || handlingMode == null) return;
              final item = existing?.copy(false) ??
                  ProcedureCatalogItem.fromJson(<String, dynamic>{});
              item.title = name.text.trim();
              item.therapyGroupID = group.id;
              item.basePrice = double.tryParse(
                    price.text.trim().replaceAll(',', '.'),
                  ) ??
                  0;
              item.durationMinutes = int.tryParse(duration.text.trim());
              item.defaultSurfaces =
                  defaultSurfaces.map((surface) => surface.name).toList();
              item.applyHandlingMode(handlingMode!);
              item.hidden = hidden;
              procedureCatalog.set(item);
              Navigator.pop(dialogContext);
            },
            child: Text(txt('save')),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  price.dispose();
  duration.dispose();
}
