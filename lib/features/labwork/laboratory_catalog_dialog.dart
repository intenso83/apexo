import 'package:apexo/core/multi_stream_builder.dart';
import 'package:apexo/common_widgets/button_styles.dart';
import 'package:apexo/features/expenses/expense_model.dart';
import 'package:apexo/features/expenses/expenses_store.dart';
import 'package:apexo/features/settings/settings_stores.dart';
import 'package:apexo/features/therapy_catalog/procedure_catalog_model.dart';
import 'package:apexo/features/therapy_catalog/therapy_catalog_store.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/services/login.dart';
import 'package:apexo/utils/constants.dart';
import 'package:fluent_ui/fluent_ui.dart';

Future<void> showLaboratoryCatalogDialog(
  BuildContext context, {
  String? selectedLaboratoryID,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _LaboratoryCatalogDialog(
      initialLaboratoryID: selectedLaboratoryID,
    ),
  );
}

class _LaboratoryCatalogDialog extends StatefulWidget {
  const _LaboratoryCatalogDialog({this.initialLaboratoryID});

  final String? initialLaboratoryID;

  @override
  State<_LaboratoryCatalogDialog> createState() =>
      _LaboratoryCatalogDialogState();
}

class _LaboratoryCatalogDialogState extends State<_LaboratoryCatalogDialog> {
  String selectedID = '';

  bool get canEdit => login.isAdmin || login.perm(Perm.expenses).full;

  @override
  void initState() {
    super.initState();
    selectedID = widget.initialLaboratoryID ?? '';
  }

