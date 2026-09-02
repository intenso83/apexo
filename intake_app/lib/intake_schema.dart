const questionnaireVersion = 'practice-medical-history-2026-09-02-v1';
const intakePacketVersion = 'practice-patient-intake-2026-09-02-v1';

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
    id: 'penicillin_allergy',
    group: 'allergies_and_reactions',
    labels: {
      'el': 'Αλλεργία στην πενικιλίνη',
      'en': 'Penicillin allergy',
      'de': 'Penicillinallergie',
    },
  ),
  IntakeQuestion(
    id: 'latex_allergy',
    group: 'allergies_and_reactions',
    labels: {
      'el': 'Αλλεργία στο λάτεξ',
      'en': 'Latex allergy',
      'de': 'Latexallergie',
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
      'el': 'Πάθηση ήπατος ή νεφρών',
      'en': 'Liver or kidney disease',
      'de': 'Leber- oder Nierenerkrankung',
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
      'el': 'Αντιβιοτική προφύλαξη πριν από οδοντιατρική θεραπεία',
      'en': 'Antibiotic prophylaxis before dental treatment',
      'de': 'Antibiotikaprophylaxe vor Zahnbehandlung',
    },
  ),
  IntakeQuestion(
    id: 'pregnancy',
    group: 'care_and_medication',
    labels: {
      'el': 'Εγκυμοσύνη ή πιθανότητα εγκυμοσύνης',
      'en': 'Pregnancy or possibility of pregnancy',
      'de': 'Schwangerschaft oder mögliche Schwangerschaft',
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
      'el': 'Αντιοστεολυτική αγωγή, συμπεριλαμβανομένων των διφωσφονικών',
      'en': 'Antiresorptive medication, including bisphosphonates',
      'de': 'Antiresorptive Medikamente, einschließlich Bisphosphonate',
    },
  ),
  IntakeQuestion(
    id: 'smoking',
    group: 'lifestyle',
    labels: {'el': 'Κάπνισμα', 'en': 'Smoking', 'de': 'Rauchen'},
  ),
  IntakeQuestion(
    id: 'alcohol_use',
    group: 'lifestyle',
    labels: {
      'el': 'Χρήση αλκοόλ σχετική με τη θεραπεία',
      'en': 'Alcohol use relevant to care',
      'de': 'Für die Behandlung relevanter Alkoholkonsum',
    },
  ),
];

class IntakeAnswer {
  String value = '';
  String notes = '';

  Map<String, dynamic> toJson() => {
    'value': value.isEmpty ? 'unknown' : value,
    if (notes.trim().isNotEmpty) 'notes': notes.trim(),
  };
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
  String reasonForVisit = '';
  String presentCondition = '';
  String treatingPhysician = '';
  String diseasesSurgeries = '';
  String generalNotes = '';

  Map<String, dynamic> toJson() => {
    'packet_version': intakePacketVersion,
    'questionnaire_version': questionnaireVersion,
    'source': 'patient_intake_android',
    'language_code': language,
    'submitted_at': DateTime.now().toUtc().toIso8601String(),
    'personal': personal.map((key, value) => MapEntry(key, value.trim()))
      ..removeWhere((_, value) => value.isEmpty),
    'medical_history': {
      if (reasonForVisit.trim().isNotEmpty)
        'reason_for_visit': reasonForVisit.trim(),
      if (presentCondition.trim().isNotEmpty)
        'present_condition': presentCondition.trim(),
      if (treatingPhysician.trim().isNotEmpty)
        'treating_physician': treatingPhysician.trim(),
      if (diseasesSurgeries.trim().isNotEmpty)
        'diseases_surgeries': diseasesSurgeries.trim(),
      if (generalNotes.trim().isNotEmpty) 'general_notes': generalNotes.trim(),
      'answers': answers.map((key, value) => MapEntry(key, value.toJson())),
    },
    'patient_confirmed': confirmed,
    'signature': {
      'type': 'typed_name',
      'name': signedName.trim(),
      'signed_at': DateTime.now().toUtc().toIso8601String(),
    },
  };
}
