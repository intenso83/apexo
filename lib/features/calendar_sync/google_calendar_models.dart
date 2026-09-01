enum GoogleCalendarSyncDirection {
  apexoToGoogle,
  twoWay;

  static GoogleCalendarSyncDirection parse(String value) =>
      GoogleCalendarSyncDirection.values.firstWhere(
        (item) => item.name == value,
        orElse: () => GoogleCalendarSyncDirection.twoWay,
      );
}

enum GoogleCalendarTitleMode {
  generic,
  patientName;

  static GoogleCalendarTitleMode parse(String value) =>
      GoogleCalendarTitleMode.values.firstWhere(
        (item) => item.name == value,
        orElse: () => GoogleCalendarTitleMode.generic,
      );
}

class GoogleCalendarSyncPreferences {
  final bool enabled;
  final String calendarId;
  final String clinicId;
  final String accountId;
  final GoogleCalendarSyncDirection direction;
  final GoogleCalendarTitleMode titleMode;
  final bool includePhone;
  final bool includeMobile;
  final bool includeEmail;
  final bool includeAddress;
  final int pastDays;
  final int futureDays;

  const GoogleCalendarSyncPreferences({
    required this.enabled,
    required this.calendarId,
    required this.clinicId,
    required this.accountId,
    this.direction = GoogleCalendarSyncDirection.twoWay,
    this.titleMode = GoogleCalendarTitleMode.generic,
    this.includePhone = true,
    this.includeMobile = true,
    this.includeEmail = true,
    this.includeAddress = false,
    this.pastDays = 90,
    this.futureDays = 365,
  });
}

/// Non-secret Google Calendar preferences for one signed-in Apexo account.
///
/// Instances are stored under the Apexo account ID. OAuth tokens themselves
/// must live in platform-secure storage; [credentialReference] is only an
/// opaque lookup key for that future secure store.
class GoogleCalendarUserSettings {
  final bool syncEnabled;
  final String googleAccountEmail;
  final String credentialReference;
  final String calendarId;
  final GoogleCalendarSyncDirection direction;
  final GoogleCalendarTitleMode titleMode;
  final bool includePhone;
  final bool includeMobile;
  final bool includeEmail;
  final bool includeAddress;
  final String syncToken;
  final DateTime? lastSuccessfulSync;
  final String lastError;

  const GoogleCalendarUserSettings({
    this.syncEnabled = false,
    this.googleAccountEmail = '',
    this.credentialReference = '',
    this.calendarId = 'primary',
    this.direction = GoogleCalendarSyncDirection.twoWay,
    this.titleMode = GoogleCalendarTitleMode.generic,
    this.includePhone = true,
    this.includeMobile = true,
    this.includeEmail = true,
    this.includeAddress = false,
    this.syncToken = '',
    this.lastSuccessfulSync,
    this.lastError = '',
  });

  bool get isConnected =>
      googleAccountEmail.isNotEmpty && credentialReference.isNotEmpty;

  factory GoogleCalendarUserSettings.fromJson(Map<String, dynamic> json) =>
      GoogleCalendarUserSettings(
        syncEnabled: json['syncEnabled'] == true,
        googleAccountEmail: json['googleAccountEmail']?.toString() ?? '',
        credentialReference: json['credentialReference']?.toString() ?? '',
        calendarId: json['calendarId']?.toString() ?? 'primary',
        direction: GoogleCalendarSyncDirection.parse(
          json['direction']?.toString() ?? '',
        ),
        titleMode: GoogleCalendarTitleMode.parse(
          json['titleMode']?.toString() ?? '',
        ),
        includePhone: json['includePhone'] != false,
        includeMobile: json['includeMobile'] != false,
        includeEmail: json['includeEmail'] != false,
        includeAddress: json['includeAddress'] == true,
        syncToken: json['syncToken']?.toString() ?? '',
        lastSuccessfulSync: DateTime.tryParse(
          json['lastSuccessfulSync']?.toString() ?? '',
        ),
        lastError: json['lastError']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'syncEnabled': syncEnabled,
        if (googleAccountEmail.isNotEmpty)
          'googleAccountEmail': googleAccountEmail,
        if (credentialReference.isNotEmpty)
          'credentialReference': credentialReference,
        'calendarId': calendarId,
        'direction': direction.name,
        'titleMode': titleMode.name,
        'includePhone': includePhone,
        'includeMobile': includeMobile,
        'includeEmail': includeEmail,
        'includeAddress': includeAddress,
        if (syncToken.isNotEmpty) 'syncToken': syncToken,
        if (lastSuccessfulSync != null)
          'lastSuccessfulSync': lastSuccessfulSync!.toUtc().toIso8601String(),
        if (lastError.isNotEmpty) 'lastError': lastError,
      };