  Future<void> _addLaboratory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: Text(txt('addLaboratory')),
        content: TextBox(
          controller: controller,
          autofocus: true,
          placeholder: txt('laboratoryName'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(txt('cancel')),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(txt('add')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !canEdit) return;
    final existing = expenses.suppliers
        .where((item) =>
            item.supplierName.trim().toLowerCase() == name.toLowerCase())
        .firstOrNull;
    final laboratory = existing ??
        Expense.fromJson({
          'isSupplier': true,
          'supplierName': name,
        });
    laboratory.isLaboratory = true;
    expenses.set(laboratory);
    setState(() => selectedID = laboratory.id);
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 760),
      title: Text(txt('laboratoryCatalogue')),
      content: SizedBox(
        width: 940,
        height: 620,
        child: MStreamBuilder(
          streams: [
            expenses.observableMap.stream,
            procedureCatalog.observableMap.stream,
            therapyGroups.observableMap.stream,
            globalSettings.observableMap.stream,
          ],
          builder: (context, _) {
            final laboratories = expenses.laboratories;
            if (!laboratories.any((item) => item.id == selectedID)) {
              selectedID = laboratories.firstOrNull?.id ?? '';
            }
            final selected = expenses.get(selectedID);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 240,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        txt('laboratoryPartners'),
                        style: FluentTheme.of(context).typography.subtitle,
                      ),
                      const SizedBox(height: 8),
                      if (canEdit)
                        FilledButton(
                          onPressed: _addLaboratory,
                          child: ButtonContent(
                            FluentIcons.add,
                            txt('addLaboratory'),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: laboratories.isEmpty
                            ? Center(child: Text(txt('noLaboratories')))
                            : ListView.separated(
                                itemCount: laboratories.length,
                                separatorBuilder: (_, __) => const Divider(),
                                itemBuilder: (context, index) {
                                  final laboratory = laboratories[index];
                                  return ListTile.selectable(
                                    selected: laboratory.id == selectedID,
                                    leading: const Icon(
                                      FluentIcons.manufacturing,
                                    ),
                                    title: Text(
                                      laboratory.supplierName,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onPressed: () => setState(
                                      () => selectedID = laboratory.id,
                                    ),
                                    onSelectionChange: (_) => setState(
                                      () => selectedID = laboratory.id,
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Divider(direction: Axis.vertical),
                const SizedBox(width: 12),
                Expanded(
                  child: selected == null
                      ? Center(child: Text(txt('selectLaboratory')))
                      : _LaboratoryEditor(
                          key: ValueKey(selected.id),
                          laboratory: selected,
                          canEdit: canEdit,
                          onRemoved: () => setState(() => selectedID = ''),
                        ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(txt('close')),
        ),
      ],
    );
  }
}

class _LaboratoryEditor extends StatefulWidget {
  const _LaboratoryEditor({
    super.key,
    required this.laboratory,
    required this.canEdit,
    required this.onRemoved,
  });

  final Expense laboratory;
  final bool canEdit;
  final VoidCallback onRemoved;

  @override
  State<_LaboratoryEditor> createState() => _LaboratoryEditorState();
}

class _LaboratoryEditorState extends State<_LaboratoryEditor> {
  late final TextEditingController name;
  late final TextEditingController contact;
  late final TextEditingController phone;
  late final TextEditingController mobile;
  late final TextEditingController email;
  late final TextEditingController address;
  String procedureSearch = '';

  @override
  void initState() {
    super.initState();
    final lab = widget.laboratory;
    name = TextEditingController(text: lab.supplierName);
    contact = TextEditingController(text: lab.supplierContactName);
    phone = TextEditingController(text: lab.supplierPhone);
    mobile = TextEditingController(text: lab.supplierMobile);
    email = TextEditingController(text: lab.supplierEmail);
    address = TextEditingController(text: lab.supplierAddress);
  }

  @override
  void dispose() {
    name.dispose();
    contact.dispose();
    phone.dispose();
    mobile.dispose();
    email.dispose();
    address.dispose();
    super.dispose();
  }

  void _saveDetails() {
    if (!widget.canEdit) return;
    final lab = widget.laboratory;
    lab.supplierName = name.text.trim();
    lab.supplierContactName = contact.text.trim();
    lab.supplierPhone = phone.text.trim();
    lab.supplierMobile = mobile.text.trim();
    lab.supplierEmail = email.text.trim();
    lab.supplierAddress = address.text.trim();
    expenses.set(lab);
  }

  _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return InfoLabel(
      label: label,
      child: TextBox(
        controller: controller,
        enabled: widget.canEdit,
        maxLines: maxLines,
        onChanged: (_) => _saveDetails(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = procedureSearch.trim().toLowerCase();
    final procedures = procedureCatalog.laboratoryProcedures
        .where((procedure) =>
            query.isEmpty ||
            procedure.title.toLowerCase().contains(query) ||
            (therapyGroups.get(procedure.therapyGroupID)?.title ?? '')
                .toLowerCase()
                .contains(query))
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                txt('laboratoryDetailsAndPrices'),
                style: FluentTheme.of(context).typography.subtitle,
              ),
            ),
            if (widget.canEdit)
              Button(
                onPressed: () {
                  widget.laboratory.isLaboratory = false;
                  expenses.set(widget.laboratory);
                  widget.onRemoved();
                },
                child: ButtonContent(
                  FluentIcons.remove_link,
                  txt('removeFromLaboratories'),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _field(txt('laboratoryName'), name),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _field(txt('contactName'), contact)),
            const SizedBox(width: 8),
            Expanded(child: _field(txt('phone'), phone)),
            const SizedBox(width: 8),
            Expanded(child: _field(txt('mobile'), mobile)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _field(txt('email'), email)),
            const SizedBox(width: 8),
            Expanded(child: _field(txt('address'), address)),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          txt('laboratoryPriceList'),
          style: FluentTheme.of(context).typography.bodyStrong,
        ),
        const SizedBox(height: 6),
        TextBox(
          placeholder: txt('catalogueSearch'),
          prefix: const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(FluentIcons.search),
          ),
          onChanged: (value) => setState(() => procedureSearch = value),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            itemCount: procedures.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) => _priceRow(procedures[index]),
          ),
        ),
      ],
    );
  }

  Widget _priceRow(ProcedureCatalogItem procedure) {
    final lab = widget.laboratory;
    final group = therapyGroups.get(procedure.therapyGroupID)?.title ?? '';
    final saved = expenses.laboratoryPrice(lab.id, procedure.id);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(procedure.title),
              Text(
                '$group · ${txt('basePrice')}: ${procedure.basePrice.toStringAsFixed(2)} ${globalSettings.currency}',
                style: FluentTheme.of(context).typography.caption,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 155,
          child: NumberBox<double>(
            value: saved,
            min: 0,
            mode: SpinButtonPlacementMode.compact,
            placeholder: txt('notSet'),
            onChanged: widget.canEdit
                ? (value) =>
                    expenses.setLaboratoryPrice(lab, procedure.id, value)
                : null,
          ),
        ),
      ],
    );
  }
}
