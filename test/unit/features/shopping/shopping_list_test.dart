import 'dart:convert';

import 'package:apexo/features/shopping/shopping_id_migration.dart';
import 'package:apexo/features/shopping/shopping_item_model.dart';
import 'package:apexo/features/shopping/shopping_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shopping material preserves state and exposes the selected variant',
      () {
    final item = ShoppingItem.fromJson({
      'id': 'gloves',
      'title': 'Γάντια',
      'categoryID': 'consumables',
      'variants': ['Medium', 'Small'],
      'selectedVariant': 'Small',
      'needed': true,
      'priority': 'urgent',
      'quantity': '2 boxes',
    });

    expect(item.displayName, 'Γάντια — Small');
    expect(item.priority, ShoppingPriority.urgent);
    expect(ShoppingItem.fromJson(item.toJson()).toJson(), item.toJson());
  });

  test('workbook template groups glove sizes as variants and starts clean', () {
    final template = buildShoppingTemplate();
    final categories = template.where((item) => item.isCategory).toList();
    final gloves = template.singleWhere((item) => item.title == 'Γάντια');

    expect(categories.map((item) => item.title), contains('Αναλώσιμα'));
    expect(gloves.variants, ['Medium', 'Small']);
    expect(gloves.selectedVariant, isEmpty);
    expect(gloves.needed, isFalse);
    expect(gloves.priority, ShoppingPriority.normal);
    expect(
      template.map((item) => item.id).toSet().length,
      template.length,
      reason: 'stable template IDs must remain unique',
    );
    expect(
      template.every((item) => item.id.length <= 15),
      isTrue,
      reason: 'PocketBase record IDs may contain no more than 15 characters',
    );
  });

  test('legacy shopping IDs are re-keyed without losing state or links', () {
    const categoryId = 'category-id-is-17';
    const itemId = 'material-id-is-017';
    final migration = planShoppingIdMigration(
      records: {
        categoryId: jsonEncode({
          'id': categoryId,
          'title': 'Αναλώσιμα',
          'isCategory': true,
        }),
        itemId: jsonEncode({
          'id': itemId,
          'title': 'Γάντια',
          'categoryID': categoryId,
          'variants': ['Medium', 'Small'],
          'selectedVariant': 'Small',
          'needed': true,
          'priority': 'urgent',
        }),
      },
      deferred: {categoryId: 10, itemId: 20},
      timestamp: 30,
    );

    expect(migration.isNeeded, isTrue);
    expect(migration.recordIdsToDelete, {categoryId, itemId});
    expect(
      migration.recordsToWrite.keys.every((id) => id.length <= 15),
      isTrue,
    );
    expect(migration.deferred.keys, migration.recordsToWrite.keys);

    final migrated = migration.recordsToWrite.values
        .map((json) => ShoppingItem.fromJson(jsonDecode(json)))
        .toList();
    final category = migrated.singleWhere((item) => item.isCategory);
    final gloves = migrated.singleWhere((item) => !item.isCategory);
    expect(gloves.categoryID, category.id);
    expect(gloves.displayName, 'Γάντια — Small');
    expect(gloves.needed, isTrue);
    expect(gloves.priority, ShoppingPriority.urgent);
  });
}
