const questionnaireVersion = 'practice-medical-history-2026-09-04-v3';
const intakePacketVersion = 'practice-patient-intake-2026-09-04-v3';

typedef Labels = Map<String, String>;

String localized(Labels values, String language) =>
    values[language] ?? values['en'] ?? values.values.first;

class IntakeQuestion {
  const IntakeQuestion({
    required this.id,
    required this.group,
    required this.labels,
  });

  final String id;
  final String group;
  final Labels labels;

  String label(String language) => localized(labels, language);
}

const questionnaireGroups = <String, Labels>{
  'allergies_and_reactions': {
    'el': 'Αλλεργίες και ανεπιθύμητες αντιδράσεις',
    'en': 'Allergies and adverse reactions',
    'de': 'Allergien und unerwünschte Reaktionen',
  },
  'systemic_conditions': {
    'el': 'Ιατρικές παθήσεις',
    'en': 'Medical conditions',
    'de': 'Erkrankungen',
  },
  'cardiovascular': {
    'el': 'Καρδιαγγειακό ιστορικό',
    'en': 'Cardiovascular history',
    'de': 'Herz-Kreislauf-Anamnese',
  },
  'care_and_medication': {
    'el': 'Τρέχουσα φροντίδα και φαρμακευτική αγωγή',
    'en': 'Current care and medication',
    'de': 'Aktuelle Behandlung und Medikamente',
  },
  'lifestyle': {'el': 'Τρόπος ζωής', 'en': 'Lifestyle', 'de': 'Lebensweise'},
};