  GoogleCalendarUserSettings copyWith({
    bool? syncEnabled,
    String? googleAccountEmail,
    String? credentialReference,
    String? calendarId,
    GoogleCalendarSyncDirection? direction,
    GoogleCalendarTitleMode? titleMode,
    bool? includePhone,
    bool? includeMobile,
    bool? includeEmail,
    bool? includeAddress,
    String? syncToken,
    DateTime? lastSuccessfulSync,
    String? lastError,
  }) =>
      GoogleCalendarUserSettings(
        syncEnabled: syncEnabled ?? this.syncEnabled,
        googleAccountEmail: googleAccountEmail ?? this.googleAccountEmail,
        credentialReference: credentialReference ?? this.credentialReference,
        calendarId: calendarId ?? this.calendarId,
        direction: direction ?? this.direction,
        titleMode: titleMode ?? this.titleMode,
        includePhone: includePhone ?? this.includePhone,
        includeMobile: includeMobile ?? this.includeMobile,
        includeEmail: includeEmail ?? this.includeEmail,
        includeAddress: includeAddress ?? this.includeAddress,
        syncToken: syncToken ?? this.syncToken,
        lastSuccessfulSync: lastSuccessfulSync ?? this.lastSuccessfulSync,
        lastError: lastError ?? this.lastError,
      );

  GoogleCalendarUserSettings disconnected() => GoogleCalendarUserSettings(
        calendarId: calendarId,
        direction: direction,
        titleMode: titleMode,
        includePhone: includePhone,
        includeMobile: includeMobile,
        includeEmail: includeEmail,
        includeAddress: includeAddress,
      );
}

class GoogleCalendarEvent {
  final String id;
  final String status;
  final String summary;
  final String description;
  final DateTime? start;
  final DateTime? end;
  final String etag;
  final DateTime? updatedAt;
  final String htmlLink;
  final Map<String, String> privateProperties;

  const GoogleCalendarEvent({
    required this.id,
    required this.status,
    required this.summary,
    required this.description,
    required this.start,
    required this.end,
    this.etag = '',
    this.updatedAt,
    this.htmlLink = '',
    this.privateProperties = const {},
  });

  bool get isCancelled => status == 'cancelled';

  factory GoogleCalendarEvent.fromApiJson(Map<String, dynamic> json) {
    final extended = json['extendedProperties'] as Map<String, dynamic>?;
    final private = extended?['private'] as Map<String, dynamic>?;
    return GoogleCalendarEvent(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'confirmed',
      summary: json['summary']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      start: _parseEventDate(json['start']),
      end: _parseEventDate(json['end']),
      etag: json['etag']?.toString() ?? '',
      updatedAt: DateTime.tryParse(json['updated']?.toString() ?? ''),
      htmlLink: json['htmlLink']?.toString() ?? '',
      privateProperties: private == null
          ? const {}
          : private.map((key, value) => MapEntry(key, value.toString())),
    );
  }

  Map<String, dynamic> toApiJson() => {
        if (id.isNotEmpty) 'id': id,
        'summary': summary,
        if (description.isNotEmpty) 'description': description,
        if (start != null)
          'start': {'dateTime': start!.toUtc().toIso8601String()},
        if (end != null) 'end': {'dateTime': end!.toUtc().toIso8601String()},
        if (privateProperties.isNotEmpty)
          'extendedProperties': {'private': privateProperties},
      };

  static DateTime? _parseEventDate(dynamic raw) {
    if (raw is! Map) return null;
    final dateTime = raw['dateTime'];
    if (dateTime != null) return DateTime.tryParse(dateTime.toString());
    final date = raw['date'];
    return date == null ? null : DateTime.tryParse(date.toString());
  }
}

class GoogleCalendarEventPage {
  final List<GoogleCalendarEvent> events;
  final String? nextPageToken;
  final String? nextSyncToken;

  const GoogleCalendarEventPage({
    required this.events,
    this.nextPageToken,
    this.nextSyncToken,
  });
}

class GoogleCalendarSyncState {
  final String? syncToken;
  final DateTime? lastSuccessfulSync;

  const GoogleCalendarSyncState({
    this.syncToken,
    this.lastSuccessfulSync,
  });
}

enum GoogleCalendarSyncIssueType {
  conflict,
  remoteDeletion,
  orphanedRemoteEvent,
  invalidRemoteTime,
}

class GoogleCalendarSyncIssue {
  final GoogleCalendarSyncIssueType type;
  final String appointmentId;
  final String eventId;
  final String message;

  const GoogleCalendarSyncIssue({
    required this.type,
    required this.appointmentId,
    required this.eventId,
    required this.message,
  });
}

class GoogleCalendarSyncResult {
  final int created;
  final int updatedInGoogle;
  final int updatedInApexo;
  final int deletedFromGoogle;
  final bool performedFullResync;
  final String? nextSyncToken;
  final List<GoogleCalendarSyncIssue> issues;

  const GoogleCalendarSyncResult({
    this.created = 0,
    this.updatedInGoogle = 0,
    this.updatedInApexo = 0,
    this.deletedFromGoogle = 0,
    this.performedFullResync = false,
    this.nextSyncToken,
    this.issues = const [],
  });
}

class GoogleCalendarSyncTokenInvalid implements Exception {
  const GoogleCalendarSyncTokenInvalid();

  @override
  String toString() => 'Google Calendar incremental sync token is invalid';
}
