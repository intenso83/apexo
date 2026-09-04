import 'package:apexo/core/model.dart';

import 'medical_history_questionnaire.dart';

class MedicalHistoryAnswerValue {
  MedicalHistoryAnswerValue._();

  static const unknown = 'unknown';
  static const no = 'no';
  static const yes = 'yes';
  static const notApplicable = 'not_applicable';

  static const values = <String>{unknown, no, yes, notApplicable};
}

class MedicalHistoryAnswer {
  MedicalHistoryAnswer({
    this.value = MedicalHistoryAnswerValue.unknown,
    this.notes = '',
    this.imported = false,
    this.requiresReview = false,
    this.sourceField = '',
    this.rawValue,
  });

  String value;
  String notes;
  bool imported;
  bool requiresReview;
  String sourceField;
  dynamic rawValue;

  factory MedicalHistoryAnswer.fromJson(Map<String, dynamic> json) {
    final candidate = json['value']?.toString() ?? '';
    return MedicalHistoryAnswer(
      value: MedicalHistoryAnswerValue.values.contains(candidate)
          ? candidate
          : MedicalHistoryAnswerValue.unknown,
      notes: json['notes']?.toString() ?? '',
      imported: json['imported'] == true,
      requiresReview: json['requires_review'] == true,
      sourceField: json['source_field']?.toString() ?? '',
      rawValue: json['raw_value'],
    );
  }

  MedicalHistoryAnswer copy() => MedicalHistoryAnswer.fromJson(toJson());

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'value': value};
    if (notes.trim().isNotEmpty) json['notes'] = notes.trim();
    if (imported) json['imported'] = true;
    if (requiresReview) json['requires_review'] = true;
    if (sourceField.isNotEmpty) json['source_field'] = sourceField;
    if (rawValue != null) json['raw_value'] = rawValue;
    return json;
  }
}

class MedicalHistorySource {
  MedicalHistorySource._();

  static const tablet = 'tablet';
  static const staffManual = 'staff_manual';
  static const dentalWin = 'dentalwin_import';
  static const ocr = 'ocr_import';
  static const other = 'other';
}

class MedicalHistoryStatus {
  MedicalHistoryStatus._();

  static const draft = 'draft';
  static const pendingReview = 'pending_review';
  static const confirmed = 'confirmed';
  static const superseded = 'superseded';
}

/// An immutable snapshot once it has been stored.
///
/// UI flows create a fresh object for every update. Existing stored revisions
/// are displayed read-only, preserving signatures and imported provenance.
class MedicalHistoryRevision extends Model {
  MedicalHistoryRevision.fromJson(super.json) : super.fromJson();

  String patientID = '';
  String questionnaireVersion = PracticeMedicalHistoryQuestionnaire.version;
  int revisionNumber = 1;
  String previousRevisionID = '';
  String source = MedicalHistorySource.staffManual;
  String status = MedicalHistoryStatus.draft;
  String languageCode = 'en';
  DateTime createdAt = DateTime.now().toUtc();
  DateTime? submittedAt;
  DateTime? reviewedAt;
  String reviewedByAccountID = '';
  bool patientConfirmed = false;
  Map<String, dynamic> signature = {};

  String reasonForVisit = '';
  String presentCondition = '';
  String treatingPhysician = '';
  String diseasesSurgeries = '';
  String generalNotes = '';
  String legacyMedicinesText = '';

  Map<String, MedicalHistoryAnswer> answers = {};
  Map<String, dynamic> legacyRawPayload = {};
  Map<String, dynamic> provenance = {};

  bool get isImported =>
      source == MedicalHistorySource.dentalWin ||
      source == MedicalHistorySource.ocr;

  bool get requiresReview =>
      status == MedicalHistoryStatus.pendingReview ||
      answers.values.any((answer) => answer.requiresReview);

  MedicalHistoryAnswer answerFor(String questionID) =>
      answers.putIfAbsent(questionID, MedicalHistoryAnswer.new);

  List<String> get positiveQuestionIDs => answers.entries
      .where((entry) => entry.value.value == MedicalHistoryAnswerValue.yes)
      .map((entry) => entry.key)
      .toList(growable: false);

