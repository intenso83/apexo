import 'package:apexo/services/localization/locale.dart';

/// Stable questionnaire definition shared by manual entry, tablet intake,
/// printable forms, OCR review, and DentalWin migration.
///
/// The IDs are data keys and must not be translated or reordered casually.
class MedicalHistoryQuestion {
  const MedicalHistoryQuestion({
    required this.id,
    required this.labels,
    this.paperNumber,
    this.indented = false,
  });

  final String id;
  final Map<String, String> labels;
  final int? paperNumber;
  final bool indented;

  String label([String? languageCode]) =>
      PracticeMedicalHistoryQuestionnaire.localized(labels, languageCode);
}

class MedicalHistorySection {
  const MedicalHistorySection({
    required this.id,
    required this.labels,
    required this.questions,
  });

  final String id;
  final Map<String, String> labels;
  final List<MedicalHistoryQuestion> questions;

  String label([String? languageCode]) =>
      PracticeMedicalHistoryQuestionnaire.localized(labels, languageCode);
}

class PracticeMedicalHistoryQuestionnaire {
  PracticeMedicalHistoryQuestionnaire._();

  static const version = 'practice-medical-history-2026-09-02-v1';

  static String localized(
    Map<String, String> values, [
    String? languageCode,
  ]) {
    final code = (languageCode ?? locale.s.$code).toLowerCase();
    return values[code] ?? values['en'] ?? values.values.first;
  }