const intakeQuestions = <IntakeQuestion>[
  IntakeQuestion(
    id: 'allergies',
    group: 'allergies_and_reactions',
    labels: {
      'el': 'Αλλεργίες (παρακαλώ προσδιορίστε)',
      'en': 'Allergies (please specify)',
      'de': 'Allergien (bitte angeben)',
    },
  ),
  IntakeQuestion(
    id: 'antibiotic_allergy',
    group: 'allergies_and_reactions',
    labels: {
      'el': 'Αλλεργία σε αντιβιοτικό',
      'en': 'Antibiotic allergy',
      'de': 'Allergie gegen Antibiotika',
    },
  ),
  IntakeQuestion(
    id: 'adverse_dental_reaction',
    group: 'allergies_and_reactions',
    labels: {
      'el':
          'Δυσάρεστη αντίδραση μετά από οδοντιατρική θεραπεία, αναισθητικό ή φάρμακο',
      'en':
          'Unpleasant reaction after dental treatment, anesthetic, or medication',
      'de':
          'Unangenehme Reaktion nach Zahnbehandlung, Betäubung oder Medikamenten',
    },
  ),
  IntakeQuestion(
    id: 'respiratory_disease',
    group: 'systemic_conditions',
    labels: {
      'el': 'Παθήσεις του αναπνευστικού',
      'en': 'Respiratory disease',
      'de': 'Atemwegserkrankung',
    },
  ),
  IntakeQuestion(
    id: 'asthma',
    group: 'systemic_conditions',
    labels: {'el': 'Άσθμα', 'en': 'Asthma', 'de': 'Asthma'},
  ),
  IntakeQuestion(
    id: 'coagulation_disorder',
    group: 'systemic_conditions',
    labels: {
      'el': 'Διαταραχή πήξης ή αιμορραγική διάθεση',
      'en': 'Blood coagulation or bleeding disorder',
      'de': 'Blutgerinnungs- oder Blutungsstörung',
    },
  ),
  IntakeQuestion(
    id: 'diabetes',
    group: 'systemic_conditions',
    labels: {'el': 'Σακχαρώδης διαβήτης', 'en': 'Diabetes', 'de': 'Diabetes'},
  ),
  IntakeQuestion(
    id: 'epilepsy',
    group: 'systemic_conditions',
    labels: {'el': 'Επιληψία', 'en': 'Epilepsy', 'de': 'Epilepsie'},
  ),
  IntakeQuestion(
    id: 'artificial_joints',
    group: 'systemic_conditions',
    labels: {
      'el': 'Τεχνητές αρθρώσεις',
      'en': 'Artificial joints',
      'de': 'Künstliche Gelenke',
    },
  ),
  IntakeQuestion(
    id: 'glaucoma',
    group: 'systemic_conditions',
    labels: {'el': 'Γλαύκωμα', 'en': 'Glaucoma', 'de': 'Glaukom'},
  ),
  IntakeQuestion(
    id: 'thyroid_disorder',
    group: 'systemic_conditions',
    labels: {
      'el': 'Διαταραχή θυρεοειδούς',
      'en': 'Thyroid disorder',
      'de': 'Schilddrüsenerkrankung',
    },
  ),
  IntakeQuestion(
    id: 'neurological_psychiatric_disorder',
    group: 'systemic_conditions',
    labels: {
      'el': 'Νευρολογική ή ψυχιατρική διαταραχή',
      'en': 'Neurological or psychiatric disorder',
      'de': 'Neurologische oder psychiatrische Erkrankung',
    },
  ),
  IntakeQuestion(
    id: 'infectious_disease',
    group: 'systemic_conditions',
    labels: {
      'el': 'Λοιμώδες νόσημα (ηπατίτιδα, HIV, φυματίωση, άλλο)',
      'en': 'Infectious disease (hepatitis, HIV, tuberculosis, other)',
      'de': 'Infektionskrankheit (Hepatitis, HIV, Tuberkulose, andere)',
    },
  ),
  IntakeQuestion(
    id: 'liver_kidney_disease',
    group: 'systemic_conditions',
    labels: {
      'el': 'Πάθηση νεφρών ή ήπατος',
      'en': 'Kidney or liver disease',
      'de': 'Nieren- oder Lebererkrankung',
    },
  ),
  IntakeQuestion(
    id: 'gastrointestinal_disorder',
    group: 'systemic_conditions',
    labels: {
      'el': 'Διαταραχή γαστρεντερικού',
      'en': 'Gastrointestinal disorder',
      'de': 'Magen-Darm-Erkrankung',
    },
  ),
  IntakeQuestion(
    id: 'rheumatism_arthritis',
    group: 'systemic_conditions',
    labels: {
      'el': 'Ρευματισμοί ή αρθρίτιδα',
      'en': 'Rheumatism or arthritis',
      'de': 'Rheuma oder Arthritis',
    },
  ),
  IntakeQuestion(
    id: 'cardiovascular_disease',
    group: 'cardiovascular',
    labels: {
      'el': 'Καρδιαγγειακή πάθηση',
      'en': 'Cardiovascular disease',
      'de': 'Herz-Kreislauf-Erkrankung',
    },
  ),
  IntakeQuestion(
    id: 'heart_failure',
    group: 'cardiovascular',
    labels: {
      'el': 'Καρδιακή ανεπάρκεια',
      'en': 'Heart failure',
      'de': 'Herzinsuffizienz',
    },
  ),
  IntakeQuestion(
    id: 'myocardial_infarction',
    group: 'cardiovascular',
    labels: {
      'el': 'Έμφραγμα μυοκαρδίου',
      'en': 'Myocardial infarction',
      'de': 'Herzinfarkt',
    },
  ),
  IntakeQuestion(
    id: 'endocarditis',
    group: 'cardiovascular',
    labels: {'el': 'Ενδοκαρδίτιδα', 'en': 'Endocarditis', 'de': 'Endokarditis'},
  ),
  IntakeQuestion(
    id: 'arrhythmia',
    group: 'cardiovascular',
    labels: {
      'el': 'Διαταραχή καρδιακού ρυθμού',
      'en': 'Abnormal cardiac rhythm',
      'de': 'Herzrhythmusstörung',
    },
  ),
  IntakeQuestion(
    id: 'pacemaker_or_implanted_device',
    group: 'cardiovascular',
    labels: {
      'el': 'Βηματοδότης ή εμφυτευμένη καρδιακή συσκευή',
      'en': 'Pacemaker or implanted cardiac device',
      'de': 'Herzschrittmacher oder implantiertes Herzgerät',
    },
  ),
  IntakeQuestion(
    id: 'blood_pressure_disorder',
    group: 'cardiovascular',
    labels: {
      'el': 'Υψηλή ή χαμηλή αρτηριακή πίεση',
      'en': 'High or low blood pressure',
      'de': 'Hoher oder niedriger Blutdruck',
    },
  ),
  IntakeQuestion(
    id: 'stroke',
    group: 'cardiovascular',
    labels: {
      'el': 'Αγγειακό εγκεφαλικό επεισόδιο',
      'en': 'Stroke',
      'de': 'Schlaganfall',
    },
  ),
  IntakeQuestion(
    id: 'antibiotic_prophylaxis',
    group: 'cardiovascular',
    labels: {
      'el':
          'Αντιβιοτική προφύλαξη πριν από οδοντιατρική θεραπεία, κατόπιν εντολής ιατρού',
      'en':
          'Antibiotic prophylaxis ordered by a doctor before dental treatment',
      'de':
          'Ärztlich angeordnete Antibiotikaprophylaxe vor einer Zahnbehandlung',
    },
  ),
  IntakeQuestion(
    id: 'pregnancy',
    group: 'care_and_medication',
    labels: {
      'el': '♀ Εγκυμοσύνη ή πιθανότητα εγκυμοσύνης',
      'en': '♀ Pregnancy or possibility of pregnancy',
      'de': '♀ Schwangerschaft oder mögliche Schwangerschaft',
    },
  ),
  IntakeQuestion(
    id: 'recent_hospitalization',
    group: 'care_and_medication',
    labels: {
      'el': 'Νοσηλεία κατά τα τελευταία τρία χρόνια',
      'en': 'Hospitalization during the last three years',
      'de': 'Krankenhausaufenthalt in den letzten drei Jahren',
    },
  ),
  IntakeQuestion(
    id: 'ongoing_medical_treatment',
    group: 'care_and_medication',
    labels: {
      'el': 'Βρίσκεστε σε ιατρική παρακολούθηση ή θεραπεία',
      'en': 'Currently under medical treatment',
      'de': 'Derzeit in ärztlicher Behandlung',
    },
  ),
  IntakeQuestion(
    id: 'anticoagulant_antiplatelet_therapy',
    group: 'care_and_medication',
    labels: {
      'el': 'Αντιπηκτική ή αντιαιμοπεταλιακή αγωγή',
      'en': 'Anticoagulant or antiplatelet medication',
      'de': 'Gerinnungshemmende oder thrombozytenhemmende Medikamente',
    },
  ),
  IntakeQuestion(
    id: 'other_medications',
    group: 'care_and_medication',
    labels: {
      'el': 'Άλλα φάρμακα',
      'en': 'Other medications',
      'de': 'Andere Medikamente',
    },
  ),
  IntakeQuestion(
    id: 'chemotherapy_radiotherapy',
    group: 'care_and_medication',
    labels: {
      'el': 'Χημειοθεραπεία ή ακτινοθεραπεία',
      'en': 'Chemotherapy or radiotherapy',
      'de': 'Chemotherapie oder Strahlentherapie',
    },
  ),
  IntakeQuestion(
    id: 'antiresorptive_therapy',
    group: 'care_and_medication',
    labels: {
      'el':
          'Αντιοστεολυτική αγωγή — Prolia® (denosumab) ή διφωσφονικά, π.χ. Fosamax®/Fosavance® (alendronate), Actonel® (risedronate), Bonviva® (ibandronate), Aclasta®/Zometa® (zoledronic acid)',
      'en':
          'Antiresorptive treatment — Prolia® (denosumab) or bisphosphonates, e.g. Fosamax®/Fosavance® (alendronate), Actonel® (risedronate), Bonviva® (ibandronate), Aclasta®/Zometa® (zoledronic acid)',
      'de':
          'Antiresorptive Therapie — Prolia® (Denosumab) oder Bisphosphonate, z. B. Fosamax®/Fosavance® (Alendronat), Actonel® (Risedronat), Bonviva® (Ibandronat), Aclasta®/Zometa® (Zoledronsäure)',
    },
  ),
  IntakeQuestion(
    id: 'smoking',
    group: 'lifestyle',
    labels: {'el': 'Κάπνισμα', 'en': 'Smoking', 'de': 'Rauchen'},
  ),
];

