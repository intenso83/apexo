import 'dart:convert';

import 'package:apexo/features/therapy_catalog/procedure_catalog_model.dart';
import 'package:flutter/services.dart';

import 'treatment_plan_model.dart';

class CatalogueTranslation {
  const CatalogueTranslation({
    required this.recordID,
    required this.sourceCode,
    required this.greek,
    required this.english,
    required this.german,
  });

  final String recordID;
  final String sourceCode;
  final String greek;
  final String english;
  final String german;

  String forLanguage(TreatmentPlanLanguage language) => switch (language) {
        TreatmentPlanLanguage.el => greek,
        TreatmentPlanLanguage.en => english.isEmpty ? greek : english,
        TreatmentPlanLanguage.de => german.isEmpty ? greek : german,
      };
}

class TreatmentCatalogueTranslations {
  TreatmentCatalogueTranslations._(this._byID, this._bySourceCode);

  final Map<String, CatalogueTranslation> _byID;
  final Map<String, CatalogueTranslation> _bySourceCode;

  static Future<TreatmentCatalogueTranslations> load() async {
    final raw = await rootBundle
        .loadString('assets/therapy_catalogue_translations.json');
    final rows = (jsonDecode(raw) as List<dynamic>).whereType<Map>().map((row) {
      final data = Map<String, dynamic>.from(row);
      return CatalogueTranslation(
        recordID: data['recordID']?.toString() ?? '',
        sourceCode: data['sourceCode']?.toString() ?? '',
        greek: data['greek']?.toString() ?? '',
        english: data['english']?.toString() ?? '',
        german: data['german']?.toString() ?? '',
      );
    }).toList();
    return TreatmentCatalogueTranslations._(
      {for (final row in rows) row.recordID: row},
      {
        for (final row in rows)
          if (row.sourceCode.isNotEmpty) row.sourceCode: row,
      },
    );
  }

  CatalogueTranslation? forProcedure(ProcedureCatalogItem item) =>
      _byID[item.id] ?? _bySourceCode[item.sourceCode];

  String procedureName(
    ProcedureCatalogItem item,
    TreatmentPlanLanguage language,
  ) {
    return forProcedure(item)?.forLanguage(language) ?? item.title;
  }

  String procedureNameFromSnapshots(
    TreatmentPlanItem item,
    TreatmentPlanLanguage language,
  ) =>
      item.displayName(language);

  String groupName(String greek, TreatmentPlanLanguage language) {
    final translation = _groupTranslations[greek];
    if (translation == null || language == TreatmentPlanLanguage.el) {
      return greek;
    }
    return language == TreatmentPlanLanguage.en
        ? translation.$1
        : translation.$2;
  }
}

const _groupTranslations = <String, (String, String)>{
  'Οδον. Χειρουργική 1': ('Operative dentistry 1', 'Zahnerhaltung 1'),
  'Οδον. Χειρουργική 2': ('Operative dentistry 2', 'Zahnerhaltung 2'),
  'Ενδοδοντία': ('Endodontics', 'Endodontie'),
  'Εξακτική/Χειρουργική': ('Oral surgery', 'Oralchirurgie'),
  'Ακίνητη Προσθετική': ('Fixed prosthodontics', 'Festsitzende Prothetik'),
  'Κινητή Προσθετική': ('Removable prosthodontics', 'Herausnehmbare Prothetik'),
  'Ορθοδοντική': ('Orthodontics', 'Kieferorthopädie'),
  'Περιοδοντολογία': ('Periodontology', 'Parodontologie'),
  'Εμφυτεύματα': ('Implantology', 'Implantologie'),
  'Πρόληψη': ('Prevention', 'Prophylaxe'),
  'Διάγνωση': ('Diagnosis', 'Diagnostik'),
  'Παιδοδοντία': ('Pediatric dentistry', 'Kinderzahnheilkunde'),
  'Γενικά': ('General', 'Allgemein'),
};

String planText(String key, TreatmentPlanLanguage language) {
  final values = _planCopy[key];
  if (values == null) return key;
  return switch (language) {
    TreatmentPlanLanguage.el => values[0],
    TreatmentPlanLanguage.en => values[1],
    TreatmentPlanLanguage.de => values[2],
  };
}

const _planCopy = <String, List<String>>{
  'treatmentPlan': ['Σχέδιο θεραπείας', 'Treatment plan', 'Behandlungsplan'],
  'alternative': ['Εναλλακτική', 'Alternative', 'Alternative'],
  'patient': ['Ασθενής', 'Patient', 'Patient/in'],
  'date': ['Ημερομηνία', 'Date', 'Datum'],
  'treatment': ['Θεραπεία', 'Treatment', 'Behandlung'],
  'target': ['Περιοχή', 'Target', 'Region'],
  'quantity': ['Ποσότητα', 'Quantity', 'Menge'],
  'unitPrice': ['Τιμή μονάδας', 'Unit price', 'Einzelpreis'],
  'discount': ['Έκπτωση', 'Discount', 'Rabatt'],
  'amount': ['Ποσό', 'Amount', 'Betrag'],
  'grossTotal': ['Αρχικό σύνολο', 'Gross total', 'Bruttosumme'],
  'itemDiscounts': [
    'Εκπτώσεις θεραπειών',
    'Treatment discounts',
    'Behandlungsrabatte'
  ],
  'planDiscount': [
    'Έκπτωση συνολικού σχεδίου',
    'Whole-plan discount',
    'Gesamtrabatt'
  ],
  'discountTotal': ['Σύνολο έκπτωσης', 'Total discount', 'Gesamtrabatt'],
  'finalTotal': ['Τελικό σύνολο', 'Final total', 'Endsumme'],
  'consent': ['Συναίνεση', 'Consent', 'Einwilligung'],
  'notAgreed': ['Δεν έχει δοθεί συγκατάθεση', 'Not agreed', 'Nicht zugestimmt'],
  'verbalAgreement': [
    'Προφορική συγκατάθεση',
    'Verbally agreed',
    'Mündlich zugestimmt'
  ],
  'signedAgreement': [
    'Υπογεγραμμένη συγκατάθεση',
    'Signed agreement',
    'Schriftlich zugestimmt'
  ],
  'signature': [
    'Υπογραφή ασθενή',
    'Patient signature',
    'Unterschrift Patient/in'
  ],
  'estimateNotice': [
    'Το παρόν αποτελεί σχέδιο και οικονομική εκτίμηση. Η τελική θεραπεία μπορεί να τροποποιηθεί ανάλογα με τα κλινικά ευρήματα.',
    'This document is a treatment plan and cost estimate. The final treatment may change according to clinical findings.',
    'Dieses Dokument ist ein Behandlungsplan und Kostenvoranschlag. Die endgültige Behandlung kann sich je nach klinischem Befund ändern.'
  ],
  'tooth': ['Δόντι', 'Tooth', 'Zahn'],
  'upperArch': ['Άνω γνάθος', 'Upper arch', 'Oberkiefer'],
  'lowerArch': ['Κάτω γνάθος', 'Lower arch', 'Unterkiefer'],
  'bothArches': ['Και οι δύο γνάθοι', 'Both arches', 'Beide Kiefer'],
  'bridge': ['Γέφυρα', 'Bridge', 'Brücke'],
  'generalPatient': [
    'Γενική καταχώριση ασθενή',
    'General patient entry',
    'Allgemeiner Patienteneintrag'
  ],
};