  static const sections = <MedicalHistorySection>[
    MedicalHistorySection(
      id: 'allergies_and_reactions',
      labels: {
        'en': 'Allergies and adverse reactions',
        'el': 'Αλλεργίες και ανεπιθύμητες αντιδράσεις',
        'de': 'Allergien und unerwünschte Reaktionen',
      },
      questions: [
        MedicalHistoryQuestion(
          id: 'allergies',
          paperNumber: 1,
          labels: {
            'en': 'Allergies (please specify)',
            'el': 'Αλλεργίες (παρακαλώ προσδιορίστε)',
            'de': 'Allergien (bitte angeben)',
          },
        ),
        MedicalHistoryQuestion(
          id: 'penicillin_allergy',
          indented: true,
          labels: {
            'en': 'Penicillin allergy',
            'el': 'Αλλεργία στην πενικιλίνη',
            'de': 'Penicillinallergie',
          },
        ),
        MedicalHistoryQuestion(
          id: 'latex_allergy',
          indented: true,
          labels: {
            'en': 'Latex allergy',
            'el': 'Αλλεργία στο λάτεξ',
            'de': 'Latexallergie',
          },
        ),
        MedicalHistoryQuestion(
          id: 'adverse_dental_reaction',
          paperNumber: 23,
          labels: {
            'en':
                'Unpleasant reaction after dental treatment, anesthetic, or medication',
            'el':
                'Δυσάρεστη αντίδραση μετά από οδοντιατρική θεραπεία, αναισθητικό ή φάρμακο',
            'de':
                'Unangenehme Reaktion nach Zahnbehandlung, Betäubung oder Medikamenten',
          },
        ),
      ],
    ),
    MedicalHistorySection(
      id: 'systemic_conditions',
      labels: {
        'en': 'Medical conditions',
        'el': 'Ιατρικές παθήσεις',
        'de': 'Erkrankungen',
      },
      questions: [
        MedicalHistoryQuestion(
          id: 'respiratory_disease',
          paperNumber: 2,
          labels: {
            'en': 'Respiratory disease',
            'el': 'Παθήσεις του αναπνευστικού',
            'de': 'Atemwegserkrankung',
          },
        ),
        MedicalHistoryQuestion(
          id: 'asthma',
          indented: true,
          labels: {'en': 'Asthma', 'el': 'Άσθμα', 'de': 'Asthma'},
        ),
        MedicalHistoryQuestion(
          id: 'coagulation_disorder',
          paperNumber: 3,
          labels: {
            'en': 'Blood coagulation or bleeding disorder',
            'el': 'Διαταραχή πήξης ή αιμορραγική διάθεση',
            'de': 'Blutgerinnungs- oder Blutungsstörung',
          },
        ),
        MedicalHistoryQuestion(
          id: 'diabetes',
          paperNumber: 4,
          labels: {
            'en': 'Diabetes',
            'el': 'Σακχαρώδης διαβήτης',
            'de': 'Diabetes',
          },
        ),
        MedicalHistoryQuestion(
          id: 'epilepsy',
          paperNumber: 5,
          labels: {'en': 'Epilepsy', 'el': 'Επιληψία', 'de': 'Epilepsie'},
        ),
        MedicalHistoryQuestion(
          id: 'artificial_joints',
          paperNumber: 6,
          labels: {
            'en': 'Artificial joints',
            'el': 'Τεχνητές αρθρώσεις',
            'de': 'Künstliche Gelenke',
          },
        ),
        MedicalHistoryQuestion(
          id: 'glaucoma',
          paperNumber: 7,
          labels: {'en': 'Glaucoma', 'el': 'Γλαύκωμα', 'de': 'Glaukom'},
        ),
        MedicalHistoryQuestion(
          id: 'thyroid_disorder',
          paperNumber: 8,
          labels: {
            'en': 'Thyroid disorder',
            'el': 'Διαταραχή θυρεοειδούς',
            'de': 'Schilddrüsenerkrankung',
          },
        ),
        MedicalHistoryQuestion(
          id: 'neurological_psychiatric_disorder',
          paperNumber: 9,
          labels: {
            'en': 'Neurological or psychiatric disorder',
            'el': 'Νευρολογική ή ψυχιατρική διαταραχή',
            'de': 'Neurologische oder psychiatrische Erkrankung',
          },
        ),
        MedicalHistoryQuestion(
          id: 'infectious_disease',
          paperNumber: 11,
          labels: {
            'en': 'Infectious disease (hepatitis, HIV, tuberculosis, other)',
            'el': 'Λοιμώδες νόσημα (ηπατίτιδα, HIV, φυματίωση, άλλο)',
            'de': 'Infektionskrankheit (Hepatitis, HIV, Tuberkulose, andere)',
          },
        ),
        MedicalHistoryQuestion(
          id: 'liver_kidney_disease',
          paperNumber: 12,
          labels: {
            'en': 'Liver or kidney disease',
            'el': 'Πάθηση ήπατος ή νεφρών',
            'de': 'Leber- oder Nierenerkrankung',
          },
        ),
        MedicalHistoryQuestion(
          id: 'gastrointestinal_disorder',
          paperNumber: 13,
          labels: {
            'en': 'Gastrointestinal disorder',
            'el': 'Διαταραχή γαστρεντερικού',
            'de': 'Magen-Darm-Erkrankung',
          },
        ),
        MedicalHistoryQuestion(
          id: 'rheumatism_arthritis',
          paperNumber: 14,
          labels: {
            'en': 'Rheumatism or arthritis',
            'el': 'Ρευματισμοί ή αρθρίτιδα',
            'de': 'Rheuma oder Arthritis',
          },
        ),
      ],
    ),
    MedicalHistorySection(
      id: 'cardiovascular',
      labels: {
        'en': 'Cardiovascular history',
        'el': 'Καρδιαγγειακό ιστορικό',
        'de': 'Herz-Kreislauf-Anamnese',
      },
      questions: [
        MedicalHistoryQuestion(
          id: 'cardiovascular_disease',
          paperNumber: 10,
          labels: {
            'en': 'Cardiovascular disease',
            'el': 'Καρδιαγγειακή πάθηση',
            'de': 'Herz-Kreislauf-Erkrankung',
          },
        ),
        MedicalHistoryQuestion(
          id: 'heart_failure',
          indented: true,
          labels: {
            'en': 'Heart failure',
            'el': 'Καρδιακή ανεπάρκεια',
            'de': 'Herzinsuffizienz',
          },
        ),
        MedicalHistoryQuestion(
          id: 'myocardial_infarction',
          indented: true,
          labels: {
            'en': 'Myocardial infarction',
            'el': 'Έμφραγμα μυοκαρδίου',
            'de': 'Herzinfarkt',
          },
        ),
        MedicalHistoryQuestion(
          id: 'endocarditis',
          indented: true,
          labels: {
            'en': 'Endocarditis',
            'el': 'Ενδοκαρδίτιδα',
            'de': 'Endokarditis',
          },
        ),
        MedicalHistoryQuestion(
          id: 'arrhythmia',
          indented: true,
          labels: {
            'en': 'Abnormal cardiac rhythm',
            'el': 'Διαταραχή καρδιακού ρυθμού',
            'de': 'Herzrhythmusstörung',
          },
        ),
        MedicalHistoryQuestion(
          id: 'pacemaker_or_implanted_device',
          indented: true,
          labels: {
            'en': 'Pacemaker or implanted cardiac device',
            'el': 'Βηματοδότης ή εμφυτευμένη καρδιακή συσκευή',
            'de': 'Herzschrittmacher oder implantiertes Herzgerät',
          },
        ),
        MedicalHistoryQuestion(
          id: 'blood_pressure_disorder',
          indented: true,
          labels: {
            'en': 'High or low blood pressure',
            'el': 'Υψηλή ή χαμηλή αρτηριακή πίεση',
            'de': 'Hoher oder niedriger Blutdruck',
          },
        ),
        MedicalHistoryQuestion(
          id: 'stroke',
          indented: true,
          labels: {
            'en': 'Stroke',
            'el': 'Αγγειακό εγκεφαλικό επεισόδιο',
            'de': 'Schlaganfall',
          },
        ),
        MedicalHistoryQuestion(
          id: 'antibiotic_prophylaxis',
          indented: true,
          labels: {
            'en': 'Antibiotic prophylaxis before dental treatment',
            'el': 'Αντιβιοτική προφύλαξη πριν από οδοντιατρική θεραπεία',
            'de': 'Antibiotikaprophylaxe vor Zahnbehandlung',
          },
        ),
      ],
    ),
    MedicalHistorySection(
      id: 'care_and_medication',
      labels: {
        'en': 'Current care and medication',
        'el': 'Τρέχουσα φροντίδα και φαρμακευτική αγωγή',
        'de': 'Aktuelle Behandlung und Medikamente',
      },
      questions: [
        MedicalHistoryQuestion(
          id: 'pregnancy',
          paperNumber: 15,
          labels: {
            'en': 'Pregnancy or possibility of pregnancy',
            'el': 'Εγκυμοσύνη ή πιθανότητα εγκυμοσύνης',
            'de': 'Schwangerschaft oder mögliche Schwangerschaft',
          },
        ),
        MedicalHistoryQuestion(
          id: 'recent_hospitalization',
          paperNumber: 16,
          labels: {
            'en': 'Hospitalization during the last three years',
            'el': 'Νοσηλεία κατά τα τελευταία τρία χρόνια',
            'de': 'Krankenhausaufenthalt in den letzten drei Jahren',
          },
        ),
        MedicalHistoryQuestion(
          id: 'ongoing_medical_treatment',
          paperNumber: 17,
          labels: {
            'en': 'Currently under medical treatment',
            'el': 'Βρίσκεστε σε ιατρική παρακολούθηση ή θεραπεία',
            'de': 'Derzeit in ärztlicher Behandlung',
          },
        ),
        MedicalHistoryQuestion(
          id: 'anticoagulant_antiplatelet_therapy',
          paperNumber: 19,
          labels: {
            'en': 'Anticoagulant or antiplatelet medication',
            'el': 'Αντιπηκτική ή αντιαιμοπεταλιακή αγωγή',
            'de': 'Gerinnungshemmende oder thrombozytenhemmende Medikamente',
          },
        ),
        MedicalHistoryQuestion(
          id: 'other_medications',
          paperNumber: 20,
          labels: {
            'en': 'Other medications',
            'el': 'Άλλα φάρμακα',
            'de': 'Andere Medikamente',
          },
        ),
        MedicalHistoryQuestion(
          id: 'chemotherapy_radiotherapy',
          paperNumber: 21,
          labels: {
            'en': 'Chemotherapy or radiotherapy',
            'el': 'Χημειοθεραπεία ή ακτινοθεραπεία',
            'de': 'Chemotherapie oder Strahlentherapie',
          },
        ),
        MedicalHistoryQuestion(
          id: 'antiresorptive_therapy',
          paperNumber: 22,
          labels: {
            'en': 'Antiresorptive medication, including bisphosphonates',
            'el': 'Αντιοστεολυτική αγωγή, συμπεριλαμβανομένων των διφωσφονικών',
            'de': 'Antiresorptive Medikamente, einschließlich Bisphosphonate',
          },
        ),
      ],
    ),
    MedicalHistorySection(
      id: 'lifestyle',
      labels: {
        'en': 'Lifestyle',
        'el': 'Τρόπος ζωής',
        'de': 'Lebensweise',
      },
      questions: [
        MedicalHistoryQuestion(
          id: 'smoking',
          paperNumber: 18,
          labels: {
            'en': 'Smoking',
            'el': 'Κάπνισμα',
            'de': 'Rauchen',
          },
        ),
        MedicalHistoryQuestion(
          id: 'alcohol_use',
          labels: {
            'en': 'Alcohol use relevant to care',
            'el': 'Χρήση αλκοόλ σχετική με τη θεραπεία',
            'de': 'Für die Behandlung relevanter Alkoholkonsum',
          },
        ),
      ],
    ),
  ];

  static List<MedicalHistoryQuestion> get questions =>
      sections.expand((section) => section.questions).toList(growable: false);

  static Map<String, MedicalHistoryQuestion> get questionsByID => {
        for (final question in questions) question.id: question,
      };
}
