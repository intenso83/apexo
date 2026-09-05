import 'dart:convert';

import 'package:apexo/utils/hash.dart';

const int pocketBaseRecordIdMaxLength = 15;

class ShoppingIdMigration {
  final Map<String, String> recordsToWrite;
  final Set<String> recordIdsToDelete;
  final Map<String, int> deferred;

  const ShoppingIdMigration({
    required this.recordsToWrite,
    required this.recordIdsToDelete,
    required this.deferred,
  });

  bool get isNeeded => recordIdsToDelete.isNotEmpty;
}

/// Re-keys shopping records created by the original template, whose IDs were
/// longer than PocketBase permits. All document contents and category links
/// are retained, and the replacement records are queued for synchronization.
ShoppingIdMigration planShoppingIdMigration({
  required Map<String, String> records,
  required Map<String, int> deferred,
  required int timestamp,
}) {
  final invalidIds = records.keys
      .where((id) => id.length > pocketBaseRecordIdMaxLength)
      .toList()
    ..sort();
  if (invalidIds.isEmpty) {
    return ShoppingIdMigration(
      recordsToWrite: const {},
      recordIdsToDelete: const {},
      deferred: Map<String, int>.from(deferred),
    );
  }

  final occupiedIds = records.keys
      .where((id) => id.length <= pocketBaseRecordIdMaxLength)
      .toSet();
  final replacementIds = <String, String>{};
  for (final oldId in invalidIds) {
    var attempt = 0;
    String candidate;
    do {
      final suffix = attempt == 0 ? '' : ':$attempt';
      candidate = simpleHash(
        'shopping-record:$oldId$suffix',
        length: pocketBaseRecordIdMaxLength,
      );
      attempt++;
    } while (occupiedIds.contains(candidate));
    occupiedIds.add(candidate);
    replacementIds[oldId] = candidate;
  }

  final recordsToWrite = <String, String>{};
  for (final entry in records.entries) {
    final decoded = Map<String, dynamic>.from(jsonDecode(entry.value));
    final newId = replacementIds[entry.key] ?? entry.key;
    var changed = newId != entry.key;
    if (changed) decoded['id'] = newId;

    final oldCategoryId = decoded['categoryID']?.toString() ?? '';
    final newCategoryId = replacementIds[oldCategoryId];
    if (newCategoryId != null) {
      decoded['categoryID'] = newCategoryId;
      changed = true;
    }

    if (changed) recordsToWrite[newId] = jsonEncode(decoded);
  }

  final rewrittenDeferred = <String, int>{};
  for (final entry in deferred.entries) {
    final newKey = _rewriteDeferredKey(entry.key, replacementIds);
    final existingTimestamp = rewrittenDeferred[newKey];
    rewrittenDeferred[newKey] = existingTimestamp == null
        ? entry.value
        : (existingTimestamp > entry.value ? existingTimestamp : entry.value);
  }
  for (final id in recordsToWrite.keys) {
    rewrittenDeferred.putIfAbsent(id, () => timestamp);
  }

  return ShoppingIdMigration(
    recordsToWrite: recordsToWrite,
    recordIdsToDelete: invalidIds.toSet(),
    deferred: rewrittenDeferred,
  );
}

String _rewriteDeferredKey(
  String key,
  Map<String, String> replacementIds,
) {
  final directReplacement = replacementIds[key];
  if (directReplacement != null) return directReplacement;
  if (!key.startsWith('FILE||')) return key;

  final parts = key.split('||');
  if (parts.length < 3) return key;
  final rowReplacement = replacementIds[parts[1]];
  if (rowReplacement == null) return key;
  parts[1] = rowReplacement;
  return parts.join('||');
}
