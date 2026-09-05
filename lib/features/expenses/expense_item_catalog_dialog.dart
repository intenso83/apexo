import 'package:apexo/core/multi_stream_builder.dart';
import 'package:apexo/common_widgets/button_styles.dart';
import 'package:apexo/features/expenses/expense_model.dart';
import 'package:apexo/features/expenses/expenses_store.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/services/login.dart';
import 'package:apexo/utils/constants.dart';
import 'package:fluent_ui/fluent_ui.dart';

Future<void> showExpenseItemCatalogDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _ExpenseItemCatalogDialog(),
  );
}

class _ExpenseItemCatalogDialog extends StatefulWidget {
  const _ExpenseItemCatalogDialog();

  @override
  State<_ExpenseItemCatalogDialog> createState() =>
      _ExpenseItemCatalogDialogState();
}

class _ExpenseItemCatalogDialogState extends State<_ExpenseItemCatalogDialog> {
  final controller = TextEditingController();
  String search = '';

  bool get canEdit => login.isAdmin || login.perm(Perm.expenses).full;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _add() {
    final name = controller.text.trim();
    if (!canEdit || name.isEmpty) return;
    final exists = expenses.catalogueItems.any(
      (item) => item.catalogueItemName.toLowerCase() == name.toLowerCase(),
    );
    if (!exists) {
      expenses.set(Expense.fromJson({
        'isCatalogueItem': true,
        'catalogueItemName': name,
      }));
    }
    controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 600, maxHeight: 620),
      title: Text(txt('expenseItemCatalogue')),
      content: SizedBox(
        width: 520,
        height: 470,
        child: MStreamBuilder(
          streams: [expenses.observableMap.stream],
          builder: (context, _) {
            final query = search.trim().toLowerCase();
            final items = expenses.catalogueItems
                .where((item) =>
                    query.isEmpty ||
                    item.catalogueItemName.toLowerCase().contains(query))
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  txt('expenseItemCatalogueDesc'),
                  style: FluentTheme.of(context).typography.caption,
                ),
                const SizedBox(height: 12),
                if (canEdit)
                  Row(
                    children: [
                      Expanded(
                        child: TextBox(
                          controller: controller,
                          placeholder: txt('newExpenseItem'),
                          onSubmitted: (_) => _add(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _add,
                        child: ButtonContent(
                          FluentIcons.add,
                          txt('add'),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),
                TextBox(
                  placeholder: txt('searchPlaceholder'),
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(FluentIcons.search),
                  ),
                  onChanged: (value) => setState(() => search = value),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: items.isEmpty
                      ? Center(child: Text(txt('noResultsFound')))
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return ListTile(
                              title: Text(item.catalogueItemName),
                              leading: const Icon(FluentIcons.product_catalog),
                              trailing: canEdit
                                  ? IconButton(
                                      icon: const Icon(FluentIcons.delete),
                                      onPressed: () =>
                                          expenses.archive(item.id),
                                    )
                                  : null,
                            );
                          },
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
