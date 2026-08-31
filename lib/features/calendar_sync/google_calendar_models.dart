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
  final GoogleCalendarSyncDirection direction;
  final GoogleCalendarTitleMode titleMode;
  final int pastDays;
  final int futureDays;

  const GoogleCalendarSyncPreferences({
    required this.enabled,
    required this.calendarId,
    required this.clinicId,
    this.direction = GoogleCalendarSyncDirection.twoWay,
    this.titleMode = GoogleCalendarTitleMode.generic,
    this.pastDays = 90,
    this.futureDays = 365,
  });
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
