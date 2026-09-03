import 'package:apexo/features/patients/patient_model.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'periodontal_chart_model.dart';

Future<Uint8List> buildPeriodontalChartPdf({
  required PeriodontalChart chart,
  required Patient patient,
  ByteData? fontData,
}) async {
  final regularData =
      fontData ?? await rootBundle.load('assets/fonts/DejaVuSans.ttf');
  final font = pw.Font.ttf(regularData);
  final document =
      pw.Document(theme: pw.ThemeData.withFont(base: font, bold: font));
  const navy = PdfColor.fromInt(0xFF173B57);
  const blue = PdfColor.fromInt(0xFF547B92);
  const paleBlue = PdfColor.fromInt(0xFFEAF4F8);
  const border = PdfColor.fromInt(0xFFD4E0E6);
  const red = PdfColor.fromInt(0xFFBC3A43);
  final summary = chart.summary;
  final date =
      DateFormat('dd/MM/yyyy HH:mm').format(chart.recordedAt.toLocal());

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(26),
      header: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Periodontal chart / Περιοδοντικό διάγραμμα',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: navy,
                ),
              ),
              pw.Text(date,
                  style: const pw.TextStyle(fontSize: 9, color: blue)),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Text(patient.title, style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 8),
          pw.Container(height: 1.5, color: blue),
          pw.SizedBox(height: 10),
        ],
      ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          '${context.pageNumber} / ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 7, color: blue),
        ),
      ),
      build: (_) => [
        pw.Row(
          children: [
            _summaryBox('Sites', '${summary.measuredSites}', paleBlue, navy),
            _summaryBox(
              'BOP',
              '${summary.bleedingPercentage.toStringAsFixed(0)}%',
              paleBlue,
              summary.bleedingPercentage >= 20 ? red : navy,
            ),
            _summaryBox(
              'Plaque',
              '${summary.plaquePercentage.toStringAsFixed(0)}%',
              paleBlue,
              summary.plaquePercentage >= 20 ? red : navy,
            ),
            _summaryBox(
              'Max PD',
              '${summary.maximumProbingDepth} mm',
              paleBlue,
              summary.maximumProbingDepth >= 6 ? red : navy,
            ),
            _summaryBox('PD ≥4', '${summary.deepSites}', paleBlue, navy),
            _summaryBox('PD ≥6', '${summary.veryDeepSites}', paleBlue, red),
          ],
        ),
        pw.SizedBox(height: 12),
        _surfaceTable(
          title: 'Upper buccal',
          teeth: upperPeriodontalTeeth,
          sites: buccalPeriodontalSites,
          navy: navy,
          paleBlue: paleBlue,
          border: border,
          red: red,
          chart: chart,
        ),
        pw.SizedBox(height: 8),
        _surfaceTable(
          title: 'Upper palatal',
          teeth: upperPeriodontalTeeth,
          sites: lingualPeriodontalSites,
          navy: navy,
          paleBlue: paleBlue,
          border: border,
          red: red,
          chart: chart,
        ),
        pw.SizedBox(height: 12),
        _surfaceTable(
          title: 'Lower lingual',
          teeth: lowerPeriodontalTeeth,
          sites: lingualPeriodontalSites,
          navy: navy,
          paleBlue: paleBlue,
          border: border,
          red: red,
          chart: chart,
        ),
        pw.SizedBox(height: 8),
        _surfaceTable(
          title: 'Lower buccal',
          teeth: lowerPeriodontalTeeth,
          sites: buccalPeriodontalSites,
          navy: navy,
          paleBlue: paleBlue,
          border: border,
          red: red,
          chart: chart,
        ),
        if (chart.notes.trim().isNotEmpty) ...[
          pw.SizedBox(height: 12),
          pw.Text('Notes / Σημειώσεις',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: navy)),
          pw.SizedBox(height: 4),
          pw.Text(chart.notes, style: const pw.TextStyle(fontSize: 9)),
        ],
      ],
    ),
  );
  return document.save();
}

Future<void> printPeriodontalChart({
  required PeriodontalChart chart,
  required Patient patient,
}) async {
  final bytes = await buildPeriodontalChartPdf(chart: chart, patient: patient);
  await Printing.layoutPdf(
    name: 'Periodontal chart - ${patient.title}',
    format: PdfPageFormat.a4.landscape,
    onLayout: (_) async => bytes,
  );
}

pw.Widget _summaryBox(
  String label,
  String value,
  PdfColor background,
  PdfColor foreground,
) {
  return pw.Expanded(
    child: pw.Container(
      margin: const pw.EdgeInsets.only(right: 6),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: pw.BoxDecoration(
        color: background,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 7)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: foreground,
            ),
          ),
        ],
      ),
    ),
  );
}

pw.Widget _surfaceTable({
  required String title,
  required List<int> teeth,
  required List<PeriodontalSite> sites,
  required PeriodontalChart chart,
  required PdfColor navy,
  required PdfColor paleBlue,
  required PdfColor border,
  required PdfColor red,
}) {
  final rows = <pw.TableRow>[
    pw.TableRow(
      decoration: pw.BoxDecoration(color: paleBlue),
      children: [
        _pdfCell(title, bold: true, color: navy),
        for (final fdi in teeth)
          _pdfCell('$fdi', bold: true, color: navy, align: pw.TextAlign.center),
      ],
    ),
    for (final metric in ['PD', 'GM', 'CAL', 'BOP', 'PI'])
      pw.TableRow(
        children: [
          _pdfCell(metric, bold: true, color: navy),
          for (final fdi in teeth)
            _pdfCell(
              _surfaceValue(chart.tooth(fdi), sites, metric),
              color: metric == 'BOP' || metric == 'PI' ? red : null,
              align: pw.TextAlign.center,
            ),
        ],
      ),
    pw.TableRow(
      children: [
        _pdfCell('Mob / Furc', bold: true, color: navy),
        for (final fdi in teeth)
          _pdfCell(
            chart.tooth(fdi).missing
                ? 'Missing'
                : '${chart.tooth(fdi).mobility} / ${chart.tooth(fdi).furcation}',
            align: pw.TextAlign.center,
          ),
      ],
    ),
  ];
  return pw.Table(
    border: pw.TableBorder.all(color: border, width: 0.5),
    columnWidths: {
      0: const pw.FixedColumnWidth(58),
      for (var index = 1; index <= teeth.length; index++)
        index: const pw.FlexColumnWidth(),
    },
    children: rows,
  );
}

String _surfaceValue(
  PeriodontalTooth tooth,
  List<PeriodontalSite> sites,
  String metric,
) {
  if (tooth.missing) return '—';
  return sites.map((site) {
    final measurement = tooth.measurement(site);
    return switch (metric) {
      'PD' => measurement.probingDepth?.toString() ?? '·',
      'GM' => measurement.gingivalMargin?.toString() ?? '·',
      'CAL' => measurement.clinicalAttachmentLevel?.toString() ?? '·',
      'BOP' => measurement.bleedingOnProbing ? '●' : '·',
      'PI' => measurement.plaque ? '●' : '·',
      _ => '·',
    };
  }).join(' ');
}

pw.Widget _pdfCell(
  String value, {
  bool bold = false,
  PdfColor? color,
  pw.TextAlign align = pw.TextAlign.left,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
    child: pw.Text(
      value,
      textAlign: align,
      maxLines: 1,
      style: pw.TextStyle(
        fontSize: 6.5,
        fontWeight: bold ? pw.FontWeight.bold : null,
        color: color,
      ),
    ),
  );
}
