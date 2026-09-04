import 'intake_schema.dart';

const mandatoryFieldIds = <String>{
  'family_name',
  'given_name',
  'date_of_birth',
};

const contactFieldIds = <String>{'mobile', 'phone', 'email'};

const defaultPracticeNames = <String, String>{
  'el': 'ΕΥΡΙΠΙΔΗΣ ΔΗΜΗΤΡΑΚΟΠΟΥΛΟΣ',
  'en': 'EVRIPIDIS DIMITRAKOPOULOS',
  'de': 'EVRIPIDIS DIMITRAKOPOULOS',
};

class IntakeFieldDefinition {
  const IntakeFieldDefinition({
    required this.id,
    required this.labelKey,
    this.lines = 1,
    this.wide = false,
    this.input = 'text',
  });

  final String id;
  final String labelKey;
  final int lines;
  final bool wide;
  final String input;

  bool get mandatory => mandatoryFieldIds.contains(id);
  bool get isContactMethod => contactFieldIds.contains(id);

  String label(String language) =>
      localized(_fieldLabels[labelKey] ?? {'en': labelKey}, language);
}

const _fieldLabels = <String, Labels>{
  'family_name': {'el': 'Επώνυμο', 'en': 'Family name', 'de': 'Nachname'},
  'given_name': {'el': 'Όνομα', 'en': 'First name', 'de': 'Vorname'},
  'father_name': {
    'el': 'Πατρώνυμο',
    'en': 'Father’s name',
    'de': 'Name des Vaters',
  },
  'date_of_birth': {
    'el': 'Ημερομηνία γέννησης',
    'en': 'Date of birth',
    'de': 'Geburtsdatum',
  },
  'occupation': {'el': 'Επάγγελμα', 'en': 'Occupation', 'de': 'Beruf'},
  'country_of_origin': {
    'el': 'Χώρα καταγωγής',
    'en': 'Country of origin',
    'de': 'Herkunftsland',
  },
  'mobile': {'el': 'Κινητό', 'en': 'Mobile', 'de': 'Mobiltelefon'},
  'phone': {'el': 'Τηλέφωνο', 'en': 'Telephone', 'de': 'Telefon'},
  'email': {'el': 'Email', 'en': 'Email', 'de': 'E-Mail'},
  'address': {'el': 'Διεύθυνση', 'en': 'Address', 'de': 'Anschrift'},
  'postal_code': {'el': 'Τ.Κ.', 'en': 'Postal code', 'de': 'Postleitzahl'},
  'city': {'el': 'Πόλη', 'en': 'City', 'de': 'Ort'},
  'amka': {'el': 'ΑΜΚΑ', 'en': 'AMKA', 'de': 'AMKA'},
  'afm': {'el': 'ΑΦΜ', 'en': 'Tax number', 'de': 'Steuernummer'},
  'doy': {'el': 'ΔΟΥ', 'en': 'Tax office', 'de': 'Finanzamt'},
  'insurance': {'el': 'Ασφάλιση', 'en': 'Insurance', 'de': 'Versicherung'},
};

const intakeFieldDefinitions = <IntakeFieldDefinition>[
  IntakeFieldDefinition(id: 'family_name', labelKey: 'family_name'),
  IntakeFieldDefinition(id: 'given_name', labelKey: 'given_name'),
  IntakeFieldDefinition(id: 'father_name', labelKey: 'father_name'),
  IntakeFieldDefinition(
    id: 'date_of_birth',
    labelKey: 'date_of_birth',
    input: 'date',
  ),
  IntakeFieldDefinition(id: 'occupation', labelKey: 'occupation'),
  IntakeFieldDefinition(id: 'country_of_origin', labelKey: 'country_of_origin'),
  IntakeFieldDefinition(id: 'mobile', labelKey: 'mobile', input: 'phone'),
  IntakeFieldDefinition(id: 'phone', labelKey: 'phone', input: 'phone'),
  IntakeFieldDefinition(id: 'email', labelKey: 'email', input: 'email'),
  IntakeFieldDefinition(id: 'address', labelKey: 'address', wide: true),
  IntakeFieldDefinition(
    id: 'postal_code',
    labelKey: 'postal_code',
    input: 'number',
  ),
  IntakeFieldDefinition(id: 'city', labelKey: 'city'),
  IntakeFieldDefinition(id: 'amka', labelKey: 'amka'),
  IntakeFieldDefinition(id: 'afm', labelKey: 'afm'),
  IntakeFieldDefinition(id: 'doy', labelKey: 'doy'),
  IntakeFieldDefinition(id: 'insurance', labelKey: 'insurance'),
];