  @override
  void fromJson(Map<String, dynamic> json) {
    super.fromJson(json);
    patientID = json['patient_id']?.toString() ?? patientID;
    questionnaireVersion =
        json['questionnaire_version']?.toString() ?? questionnaireVersion;
    revisionNumber = _parseInt(json['revision_number']) ?? revisionNumber;
    previousRevisionID =
        json['previous_revision_id']?.toString() ?? previousRevisionID;
    source = json['source']?.toString() ?? source;
    status = json['status']?.toString() ?? status;
    languageCode = json['language_code']?.toString() ?? languageCode;
    createdAt = _parseDate(json['created_at']) ?? createdAt;
    submittedAt = _parseDate(json['submitted_at']);
    reviewedAt = _parseDate(json['reviewed_at']);
    reviewedByAccountID =
        json['reviewed_by_account_id']?.toString() ?? reviewedByAccountID;
    patientConfirmed = json['patient_confirmed'] == true;
    signature = Map<String, dynamic>.from(json['signature'] ?? const {});

    reasonForVisit = json['reason_for_visit']?.toString() ?? reasonForVisit;
    presentCondition =
        json['present_condition']?.toString() ?? presentCondition;
    treatingPhysician =
        json['treating_physician']?.toString() ?? treatingPhysician;
    diseasesSurgeries =
        json['diseases_surgeries']?.toString() ?? diseasesSurgeries;
    generalNotes = json['general_notes']?.toString() ?? generalNotes;
    legacyMedicinesText =
        json['legacy_medicines_text']?.toString() ?? legacyMedicinesText;

    final rawAnswers = Map<String, dynamic>.from(json['answers'] ?? const {});
    answers = rawAnswers.map(
      (key, value) => MapEntry(
        key,
        MedicalHistoryAnswer.fromJson(
          Map<String, dynamic>.from(value as Map),
        ),
      ),
    );
    legacyRawPayload =
        Map<String, dynamic>.from(json['legacy_raw_payload'] ?? const {});
    provenance = Map<String, dynamic>.from(json['provenance'] ?? const {});
    title = title.isEmpty ? 'Medical history revision $revisionNumber' : title;
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['patient_id'] = patientID;
    json['questionnaire_version'] = questionnaireVersion;
    json['revision_number'] = revisionNumber;
    if (previousRevisionID.isNotEmpty) {
      json['previous_revision_id'] = previousRevisionID;
    }
    json['source'] = source;
    json['status'] = status;
    json['language_code'] = languageCode;
    json['created_at'] = createdAt.toUtc().toIso8601String();
    if (submittedAt != null) {
      json['submitted_at'] = submittedAt!.toUtc().toIso8601String();
    }
    if (reviewedAt != null) {
      json['reviewed_at'] = reviewedAt!.toUtc().toIso8601String();
    }
    if (reviewedByAccountID.isNotEmpty) {
      json['reviewed_by_account_id'] = reviewedByAccountID;
    }
    if (patientConfirmed) json['patient_confirmed'] = true;
    if (signature.isNotEmpty) json['signature'] = signature;

    if (reasonForVisit.trim().isNotEmpty) {
      json['reason_for_visit'] = reasonForVisit.trim();
    }
    if (presentCondition.trim().isNotEmpty) {
      json['present_condition'] = presentCondition.trim();
    }
    if (treatingPhysician.trim().isNotEmpty) {
      json['treating_physician'] = treatingPhysician.trim();
    }
    if (diseasesSurgeries.trim().isNotEmpty) {
      json['diseases_surgeries'] = diseasesSurgeries.trim();
    }
    if (generalNotes.trim().isNotEmpty) {
      json['general_notes'] = generalNotes.trim();
    }
    if (legacyMedicinesText.trim().isNotEmpty) {
      json['legacy_medicines_text'] = legacyMedicinesText.trim();
    }
    if (answers.isNotEmpty) {
      json['answers'] = answers.map(
        (key, value) => MapEntry(key, value.toJson()),
      );
    }
    if (legacyRawPayload.isNotEmpty) {
      json['legacy_raw_payload'] = legacyRawPayload;
    }
    if (provenance.isNotEmpty) json['provenance'] = provenance;
    return json;
  }

  @override
  MedicalHistoryRevision copy(bool blank) =>
      MedicalHistoryRevision.fromJson(blank ? {} : toJson());

