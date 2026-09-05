import 'dart:async';

import 'package:apexo/common_widgets/button_styles.dart';
import 'package:apexo/core/multi_stream_builder.dart';
import 'package:apexo/features/shopping/shopping_item_model.dart';
import 'package:apexo/features/shopping/shopping_store.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  String search = '';
  String selectedCategoryID = '';
  bool neededOnly = false;

  @override
  Widget build(BuildContext context) {
    return MStreamBuilder(
      streams: [shoppingList.observableMap.stream],
      builder: (context, _) {
        final categories = shoppingList.categories;
        if (selectedCategoryID.isNotEmpty &&
            !categories.any((item) => item.id == selectedCategoryID)) {
          selectedCategoryID = '';
        }
        final query = search.trim().toLowerCase();
        final materials = shoppingList.materials.where((item) {
          if (selectedCategoryID.isNotEmpty &&
              item.categoryID != selectedCategoryID) {
            return false;
          }
          if (neededOnly && !item.needed) return false;
          if (query.isEmpty) return true;
          return item.title.toLowerCase().contains(query) ||
              item.selectedVariant.toLowerCase().contains(query) ||
              item.variants
                  .any((variant) => variant.toLowerCase().contains(query)) ||
              item.notes.toLowerCase().contains(query) ||
              shoppingList
                  .categoryTitle(item.categoryID)
                  .toLowerCase()
                  .contains(query);
        }).toList();

        return Column(
          key: WK.shoppingListScreen,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildToolbar(context, categories),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final urgent = _UrgentPane(items: shoppingList.urgent);
                  final table = _ShoppingTable(materials: materials);
                  if (constraints.maxWidth < 900) {
                    return Column(
                      children: [
                        SizedBox(height: 210, child: urgent),
                        const Divider(),
                        Expanded(child: table),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: table),
                      const Divider(direction: Axis.vertical),
                      SizedBox(width: 315, child: urgent),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildToolbar(
    BuildContext context,
    List<ShoppingItem> categories,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      color: FluentTheme.of(context).cardColor,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton(
            onPressed: categories.isEmpty
                ? null
                : () => showShoppingItemDialog(
                      context,
                      preferredCategoryID: selectedCategoryID,
                    ),
            child: ButtonContent(FluentIcons.add, txt('addShoppingItem')),
          ),
          Button(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const _CategoryManagerDialog(),
            ),
            child: ButtonContent(
              FluentIcons.product_catalog,
              txt('manageShoppingCategories'),
            ),
          ),
          SizedBox(
            width: 220,
            child: ComboBox<String>(
              value: selectedCategoryID,
              isExpanded: true,
              items: [
                ComboBoxItem(
                  value: '',
                  child: Text(txt('allShoppingCategories')),
                ),
                ...categories.map(
                  (category) => ComboBoxItem(
                    value: category.id,
                    child: Text(category.title),
                  ),
                ),
              ],
              onChanged: (value) =>
                  setState(() => selectedCategoryID = value ?? ''),
            ),
          ),
          SizedBox(
            width: 260,
            child: TextBox(
              placeholder: txt('searchPlaceholder'),
              prefix: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(FluentIcons.search),
              ),
              onChanged: (value) => setState(() => search = value),
            ),
          ),
          Checkbox(
            checked: neededOnly,
            content: Text(txt('showNeededOnly')),
            onChanged: (value) => setState(() => neededOnly = value ?? false),
          ),
        ],
      ),
    );
  }
}

class _ShoppingTable extends StatelessWidget {
  const _ShoppingTable({required this.materials});

  final List<ShoppingItem> materials;

