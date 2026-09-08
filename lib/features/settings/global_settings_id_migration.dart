import 'dart:convert';

const int pocketBaseRecordIdMaxLength = 15;

const String googleCalendarIdSettingKey = 'gcal_calendarid';
const String legacyGoogleCalendarIdSettingKey = 'gcal_calendar_id';

class GlobalSettingsIdMigration {
  final Map<String, String> recordsToWrite;
  final Set<String> recordIdsToDelete;
  final Map<String, int> deferred;

  const GlobalSettingsIdMigration({
    required this.recordsToWrite,
    required this.recordIdsToDelete,
    required this.deferred,
  });

  bool get isNeeded => recordIdsToDelete.isNotEmpty;
}

/// Re-keys the original Google Calendar ID setting, whose 16-character key
/// cannot be used as a PocketBase record ID. Existing values are retained and
/// the valid replacement is queued before the store's first remote request.
GlobalSettingsIdMigration planGlobalSettingsIdMigration({
  required Map<String, String> records,
  required Map<String, int> deferred,
  required int timestamp,
}) {
  final hasLegacyRecord = records.containsKey(
    legacyGoogleCalendarIdSettingKey,
  );
  final hasLegacyDeferred = deferred.containsKey(
    legacyGoogleCalendarIdSettingKey,
  );
  if (!hasLegacyRecord && !hasLegacyDeferred) {
    return GlobalSettingsIdMigration(
      recordsToWrite: const {},
      recordIdsToDelete: const {},
      deferred: Map<String, int>.from(deferred),
    );
  }

  final rewrittenDeferred = Map<String, int>.from(deferred);
  final legacyTimestamp =
      rewrittenDeferred.remove(legacyGoogleCalendarIdSettingKey);
  final recordsToWrite = <String, String>{};

  if (!records.containsKey(googleCalendarIdSettingKey) && hasLegacyRecord) {
    final decoded = Map<String, dynamic>.from(
      jsonDecode(records[legacyGoogleCalendarIdSettingKey]!),
    );
    decoded['id'] = googleCalendarIdSettingKey;
    recordsToWrite[googleCalendarIdSettingKey] = jsonEncode(decoded);

    final replacementTimestamp = rewrittenDeferred[googleCalendarIdSettingKey];
    final migratedTimestamp = legacyTimestamp ?? timestamp;
    rewrittenDeferred[googleCalendarIdSettingKey] =
        replacementTimestamp == null || migratedTimestamp > replacementTimestamp
            ? migratedTimestamp
            : replacementTimestamp;
  } else if (records.containsKey(googleCalendarIdSettingKey) &&
      legacyTimestamp != null) {
    final replacementTimestamp = rewrittenDeferred[googleCalendarIdSettingKey];
    rewrittenDeferred[googleCalendarIdSettingKey] =
        replacementTimestamp == null || legacyTimestamp > replacementTimestamp
            ? legacyTimestamp
            : replacementTimestamp;
  }

  return GlobalSettingsIdMigration(
    recordsToWrite: recordsToWrite,
    recordIdsToDelete: const {legacyGoogleCalendarIdSettingKey},
    deferred: rewrittenDeferred,
  );
}