  MedicalHistoryRevision copyAsNextRevision({
    required String languageCode,
    String source = MedicalHistorySource.staffManual,
  }) {
    final json = toJson()
      ..remove('id')
      ..remove('archived')
      ..remove('submitted_at')
      ..remove('reviewed_at')
      ..remove('reviewed_by_account_id')
      ..remove('signature');
    final next = MedicalHistoryRevision.fromJson(json)
      ..revisionNumber = revisionNumber + 1
      ..previousRevisionID = id
      ..source = source
      ..status = MedicalHistoryStatus.draft
      ..languageCode = languageCode
      ..createdAt = DateTime.now().toUtc()
      ..patientConfirmed = false
      ..provenance = {};
    next.title = 'Medical history revision ${next.revisionNumber}';
    return next;
  }

  factory MedicalHistoryRevision.fromDentalWinStage({
    required String patientID,
    required Map<String, dynamic> stage,
  }) {
    final revision = MedicalHistoryRevision.fromJson({
      'patient_id': patientID,
      'source': MedicalHistorySource.dentalWin,
      'status': MedicalHistoryStatus.pendingReview,
      'language_code': 'el',
      'reason_for_visit': stage['reason_for_visit'],
      'present_condition': stage['present_condition'],
      'diseases_surgeries': stage['diseases_surgeries_text'],
      'general_notes': stage['general_notes'],
      'legacy_medicines_text': stage['medicines_text'],
      'legacy_raw_payload': stage,
      'provenance': {
        'source_system': 'DentalWin',
        if (stage['stage_key'] != null) 'stage_key': stage['stage_key'],
        'mapping_version': PracticeMedicalHistoryQuestionnaire.version,
      },
    });

    revision._addImportedFlag(
      questionID: 'antibiotic_allergy',
      sourceField: 'penikilinh',
      rawValue: stage['penicillin_raw'],
    );
    revision._addImportedFlag(
      questionID: 'allergies',
      sourceField: 'latex',
      rawValue: stage['latex_raw'],
    );
    revision._addImportedFlag(
      questionID: 'blood_pressure_disorder',
      sourceField: 'ypertasi',
      rawValue: stage['hypertension_raw'],
    );
    revision._addImportedFlag(
      questionID: 'cardiovascular_disease',
      sourceField: 'kardiaggiaki',
      rawValue: stage['cardiovascular_raw'],
    );
    revision._addImportedText(
      questionID: 'pregnancy',
      sourceField: 'MEMOS29',
      rawValue: stage['pregnancy_text'],
    );
    return revision;
  }

  void _addImportedText({
    required String questionID,
    required String sourceField,
    required dynamic rawValue,
  }) {
    final text = rawValue?.toString().trim() ?? '';
    if (text.isEmpty) return;
    answers[questionID] = MedicalHistoryAnswer(
      value: MedicalHistoryAnswerValue.unknown,
      notes: text,
      imported: true,
      requiresReview: true,
      sourceField: sourceField,
      rawValue: rawValue,
    );
  }

  void _addImportedFlag({
    required String questionID,
    required String sourceField,
    required dynamic rawValue,
  }) {
    if (rawValue == null || rawValue.toString().trim().isEmpty) return;
    answers[questionID] = MedicalHistoryAnswer(
      value: _legacyFlagValue(rawValue),
      imported: true,
      requiresReview: true,
      sourceField: sourceField,
      rawValue: rawValue,
    );
  }

  static String _legacyFlagValue(dynamic rawValue) {
    if (rawValue is bool) {
      return rawValue
          ? MedicalHistoryAnswerValue.yes
          : MedicalHistoryAnswerValue.no;
    }
    if (rawValue is num) {
      if (rawValue == 1 || rawValue == -1) {
        return MedicalHistoryAnswerValue.yes;
      }
      if (rawValue == 0) return MedicalHistoryAnswerValue.no;
    }
    final normalized = rawValue.toString().trim().toLowerCase();
    if ({'1', '-1', 'true', 'yes', 'y', 'ναι'}.contains(normalized)) {
      return MedicalHistoryAnswerValue.yes;
    }
    if ({'0', 'false', 'no', 'n', 'όχι', 'οχι'}.contains(normalized)) {
      return MedicalHistoryAnswerValue.no;
    }
    return MedicalHistoryAnswerValue.unknown;
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return null;
    return DateTime.tryParse(value.toString())?.toUtc();
  }
}