  @override
  Widget build(BuildContext context) {
    if (materials.isEmpty) {
      return Center(child: Text(txt('noShoppingItems')));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 1100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _ShoppingTableHeader(),
            Expanded(
              child: ListView.builder(
                itemCount: materials.length,
                itemExtent: 62,
                itemBuilder: (context, index) => _ShoppingMaterialRow(
                  key: ValueKey(materials[index].id),
                  item: materials[index],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShoppingTableHeader extends StatelessWidget {
  const _ShoppingTableHeader();

  @override
  Widget build(BuildContext context) {
    final style = FluentTheme.of(context)
        .typography
        .caption
        ?.copyWith(fontWeight: FontWeight.w600);
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: FluentTheme.of(context).resources.subtleFillColorSecondary,
      child: Row(
        children: [
          _cell(42, const SizedBox()),
          _cell(228, Text(txt('shoppingMaterial'), style: style)),
          _cell(160, Text(txt('shoppingVariant'), style: style)),
          _cell(145, Text(txt('shoppingCategory'), style: style)),
          _cell(105, Text(txt('quantity'), style: style)),
          _cell(130, Text(txt('shoppingPriority'), style: style)),
          _cell(210, Text(txt('notes'), style: style)),
          _cell(64, const SizedBox()),
        ],
      ),
    );
  }
}

class _ShoppingMaterialRow extends StatefulWidget {
  const _ShoppingMaterialRow({super.key, required this.item});

  final ShoppingItem item;

  @override
  State<_ShoppingMaterialRow> createState() => _ShoppingMaterialRowState();
}

class _ShoppingMaterialRowState extends State<_ShoppingMaterialRow> {
  late final TextEditingController quantity;
  late final TextEditingController notes;
  Timer? saveTimer;

  @override
  void initState() {
    super.initState();
    quantity = TextEditingController(text: widget.item.quantity);
    notes = TextEditingController(text: widget.item.notes);
  }

  @override
  void didUpdateWidget(covariant _ShoppingMaterialRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.quantity != widget.item.quantity &&
        quantity.text != widget.item.quantity) {
      quantity.text = widget.item.quantity;
    }
    if (oldWidget.item.notes != widget.item.notes &&
        notes.text != widget.item.notes) {
      notes.text = widget.item.notes;
    }
  }

  @override
  void dispose() {
    saveTimer?.cancel();
    quantity.dispose();
    notes.dispose();
    super.dispose();
  }

  void _update(void Function(ShoppingItem copy) change) {
    final copy = widget.item.copy(false);
    change(copy);
    shoppingList.set(copy);
  }

  void _saveTextSoon() {
    saveTimer?.cancel();
    saveTimer = Timer(const Duration(milliseconds: 450), () {
      _update((copy) {
        copy.quantity = quantity.text.trim();
        copy.notes = notes.text.trim();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final background = switch (item.priority) {
      ShoppingPriority.urgent => Colors.red.withValues(alpha: 0.08),
      ShoppingPriority.soon => Colors.yellow.withValues(alpha: 0.22),
      ShoppingPriority.normal => Colors.transparent,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        border: Border(
          bottom: BorderSide(
            color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
          ),
        ),
      ),
      child: Row(
        children: [
          _cell(
            42,
            Checkbox(
              checked: item.needed,
              onChanged: (value) =>
                  _update((copy) => copy.needed = value ?? false),
            ),
          ),
          _cell(
            228,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight:
                        item.needed ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (item.selectedVariant.isNotEmpty)
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FluentTheme.of(context).typography.caption,
                  ),
              ],
            ),
          ),
          _cell(
            160,
            item.variants.isEmpty
                ? Text(
                    txt('noVariants'),
                    style: FluentTheme.of(context).typography.caption,
                  )
                : ComboBox<String>(
                    value: item.variants.contains(item.selectedVariant)
                        ? item.selectedVariant
                        : '',
                    isExpanded: true,
                    items: [
                      ComboBoxItem(
                          value: '', child: Text(txt('selectVariant'))),
                      ...item.variants.map(
                        (variant) => ComboBoxItem(
                          value: variant,
                          child: Text(variant),
                        ),
                      ),
                    ],
                    onChanged: (value) => _update(
                      (copy) => copy.selectedVariant = value ?? '',
                    ),
                  ),
          ),
          _cell(
            145,
            ComboBox<String>(
              value: shoppingList.categories
                      .any((category) => category.id == item.categoryID)
                  ? item.categoryID
                  : null,
              isExpanded: true,
              items: shoppingList.categories
                  .map(
                    (category) => ComboBoxItem(
                      value: category.id,
                      child: Text(
                        category.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                _update((copy) {
                  copy.categoryID = value;
                  copy.displayOrder = shoppingList.nextOrder(value);
                });
              },
            ),
          ),
          _cell(
            105,
            TextBox(
              controller: quantity,
              placeholder: txt('quantity'),
              onChanged: (_) => _saveTextSoon(),
            ),
          ),
          _cell(
            130,
            _PriorityButtons(
              value: item.priority,
              onChanged: (value) => _update((copy) => copy.priority = value),
            ),
          ),
          _cell(
            210,
            TextBox(
              controller: notes,
              placeholder: txt('notes'),
              onChanged: (_) => _saveTextSoon(),
            ),
          ),
          _cell(
            64,
            Row(
              children: [
                IconButton(
                  icon: const Icon(FluentIcons.edit, size: 15),
                  onPressed: () => showShoppingItemDialog(
                    context,
                    existing: item,
                  ),
                ),
                IconButton(
                  icon: const Icon(FluentIcons.delete, size: 15),
                  onPressed: () => _confirmDeleteItem(context, item),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityButtons extends StatelessWidget {
  const _PriorityButtons({required this.value, required this.onChanged});

  final ShoppingPriority value;
  final ValueChanged<ShoppingPriority> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _priorityButton(
          context,
          ShoppingPriority.normal,
          Colors.grey,
          txt('priorityNormal'),
        ),
        _priorityButton(
          context,
          ShoppingPriority.soon,
          Colors.yellow,
          txt('prioritySoon'),
        ),
        _priorityButton(
          context,
          ShoppingPriority.urgent,
          Colors.red,
          txt('priorityUrgent'),
        ),
      ],
    );
  }

  Widget _priorityButton(
    BuildContext context,
    ShoppingPriority priority,
    Color color,
    String tooltip,
  ) {
    final selected = value == priority;
    return Tooltip(
      message: tooltip,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: IconButton(
          icon: Icon(
            selected ? FluentIcons.circle_fill : FluentIcons.circle_ring,
            size: 15,
            color: color,
          ),
          onPressed: () => onChanged(priority),
        ),
      ),
    );
  }
}

class _UrgentPane extends StatelessWidget {
  const _UrgentPane({required this.items});

  final List<ShoppingItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.red.withValues(alpha: 0.055),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(FluentIcons.warning, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${txt('urgentShoppingList')} (${items.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            txt('urgentShoppingListDescription'),
            style: FluentTheme.of(context).typography.caption,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: items.isEmpty
                ? Center(child: Text(txt('noUrgentShoppingItems')))
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        leading: Checkbox(
                          checked: true,
                          onChanged: (value) {
                            final copy = item.copy(false)
                              ..needed = value ?? false;
                            shoppingList.set(copy);
                          },
                        ),
                        title: Text(
                          item.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          [
                            if (item.quantity.isNotEmpty) item.quantity,
                            shoppingList.categoryTitle(item.categoryID),
                          ].join(' · '),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

Widget _cell(double width, Widget child) => SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: child,
      ),
    );

Future<void> showShoppingItemDialog(
  BuildContext context, {
  ShoppingItem? existing,
  String preferredCategoryID = '',
}) async {
  final categories = shoppingList.categories;
  if (categories.isEmpty) return;
  final name = TextEditingController(text: existing?.title ?? '');
  final variants = TextEditingController(
    text: existing?.variants.join(', ') ?? '',
  );
  final quantity = TextEditingController(text: existing?.quantity ?? '');
  final notes = TextEditingController(text: existing?.notes ?? '');
  var categoryID = existing?.categoryID ?? preferredCategoryID;
  if (!categories.any((category) => category.id == categoryID)) {
    categoryID = categories.first.id;
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => ContentDialog(
        title: Text(
          existing == null ? txt('addShoppingItem') : txt('editShoppingItem'),
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InfoLabel(
                  label: txt('shoppingCategory'),
                  child: ComboBox<String>(
                    value: categoryID,
                    isExpanded: true,
                    items: categories
                        .map(
                          (category) => ComboBoxItem(
                            value: category.id,
                            child: Text(category.title),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setDialogState(
                      () => categoryID = value ?? categoryID,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                InfoLabel(
                  label: txt('shoppingMaterial'),
                  child: TextBox(controller: name, autofocus: true),
                ),
                const SizedBox(height: 10),
                InfoLabel(
                  label: txt('shoppingVariants'),
                  child: TextBox(
                    controller: variants,
                    placeholder: txt('shoppingVariantsHint'),
                  ),
                ),
                const SizedBox(height: 10),
                InfoLabel(
                  label: txt('quantity'),
                  child: TextBox(controller: quantity),
                ),
                const SizedBox(height: 10),
                InfoLabel(
                  label: txt('notes'),
                  child: TextBox(controller: notes, maxLines: 3),
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
              final title = name.text.trim();
              if (title.isEmpty) return;
              final parsedVariants = variants.text
                  .split(RegExp(r'[,;\n]'))
                  .map((value) => value.trim())
                  .where((value) => value.isNotEmpty)
                  .toSet()
                  .toList();
              final item = existing?.copy(false) ?? ShoppingItem.fromJson({});
              item.title = title;
              item.categoryID = categoryID;
              item.variants = parsedVariants;
              if (!parsedVariants.contains(item.selectedVariant)) {
                item.selectedVariant = '';
              }
              item.quantity = quantity.text.trim();
              item.notes = notes.text.trim();
              if (existing == null) {
                item.displayOrder = shoppingList.nextOrder(categoryID);
              }
              shoppingList.set(item);
              Navigator.pop(dialogContext);
            },
            child: Text(txt('save')),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  variants.dispose();
  quantity.dispose();
  notes.dispose();
}

Future<void> _confirmDeleteItem(
  BuildContext context,
  ShoppingItem item,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => ContentDialog(
      title: Text(txt('deleteShoppingItem')),
      content:
          Text('${txt('deleteShoppingItemQuestion')}\n${item.displayName}'),
      actions: [
        Button(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(txt('cancel')),
        ),
        FilledButton(
          onPressed: () {
            shoppingList.archive(item.id);
            Navigator.pop(dialogContext);
          },
          child: Text(txt('delete')),
        ),
      ],
    ),
  );
}

class _CategoryManagerDialog extends StatefulWidget {
  const _CategoryManagerDialog();

  @override
  State<_CategoryManagerDialog> createState() => _CategoryManagerDialogState();
}

class _CategoryManagerDialogState extends State<_CategoryManagerDialog> {
  final name = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  void _add() {
    final title = name.text.trim();
    if (title.isEmpty) return;
    final duplicate = shoppingList.categories.any(
      (category) => category.title.toLowerCase() == title.toLowerCase(),
    );
    if (!duplicate) {
      shoppingList.set(ShoppingItem.fromJson({
        'title': title,
        'isCategory': true,
        'displayOrder': shoppingList.categories.length,
      }));
    }
    name.clear();
  }

  Future<void> _rename(ShoppingItem category) async {
    final controller = TextEditingController(text: category.title);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: Text(txt('editShoppingCategory')),
        content: TextBox(controller: controller, autofocus: true),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(txt('cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              final copy = category.copy(false)..title = controller.text.trim();
              shoppingList.set(copy);
              Navigator.pop(dialogContext);
            },
            child: Text(txt('save')),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _delete(ShoppingItem category) async {
    final count = shoppingList.forCategory(category.id).length;
    if (count > 0) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => ContentDialog(
          title: Text(txt('shoppingCategoryInUse')),
          content: Text(txt('shoppingCategoryInUseDescription')),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(txt('close')),
            ),
          ],
        ),
      );
      return;
    }
    shoppingList.archive(category.id);
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 560, maxHeight: 650),
      title: Text(txt('manageShoppingCategories')),
      content: SizedBox(
        width: 480,
        height: 480,
        child: MStreamBuilder(
          streams: [shoppingList.observableMap.stream],
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextBox(
                      controller: name,
                      placeholder: txt('newShoppingCategory'),
                      onSubmitted: (_) => _add(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _add,
                    child: ButtonContent(FluentIcons.add, txt('add')),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: shoppingList.categories.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final category = shoppingList.categories[index];
                    final count = shoppingList.forCategory(category.id).length;
                    return ListTile(
                      leading: const Icon(FluentIcons.folder),
                      title: Text(category.title),
                      subtitle: Text('$count ${txt('shoppingItems')}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(FluentIcons.edit),
                            onPressed: () => _rename(category),
                          ),
                          IconButton(
                            icon: const Icon(FluentIcons.delete),
                            onPressed: () => _delete(category),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
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