class IntakeAnswer {
  String value = '';
  String notes = '';
  List<String> selections = [];

  Map<String, dynamic> toJson() => {
    'value': value.isEmpty ? 'unknown' : value,
    if (selections.isNotEmpty) 'selections': selections,
    if (notes.trim().isNotEmpty) 'notes': notes.trim(),
  };
}

bool requiresQuestionDetails(String questionId, IntakeAnswer answer) =>
    answer.value == 'yes' &&
    const {
      'antibiotic_allergy',
      'liver_kidney_disease',
      'smoking',
    }.contains(questionId);

bool hasValidRequiredDetails(String questionId, IntakeAnswer answer) {
  if (!requiresQuestionDetails(questionId, answer)) return true;
  final text = answer.notes.trim();
  if (text.isEmpty) return false;
  if (questionId != 'smoking') return true;
  final daily = int.tryParse(text);
  return daily != null && daily > 0 && daily <= 200;
}

class IntakeDraft {
  IntakeDraft() {
    for (final question in intakeQuestions) {
      answers[question.id] = IntakeAnswer();
    }
  }

  String language = 'el';
  final Map<String, String> personal = {};
  final Map<String, IntakeAnswer> answers = {};
  bool privacyAccepted = false;
  bool confirmed = false;
  String signedName = '';
  int configurationRevision = 1;
  List<String> visibleItemIds = const [];
  List<List<Map<String, double>>> signatureStrokes = const [];

  Map<String, dynamic> toJson() => {
    'packet_version': intakePacketVersion,
    'questionnaire_version': questionnaireVersion,
    'source': 'patient_intake_android',
    'language_code': language,
    'gdpr_acknowledged': privacyAccepted,
    'form_configuration': {
      'revision': configurationRevision,
      'visible_item_ids': visibleItemIds,
    },
    'submitted_at': DateTime.now().toUtc().toIso8601String(),
    'personal': personal.map((key, value) => MapEntry(key, value.trim()))
      ..removeWhere((_, value) => value.isEmpty),
    'medical_history': {
      'answers': answers.map((key, value) => MapEntry(key, value.toJson())),
    },
    'patient_confirmed': confirmed,
    'signature': {
      'type': 'drawn',
      'name': signedName.trim(),
      'strokes': signatureStrokes,
      'signed_at': DateTime.now().toUtc().toIso8601String(),
    },
  };
}
