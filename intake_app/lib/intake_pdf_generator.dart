import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'form_configuration.dart';
import 'intake_schema.dart';

class IntakePdfGenerator {
  const IntakePdfGenerator();

  static const maxPdfBytes = 2 * 1024 * 1024;

  Future<Uint8List> generate({
    required IntakeDraft draft,
    required IntakeFormConfiguration configuration,
    DateTime? generatedAt,
  }) async {
    final fontData = await rootBundle.load('assets/fonts/DejaVuSans.ttf');
    final logoBytes = await _loadLogo(configuration.customLogoPath);
    final signatureBytes = await renderSignatureImage(draft.signatureStrokes);
    return generateWithAssets(
      draft: draft,
      configuration: configuration,
      fontData: fontData,
      logoBytes: logoBytes,
      signatureBytes: signatureBytes,
      generatedAt: generatedAt,
    );
  }

  Future<Uint8List> generateWithAssets({
    required IntakeDraft draft,
    required IntakeFormConfiguration configuration,
    required ByteData fontData,
    required Uint8List signatureBytes,
    Uint8List? logoBytes,
    DateTime? generatedAt,
  }) async {
    final language = draft.language;
    final labels = _PdfLabels(language);
    final created = (generatedAt ?? DateTime.now()).toLocal();
    final font = pw.Font.ttf(fontData);
    final theme = pw.ThemeData.withFont(base: font, bold: font);
    final logo = logoBytes == null ? null : pw.MemoryImage(logoBytes);
    final signature = pw.MemoryImage(signatureBytes);
    final document = pw.Document(
      title: labels.documentTitle,
      author: configuration.practiceName(language),
      creator: 'Apexo Patient Intake',
      subject: labels.medicalHistory,
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(38, 34, 38, 38),
        theme: theme,
        maxPages: 20,
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
            ),
          ),
          child: pw.Text(
            '${labels.page} ${context.pageNumber}/${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ),
        build: (context) => [
          _header(
            configuration: configuration,
            language: language,
            labels: labels,
            logo: logo,
          ),
          pw.SizedBox(height: 10),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                labels.documentTitle,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey800,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '${labels.generated}: ${_formatDateTime(created)}',
                style: const pw.TextStyle(
                  fontSize: 8.5,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          ..._configuredSections(
            draft: draft,
            configuration: configuration,
            labels: labels,
          ),
          pw.SizedBox(height: 14),
          pw.Header(
            level: 1,
            text: labels.declarations,
            textStyle: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey800,
            ),
          ),
          _declarationLine(
            labels.gdprAcknowledged,
            draft.privacyAccepted,
            labels,
          ),
          _declarationLine(labels.answersConfirmed, draft.confirmed, labels),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blueGrey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  labels.signature,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text('${labels.signedName}: ${draft.signedName.trim()}'),
                pw.SizedBox(height: 8),
                pw.Container(
                  height: 110,
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(5),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    border: pw.Border.all(color: PdfColors.grey500),
                  ),
                  child: pw.Image(signature, fit: pw.BoxFit.contain),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            '${labels.questionnaireVersion}: $questionnaireVersion',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    final bytes = await document.save();
    if (bytes.length > maxPdfBytes) {
      throw StateError('The generated intake PDF is unexpectedly large.');
    }
    return bytes;
  }

  Future<Uint8List?> _loadLogo(String customLogoPath) async {
    Uint8List bytes;
    final path = customLogoPath.trim();
    if (path.isNotEmpty) {
      try {
        bytes = await File(path).readAsBytes();
      } catch (_) {
        final asset = await rootBundle.load('assets/practice_logo.gif');
        bytes = asset.buffer.asUint8List();
      }
    } else {
      final asset = await rootBundle.load('assets/practice_logo.gif');
      bytes = asset.buffer.asUint8List();
    }
    try {
      return await _convertImageToPng(bytes, targetWidth: 500);
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List> renderSignatureImage(
    List<List<Map<String, double>>> strokes, {
    int width = 1000,
    int height = 300,
  }) async {
    if (strokes.fold<int>(0, (count, stroke) => count + stroke.length) < 2) {
      throw StateError('A drawn signature is required for the PDF.');
    }
    final image = img.Image(width: width, height: height, numChannels: 4);
    img.fill(image, color: img.ColorRgba8(255, 255, 255, 255));
    final ink = img.ColorRgba8(23, 36, 58, 255);
    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        img.fillCircle(
          image,
          x: _pixel(stroke.first['x'], width),
          y: _pixel(stroke.first['y'], height),
          radius: 2,
          color: ink,
        );
        continue;
      }
      for (var index = 1; index < stroke.length; index++) {
        final previous = stroke[index - 1];
        final point = stroke[index];
        img.drawLine(
          image,
          x1: _pixel(previous['x'], width),
          y1: _pixel(previous['y'], height),
          x2: _pixel(point['x'], width),
          y2: _pixel(point['y'], height),
          color: ink,
          thickness: 5,
          antialias: true,
        );
      }
    }
    return Uint8List.fromList(img.encodePng(image, level: 6));
  }

  static Future<Uint8List> _convertImageToPng(
    Uint8List input, {
    int? targetWidth,
  }) async {
    final decoded = img.decodeImage(input);
    if (decoded == null) throw StateError('The logo could not be converted.');
    final normalized = targetWidth != null && decoded.width > targetWidth
        ? img.copyResize(decoded, width: targetWidth)
        : decoded;
    return Uint8List.fromList(img.encodePng(normalized, level: 6));
  }

  static int _pixel(double? normalized, int extent) =>
      ((normalized ?? 0).clamp(0, 1) * (extent - 1)).round();

  pw.Widget _header({
    required IntakeFormConfiguration configuration,
    required String language,
    required _PdfLabels labels,
    required pw.MemoryImage? logo,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 9),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.blueGrey300, width: 0.7),
        ),
      ),
      child: pw.Row(
        children: [
          if (logo != null) ...[
            pw.SizedBox(
              width: 46,
              height: 46,
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            ),
            pw.SizedBox(width: 12),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  configuration.practiceName(language),
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey800,
                  ),
                ),
                pw.Text(
                  labels.practiceType,
                  style: const pw.TextStyle(
                    fontSize: 9.5,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<pw.Widget> _configuredSections({
    required IntakeDraft draft,
    required IntakeFormConfiguration configuration,
    required _PdfLabels labels,
  }) {
    final result = <pw.Widget>[];
    for (final page in configuration.visiblePages) {
      final rows = <List<dynamic>>[];
      for (final item in configuration.itemsForPage(page.id)) {
        if (item.isField) {
          final definition = intakeFieldsById[item.id];
          if (definition == null) continue;
          rows.add([
            definition.label(draft.language),
            draft.personal[item.id]?.trim() ?? '',
            '',
          ]);
        } else {
          final question = intakeQuestionsById[item.id];
          final answer = draft.answers[item.id];
          if (question == null || answer == null) continue;
          rows.add([
            question.label(draft.language),
            labels.answerLabel(answer),
            answer.notes.trim(),
          ]);
        }
      }
      if (rows.isEmpty) continue;
      const chunkSize = 10;
      for (var offset = 0; offset < rows.length; offset += chunkSize) {
        final end = (offset + chunkSize).clamp(0, rows.length);
        result.add(
          pw.Inseparable(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 1,
                  text: offset == 0
                      ? page.title(draft.language)
                      : '${page.title(draft.language)} - ${labels.continued}',
                  textStyle: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey800,
                  ),
                ),
                _sectionTable(rows.sublist(offset, end), labels),
              ],
            ),
          ),
        );
        result.add(pw.SizedBox(height: 8));
      }
    }
    return result;
  }

  pw.Widget _sectionTable(List<List<dynamic>> rows, _PdfLabels labels) {
    return pw.TableHelper.fromTextArray(
      headers: [labels.entry, labels.answer, labels.details],
      data: rows,
      columnWidths: const {
        0: pw.FlexColumnWidth(5),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(3),
      },
      cellAlignment: pw.Alignment.topLeft,
      headerAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      headerStyle: pw.TextStyle(
        fontSize: 8.5,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      cellStyle: const pw.TextStyle(fontSize: 8.2, lineSpacing: 1.5),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(
          color: PdfColors.blueGrey200,
          width: 0.4,
        ),
        bottom: pw.BorderSide(color: PdfColors.blueGrey300, width: 0.6),
      ),
    );
  }

  pw.Widget _declarationLine(String label, bool value, _PdfLabels labels) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text('$label: ${value ? labels.yes : labels.no}'),
    );
  }

  static String _formatDateTime(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.year.toString().padLeft(4, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}

final Map<String, IntakeQuestion> intakeQuestionsById = {
  for (final question in intakeQuestions) question.id: question,
};

class _PdfLabels {
  const _PdfLabels(this.language);

  final String language;

  String get documentTitle => _value('document_title');
  String get practiceType => _value('practice_type');
  String get medicalHistory => _value('medical_history');
  String get generated => _value('generated');
  String get page => _value('page');
  String get entry => _value('entry');
  String get answer => _value('answer');
  String get details => _value('details');
  String get declarations => _value('declarations');
  String get gdprAcknowledged => _value('gdpr_acknowledged');
  String get answersConfirmed => _value('answers_confirmed');
  String get signature => _value('signature');
  String get signedName => _value('signed_name');
  String get questionnaireVersion => _value('questionnaire_version');
  String get continued => _value('continued');
  String get yes => _value('yes');
  String get no => _value('no');
  String get unknown => _value('unknown');

  String answerLabel(IntakeAnswer answer) {
    final base = switch (answer.value) {
      'yes' => yes,
      'no' => no,
      _ => unknown,
    };
    if (answer.selections.isEmpty) return base;
    final selected = answer.selections.map((item) => _value(item)).join(', ');
    return '$base - $selected';
  }

  String _value(String key) =>
      _pdfLabels[language]?[key] ?? _pdfLabels['en']![key] ?? key;
}

const _pdfLabels = <String, Map<String, String>>{
  'el': {
    'document_title': 'Έντυπο ιατρικού ιστορικού ασθενούς',
    'practice_type': 'Οδοντιατρείο',
    'medical_history': 'Ιατρικό ιστορικό',
    'generated': 'Δημιουργήθηκε',
    'page': 'Σελίδα',
    'entry': 'Ερώτηση / πεδίο',
    'answer': 'Απάντηση',
    'details': 'Λεπτομέρειες',
    'declarations': 'Δηλώσεις',
    'gdpr_acknowledged': 'Ανάγνωση ενημέρωσης ΓΚΠΔ',
    'answers_confirmed': 'Επιβεβαίωση ακρίβειας απαντήσεων',
    'signature': 'Υπογραφή ασθενούς',
    'signed_name': 'Ονοματεπώνυμο',
    'questionnaire_version': 'Έκδοση ερωτηματολογίου',
    'continued': 'συνέχεια',
    'yes': 'Ναι',
    'no': 'Όχι',
    'unknown': 'Δεν γνωρίζω',
    'kidney': 'Νεφρά',
    'liver': 'Ήπαρ',
    'high': 'Υψηλή πίεση',
    'low': 'Χαμηλή πίεση',
  },
  'en': {
    'document_title': 'Patient medical history form',
    'practice_type': 'Dental practice',
    'medical_history': 'Medical history',
    'generated': 'Generated',
    'page': 'Page',
    'entry': 'Question / field',
    'answer': 'Answer',
    'details': 'Details',
    'declarations': 'Declarations',
    'gdpr_acknowledged': 'GDPR notice acknowledged',
    'answers_confirmed': 'Accuracy of answers confirmed',
    'signature': 'Patient signature',
    'signed_name': 'Full name',
    'questionnaire_version': 'Questionnaire version',
    'continued': 'continued',
    'yes': 'Yes',
    'no': 'No',
    'unknown': 'I do not know',
    'kidney': 'Kidney',
    'liver': 'Liver',
    'high': 'High blood pressure',
    'low': 'Low blood pressure',
  },
  'de': {
    'document_title': 'Patientenanamnese',
    'practice_type': 'Zahnarztpraxis',
    'medical_history': 'Medizinische Anamnese',
    'generated': 'Erstellt',
    'page': 'Seite',
    'entry': 'Frage / Feld',
    'answer': 'Antwort',
    'details': 'Einzelheiten',
    'declarations': 'Erklärungen',
    'gdpr_acknowledged': 'DSGVO-Hinweis zur Kenntnis genommen',
    'answers_confirmed': 'Richtigkeit der Antworten bestätigt',
    'signature': 'Unterschrift des Patienten',
    'signed_name': 'Vollständiger Name',
    'questionnaire_version': 'Fragebogenversion',
    'continued': 'Fortsetzung',
    'yes': 'Ja',
    'no': 'Nein',
    'unknown': 'Ich weiß es nicht',
    'kidney': 'Niere',
    'liver': 'Leber',
    'high': 'Hoher Blutdruck',
    'low': 'Niedriger Blutdruck',
  },
};