Map<String, IntakeFieldDefinition> get intakeFieldsById => {
  for (final field in intakeFieldDefinitions) field.id: field,
};

class IntakePageConfiguration {
  IntakePageConfiguration({
    required this.id,
    required this.titles,
    required this.subtitles,
    required this.order,
    this.enabled = true,
    this.protected = false,
    this.custom = false,
  });

  String id;
  Labels titles;
  Labels subtitles;
  int order;
  bool enabled;
  bool protected;
  bool custom;

  String title(String language) => localized(titles, language);
  String subtitle(String language) => localized(subtitles, language);

  IntakePageConfiguration copy() => IntakePageConfiguration.fromJson(toJson());

  factory IntakePageConfiguration.fromJson(Map<String, dynamic> json) {
    return IntakePageConfiguration(
      id: json['id']?.toString() ?? '',
      titles: Map<String, String>.from(json['titles'] as Map? ?? const {}),
      subtitles: Map<String, String>.from(
        json['subtitles'] as Map? ?? const {},
      ),
      order: int.tryParse(json['order']?.toString() ?? '') ?? 0,
      enabled: json['enabled'] != false,
      protected: json['protected'] == true,
      custom: json['custom'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'titles': titles,
    'subtitles': subtitles,
    'order': order,
    'enabled': enabled,
    'protected': protected,
    'custom': custom,
  };
}

class IntakeItemConfiguration {
  IntakeItemConfiguration({
    required this.id,
    required this.kind,
    required this.pageId,
    required this.order,
    this.enabled = true,
  });

  String id;
  String kind;
  String pageId;
  int order;
  bool enabled;

  bool get isField => kind == 'field';
  bool get isQuestion => kind == 'question';
  bool get mandatory => isField && mandatoryFieldIds.contains(id);
  bool get isContactMethod => isField && contactFieldIds.contains(id);

  IntakeItemConfiguration copy() => IntakeItemConfiguration.fromJson(toJson());

  factory IntakeItemConfiguration.fromJson(Map<String, dynamic> json) {
    return IntakeItemConfiguration(
      id: json['id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      pageId: json['page_id']?.toString() ?? '',
      order: int.tryParse(json['order']?.toString() ?? '') ?? 0,
      enabled: json['enabled'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'page_id': pageId,
    'order': order,
    'enabled': enabled,
  };
}

class IntakeFormConfiguration {
  IntakeFormConfiguration({
    required this.pages,
    required this.items,
    this.revision = 1,
    Labels? practiceNames,
    this.customLogoPath = '',
  }) : practiceNames = Map<String, String>.from(
         practiceNames ?? defaultPracticeNames,
       );

  int revision;
  List<IntakePageConfiguration> pages;
  List<IntakeItemConfiguration> items;
  Labels practiceNames;
  String customLogoPath;

  String practiceName(String language) => localized(practiceNames, language);

  factory IntakeFormConfiguration.defaults() {
    final pages = <IntakePageConfiguration>[
      IntakePageConfiguration(
        id: 'identity',
        titles: const {
          'el': 'Προσωπικά στοιχεία',
          'en': 'Personal details',
          'de': 'Persönliche Angaben',
        },
        subtitles: const {
          'el': 'Τα πεδία με αστερίσκο (*) είναι υποχρεωτικά.',
          'en': 'Fields marked with an asterisk (*) are required.',
          'de': 'Mit Sternchen (*) markierte Felder sind Pflichtfelder.',
        },
        order: 0,
      ),
      IntakePageConfiguration(
        id: 'contact',
        titles: const {
          'el': 'Επικοινωνία και διεύθυνση',
          'en': 'Contact and address',
          'de': 'Kontakt und Anschrift',
        },
        subtitles: const {
          'el': 'Χρειαζόμαστε τουλάχιστον έναν τρόπο επικοινωνίας.',
          'en': 'Please provide at least one way for us to contact you.',
          'de': 'Bitte geben Sie mindestens eine Kontaktmöglichkeit an.',
        },
        order: 1,
      ),
      IntakePageConfiguration(
        id: 'conditions',
        titles: const {
          'el': 'Αλλεργίες και παθήσεις',
          'en': 'Allergies and conditions',
          'de': 'Allergien und Erkrankungen',
        },
        subtitles: const {
          'el': 'Επιλέξτε μία απάντηση για κάθε ερώτηση.',
          'en': 'Choose one answer for every question.',
          'de': 'Wählen Sie für jede Frage eine Antwort.',
        },
        order: 3,
      ),
      IntakePageConfiguration(
        id: 'cardiovascular',
        titles: const {
          'el': 'Καρδιαγγειακό ιστορικό',
          'en': 'Cardiovascular history',
          'de': 'Herz-Kreislauf-Anamnese',
        },
        subtitles: const {
          'el': 'Επιλέξτε μία απάντηση για κάθε ερώτηση.',
          'en': 'Choose one answer for every question.',
          'de': 'Wählen Sie für jede Frage eine Antwort.',
        },
        order: 4,
      ),
      IntakePageConfiguration(
        id: 'care',
        titles: const {
          'el': 'Αγωγή και τρόπος ζωής',
          'en': 'Medication and lifestyle',
          'de': 'Medikamente und Lebensweise',
        },
        subtitles: const {
          'el': 'Επιλέξτε μία απάντηση για κάθε ερώτηση.',
          'en': 'Choose one answer for every question.',
          'de': 'Wählen Sie für jede Frage eine Antwort.',
        },
        order: 5,
      ),
    ];

    final items = <IntakeItemConfiguration>[];
    void addFields(String pageId, Iterable<String> ids) {
      var order = 0;
      for (final id in ids) {
        items.add(
          IntakeItemConfiguration(
            id: id,
            kind: 'field',
            pageId: pageId,
            order: order++,
          ),
        );
      }
    }

    addFields('identity', const [
      'family_name',
      'given_name',
      'father_name',
      'date_of_birth',
      'occupation',
      'country_of_origin',
    ]);
    addFields('contact', const [
      'mobile',
      'phone',
      'email',
      'address',
      'postal_code',
      'city',
      'amka',
      'afm',
      'doy',
      'insurance',
    ]);
    final nextOrder = <String, int>{};
    for (final question in intakeQuestions) {
      final pageId = switch (question.group) {
        'cardiovascular' => 'cardiovascular',
        'care_and_medication' || 'lifestyle' => 'care',
        _ => 'conditions',
      };
      final order = nextOrder[pageId] ?? 0;
      items.add(
        IntakeItemConfiguration(
          id: question.id,
          kind: 'question',
          pageId: pageId,
          order: order,
        ),
      );
      nextOrder[pageId] = order + 1;
    }
    return IntakeFormConfiguration(pages: pages, items: items)..normalize();
  }

  factory IntakeFormConfiguration.fromJson(Map<String, dynamic> json) {
    final config = IntakeFormConfiguration(
      pages: (json['pages'] as List<dynamic>? ?? const [])
          .map(
            (page) => IntakePageConfiguration.fromJson(
              Map<String, dynamic>.from(page as Map),
            ),
          )
          .toList(),
      items: (json['items'] as List<dynamic>? ?? const [])
          .map(
            (item) => IntakeItemConfiguration.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      revision: int.tryParse(json['revision']?.toString() ?? '') ?? 1,
      practiceNames: Map<String, String>.from(
        (json['branding'] as Map?)?['practice_names'] as Map? ??
            defaultPracticeNames,
      ),
      customLogoPath:
          (json['branding'] as Map?)?['custom_logo_path']?.toString() ?? '',
    );
    return config..normalize();
  }

  IntakeFormConfiguration copy() => IntakeFormConfiguration.fromJson(toJson());

  List<IntakePageConfiguration> get orderedPages {
    final result = pages.toList()..sort((a, b) => a.order.compareTo(b.order));
    return result;
  }

  List<IntakePageConfiguration> get visiblePages =>
      orderedPages.where((page) => page.enabled).toList(growable: false);

  List<IntakeItemConfiguration> itemsForPage(
    String pageId, {
    bool includeDisabled = false,
  }) {
    final result =
        items
            .where(
              (item) =>
                  item.pageId == pageId && (includeDisabled || item.enabled),
            )
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    return result;
  }

  IntakePageConfiguration? pageById(String id) {
    for (final page in pages) {
      if (page.id == id) return page;
    }
    return null;
  }

  IntakeItemConfiguration? itemById(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  bool canDisableItem(IntakeItemConfiguration item) {
    if (item.mandatory) return false;
    if (item.isContactMethod) {
      return items
              .where(
                (candidate) => candidate.isContactMethod && candidate.enabled,
              )
              .length >
          1;
    }
    return true;
  }

  bool canDisablePage(IntakePageConfiguration page) {
    if (page.protected) return false;
    return !itemsForPage(
      page.id,
    ).any((item) => item.mandatory || item.isContactMethod);
  }

  void normalize() {
    final defaults = IntakeFormConfiguration._rawDefaults();
    final knownPageIds = pages.map((page) => page.id).toSet();
    for (final defaultPage in defaults.pages) {
      if (knownPageIds.add(defaultPage.id)) pages.add(defaultPage.copy());
    }

    final knownItems = items.map((item) => '${item.kind}:${item.id}').toSet();
    for (final defaultItem in defaults.items) {
      if (knownItems.add('${defaultItem.kind}:${defaultItem.id}')) {
        items.add(defaultItem.copy());
      }
    }
    pages.removeWhere((page) => page.id == 'medical_context');
    final validFieldIds = intakeFieldDefinitions
        .map((field) => field.id)
        .toSet();
    final validQuestionIds = intakeQuestions
        .map((question) => question.id)
        .toSet();
    items.removeWhere(
      (item) =>
          (item.isField && !validFieldIds.contains(item.id)) ||
          (item.isQuestion && !validQuestionIds.contains(item.id)) ||
          (!item.isField && !item.isQuestion),
    );

    for (final item in items) {
      if (item.mandatory) item.enabled = true;
      if (pageById(item.pageId) == null) {
        item.pageId = item.isField ? 'identity' : 'conditions';
      }
    }
    if (!items.any((item) => item.isContactMethod && item.enabled)) {
      itemById('mobile')?.enabled = true;
    }
    for (final page in pages) {
      if (page.protected ||
          itemsForPage(
            page.id,
          ).any((item) => item.mandatory || item.isContactMethod)) {
        page.enabled = true;
      }
    }
    for (final language in const ['el', 'en', 'de']) {
      if ((practiceNames[language] ?? '').trim().isEmpty) {
        practiceNames[language] = defaultPracticeNames[language]!;
      }
    }
    final ordered = orderedPages;
    for (var i = 0; i < ordered.length; i++) {
      ordered[i].order = i;
    }
    for (final page in pages) {
      final orderedItems = itemsForPage(page.id, includeDisabled: true);
      for (var i = 0; i < orderedItems.length; i++) {
        orderedItems[i].order = i;
      }
    }
  }

  void markChanged() {
    normalize();
    revision += 1;
  }

  Map<String, dynamic> toJson() => {
    'revision': revision,
    'branding': {
      'practice_names': practiceNames,
      'custom_logo_path': customLogoPath,
    },
    'pages': orderedPages.map((page) => page.toJson()).toList(),
    'items': items.map((item) => item.toJson()).toList(),
  };

  static IntakeFormConfiguration _rawDefaults() {
    final config = IntakeFormConfiguration.defaultsWithoutNormalization();
    return config;
  }

  static IntakeFormConfiguration defaultsWithoutNormalization() {
    // This is replaced by [defaults] during static initialization avoidance.
    // Build once through the same declarations, then return before normalize.
    final built = _DefaultConfigurationBuilder.build();
    return built;
  }
}

class _DefaultConfigurationBuilder {
  static IntakeFormConfiguration build() {
    // Use the public factory's data without recursively calling normalize.
    final pages = <IntakePageConfiguration>[
      IntakePageConfiguration(
        id: 'identity',
        titles: const {
          'el': 'Προσωπικά στοιχεία',
          'en': 'Personal details',
          'de': 'Persönliche Angaben',
        },
        subtitles: const {
          'el': 'Τα πεδία με αστερίσκο (*) είναι υποχρεωτικά.',
          'en': 'Fields marked with an asterisk (*) are required.',
          'de': 'Mit Sternchen (*) markierte Felder sind Pflichtfelder.',
        },
        order: 0,
      ),
      IntakePageConfiguration(
        id: 'contact',
        titles: const {
          'el': 'Επικοινωνία και διεύθυνση',
          'en': 'Contact and address',
          'de': 'Kontakt und Anschrift',
        },
        subtitles: const {
          'el': 'Χρειαζόμαστε τουλάχιστον έναν τρόπο επικοινωνίας.',
          'en': 'Please provide at least one way for us to contact you.',
          'de': 'Bitte geben Sie mindestens eine Kontaktmöglichkeit an.',
        },
        order: 1,
      ),
      IntakePageConfiguration(
        id: 'conditions',
        titles: const {
          'el': 'Αλλεργίες και παθήσεις',
          'en': 'Allergies and conditions',
          'de': 'Allergien und Erkrankungen',
        },
        subtitles: const {
          'el': 'Επιλέξτε μία απάντηση για κάθε ερώτηση.',
          'en': 'Choose one answer for every question.',
          'de': 'Wählen Sie für jede Frage eine Antwort.',
        },
        order: 3,
      ),
      IntakePageConfiguration(
        id: 'cardiovascular',
        titles: const {
          'el': 'Καρδιαγγειακό ιστορικό',
          'en': 'Cardiovascular history',
          'de': 'Herz-Kreislauf-Anamnese',
        },
        subtitles: const {
          'el': 'Επιλέξτε μία απάντηση για κάθε ερώτηση.',
          'en': 'Choose one answer for every question.',
          'de': 'Wählen Sie für jede Frage eine Antwort.',
        },
        order: 4,
      ),
      IntakePageConfiguration(
        id: 'care',
        titles: const {
          'el': 'Αγωγή και τρόπος ζωής',
          'en': 'Medication and lifestyle',
          'de': 'Medikamente und Lebensweise',
        },
        subtitles: const {
          'el': 'Επιλέξτε μία απάντηση για κάθε ερώτηση.',
          'en': 'Choose one answer for every question.',
          'de': 'Wählen Sie für jede Frage eine Antwort.',
        },
        order: 5,
      ),
    ];
    final items = <IntakeItemConfiguration>[];
    const fieldPages = <String, List<String>>{
      'identity': [
        'family_name',
        'given_name',
        'father_name',
        'date_of_birth',
        'occupation',
        'country_of_origin',
      ],
      'contact': [
        'mobile',
        'phone',
        'email',
        'address',
        'postal_code',
        'city',
        'amka',
        'afm',
        'doy',
        'insurance',
      ],
    };
    for (final entry in fieldPages.entries) {
      for (var i = 0; i < entry.value.length; i++) {
        items.add(
          IntakeItemConfiguration(
            id: entry.value[i],
            kind: 'field',
            pageId: entry.key,
            order: i,
          ),
        );
      }
    }
    final nextOrder = <String, int>{};
    for (final question in intakeQuestions) {
      final pageId = switch (question.group) {
        'cardiovascular' => 'cardiovascular',
        'care_and_medication' || 'lifestyle' => 'care',
        _ => 'conditions',
      };
      final order = nextOrder[pageId] ?? 0;
      items.add(
        IntakeItemConfiguration(
          id: question.id,
          kind: 'question',
          pageId: pageId,
          order: order,
        ),
      );
      nextOrder[pageId] = order + 1;
    }
    return IntakeFormConfiguration(pages: pages, items: items);
  }
}
