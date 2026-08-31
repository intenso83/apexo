class GoogleCalendarAppointmentLink {
  final String eventId;
  final String calendarId;
  final String etag;
  final DateTime? updatedAt;
  final String htmlLink;
  final String syncFingerprint;

  const GoogleCalendarAppointmentLink({
    this.eventId = '',
    this.calendarId = '',
    this.etag = '',
    this.updatedAt,
    this.htmlLink = '',
    this.syncFingerprint = '',
  });

  bool get isLinked => eventId.isNotEmpty;

  factory GoogleCalendarAppointmentLink.fromJson(Map<String, dynamic> json) =>
      GoogleCalendarAppointmentLink(
        eventId: json['eventId']?.toString() ?? '',
        calendarId: json['calendarId']?.toString() ?? '',
        etag: json['etag']?.toString() ?? '',
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
        htmlLink: json['htmlLink']?.toString() ?? '',
        syncFingerprint: json['syncFingerprint']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'calendarId': calendarId,
        if (etag.isNotEmpty) 'etag': etag,
        if (updatedAt != null)
          'updatedAt': updatedAt!.toUtc().toIso8601String(),
        if (htmlLink.isNotEmpty) 'htmlLink': htmlLink,
        if (syncFingerprint.isNotEmpty) 'syncFingerprint': syncFingerprint,
      };
}
