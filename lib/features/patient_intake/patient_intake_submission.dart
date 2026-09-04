class PatientIntakeSubmission {
  PatientIntakeSubmission({
    required this.id,
    required this.receivedAt,
    required this.packet,
    this.pdfFile = '',
  });

  final String id;
  final DateTime? receivedAt;
  final Map<String, dynamic> packet;
  final String pdfFile;

  bool get hasPdf => pdfFile.trim().isNotEmpty;

  factory PatientIntakeSubmission.fromJson(Map<String, dynamic> json) {
    return PatientIntakeSubmission(
      id: json['id']?.toString() ?? '',
      receivedAt:
          DateTime.tryParse(json['received_at']?.toString() ?? '')?.toUtc(),
      pdfFile: json['pdf_file']?.toString() ?? '',
      packet: Map<String, dynamic>.from(json['packet'] as Map? ?? const {}),
    );
  }

  Map<String, dynamic> get personal =>
      Map<String, dynamic>.from(packet['personal'] as Map? ?? const {});

  Map<String, dynamic> get medicalHistory => Map<String, dynamic>.from(
        packet['medical_history'] as Map? ?? const {},
      );

  String personalValue(String key) => personal[key]?.toString().trim() ?? '';

  String get displayName => [
        personalValue('family_name'),
        personalValue('given_name'),
      ].where((part) => part.isNotEmpty).join(' ');

  String get dateOfBirth => personalValue('date_of_birth');

  int get positiveAnswerCount {
    final answers = Map<String, dynamic>.from(
      medicalHistory['answers'] as Map? ?? const {},
    );
    return answers.values.where((value) {
      final answer = Map<String, dynamic>.from(value as Map? ?? const {});
      return answer['value'] == 'yes';
    }).length;
  }
}
