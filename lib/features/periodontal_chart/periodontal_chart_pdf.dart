import 'package:apexo/features/patients/patient_model.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'periodontal_chart_model.dart';

const _navy = PdfColor.fromInt(0xFF173B57);
const _blue = PdfColor.fromInt(0xFF1769AA);
const _teal = PdfColor.fromInt(0xFF00897B);
const _amber = PdfColor.fromInt(0xFFD97706);
const _red = PdfColor.fromInt(0xFFB3261E);
const _paleBlue = PdfColor.fromInt(0xFFEAF4F8);
const _border = PdfColor.fromInt(0xFFD4E0E6);
const _softGrey = PdfColor.fromInt(0xFFF2F4F5);

Future<Uint8List> buildPeriodontalChartPdf({
  required PeriodontalChart chart,
  required Patient patient,
  ByteData? fontData,
  bool blank = false,
}) async {
  final regularData =
      fontData ?? await rootBundle.load('assets/fonts/DejaVuSans.ttf');
  final font = pw.Font.ttf(regularData);
  final document = pw.Document(
    theme: pw.ThemeData.withFont(base: font, bold: font),
  );
  final summary = chart.summary;
  final date = DateFormat('dd/MM/yyyy HH:mm').format(
    chart.recordedAt.toLocal(),
  );

  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(22),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _pdfHeader(patient: patient, date: date, blank: blank),
          pw.SizedBox(height: 7),
          if (blank) _blankInstructions() else _summaryStrip(summary),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _archProfile(
                  title: 'Upper arch / Άνω γνάθος',
                  secondaryLabel: 'Palatal',
                  teeth: upperPeriodontalTeeth,
                  chart: chart,
                  blank: blank,
                ),
              ),
              pw.SizedBox(width: 9),
              pw.Expanded(
                child: _archProfile(
                  title: 'Lower arch / Κάτω γνάθος',
                  secondaryLabel: 'Lingual',
                  teeth: lowerPeriodontalTeeth,
                  chart: chart,
                  blank: blank,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _surfaceTable(
                  title: 'Upper buccal',
                  teeth: upperPeriodontalTeeth,
                  sites: buccalPeriodontalSites,
                  chart: chart,
                  blank: blank,
                ),
              ),
              pw.SizedBox(width: 9),
              pw.Expanded(
                child: _surfaceTable(
                  title: 'Upper palatal',
                  teeth: upperPeriodontalTeeth,
                  sites: lingualPeriodontalSites,
                  chart: chart,
                  blank: blank,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _surfaceTable(
                  title: 'Lower lingual',
                  teeth: lowerPeriodontalTeeth,
                  sites: lingualPeriodontalSites,
                  chart: chart,
                  blank: blank,
                ),
              ),
              pw.SizedBox(width: 9),
              pw.Expanded(
                child: _surfaceTable(
                  title: 'Lower buccal',
                  teeth: lowerPeriodontalTeeth,
                  sites: buccalPeriodontalSites,
                  chart: chart,
                  blank: blank,
                ),
              ),
            ],
          ),
          pw.Spacer(),
          _pdfFooter(chart: chart, blank: blank),
        ],
      ),
    ),
  );
  return document.save();
}

Future<void> printPeriodontalChart({
  required PeriodontalChart chart,
  required Patient patient,
}) async {
  final bytes = await buildPeriodontalChartPdf(
    chart: chart,
    patient: patient,
  );
  await Printing.layoutPdf(
    name: 'Periodontal chart - ${patient.title}',
    format: PdfPageFormat.a4.landscape,
    onLayout: (_) async => bytes,
  );
}

Future<void> printBlankPeriodontalChart({required Patient patient}) async {
  final blankChart = PeriodontalChart.newExam(patientID: patient.id);
  final bytes = await buildPeriodontalChartPdf(
    chart: blankChart,
    patient: patient,
    blank: true,
  );
  await Printing.layoutPdf(
    name: 'Blank periodontal chart',
    format: PdfPageFormat.a4.landscape,
    onLayout: (_) async => bytes,
  );
}

pw.Widget _pdfHeader({
  required Patient patient,
  required String date,
  required bool blank,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                blank
                    ? 'Blank periodontal chart / Κενό περιοδοντικό διάγραμμα'
                    : 'Periodontal chart / Περιοδοντικό διάγραμμα',
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                  color: _navy,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                blank
                    ? 'Patient / Ασθενής: __________________________________________'
                    : 'Patient / Ασθενής: ${patient.title}',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
          pw.Text(
            blank ? 'Date / Ημερομηνία: ____ / ____ / ______' : date,
            style: const pw.TextStyle(fontSize: 8, color: _blue),
          ),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Container(height: 1.4, color: _blue),
    ],
  );
}

pw.Widget _blankInstructions() {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: pw.BoxDecoration(
      color: _softGrey,
      border: pw.Border.all(color: _border, width: 0.6),
      borderRadius: pw.BorderRadius.circular(3),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Six sites per tooth: MB - B - DB / ML - L - DL',
          style: const pw.TextStyle(fontSize: 7.5, color: _navy),
        ),
        pw.Text(
          'Measurements in mm | mark BOP and PI with +',
          style: const pw.TextStyle(fontSize: 7.5, color: _navy),
        ),
      ],
    ),
  );
}

pw.Widget _summaryStrip(PeriodontalSummary summary) {
  return pw.Row(
    children: [
      _summaryBox('Sites', '${summary.measuredSites}', _navy),
      _summaryBox(
        'BOP',
        '${summary.bleedingPercentage.toStringAsFixed(0)}%',
        summary.bleedingPercentage >= 20 ? _red : _navy,
      ),
      _summaryBox(
        'Plaque',
        '${summary.plaquePercentage.toStringAsFixed(0)}%',
        summary.plaquePercentage >= 20 ? _red : _navy,
      ),
      _summaryBox(
        'Max PD',
        '${summary.maximumProbingDepth} mm',
        summary.maximumProbingDepth >= 6 ? _red : _navy,
      ),
      _summaryBox('PD >=4', '${summary.deepSites}', _amber),
      _summaryBox('PD >=6', '${summary.veryDeepSites}', _red),
    ],
  );
}

pw.Widget _summaryBox(String label, String value, PdfColor foreground) {
  return pw.Expanded(
    child: pw.Container(
      margin: const pw.EdgeInsets.only(right: 5),
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: pw.BoxDecoration(
        color: _paleBlue,
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 6.5)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: foreground,
            ),
          ),
        ],
      ),
    ),
  );
}

pw.Widget _archProfile({
  required String title,
  required String secondaryLabel,
  required List<int> teeth,
  required PeriodontalChart chart,
  required bool blank,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.fromLTRB(7, 5, 7, 4),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _border, width: 0.6),
      borderRadius: pw.BorderRadius.circular(3),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: _navy,
              ),
            ),
            pw.Spacer(),
            _pdfLineKey('Buccal', _blue),
            pw.SizedBox(width: 8),
            _pdfLineKey(secondaryLabel, _teal),
            pw.SizedBox(width: 8),
            pw.Text('PD 0-15 mm', style: const pw.TextStyle(fontSize: 5.7)),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 13,
              height: 61,
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  for (final depth in [0, 3, 6, 9, 12, 15])
                    pw.Text(
                      '$depth',
                      style: const pw.TextStyle(fontSize: 4.7, color: _navy),
                    ),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.SizedBox(
                height: 61,
                child: pw.CustomPaint(
                  size: const PdfPoint(347, 61),
                  painter: (canvas, size) => _paintPdfProfile(
                    canvas,
                    size,
                    chart: chart,
                    teeth: teeth,
                    blank: blank,
                  ),
                ),
              ),
            ),
          ],
        ),
        pw.Row(
          children: [
            pw.SizedBox(width: 13),
            for (final fdi in teeth)
              pw.Expanded(
                child: pw.Text(
                  '$fdi',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 5.7, color: _navy),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _pdfLineKey(String label, PdfColor color) {
  return pw.Row(
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      pw.Container(width: 10, height: 2, color: color),
      pw.SizedBox(width: 3),
      pw.Text(label, style: const pw.TextStyle(fontSize: 5.7)),
    ],
  );
}

void _paintPdfProfile(
  PdfGraphics canvas,
  PdfPoint size, {
  required PeriodontalChart chart,
  required List<int> teeth,
  required bool blank,
}) {
  const maximumDepth = 15.0;
  const topBottomPadding = 2.0;
  final plotHeight = size.y - topBottomPadding * 2;
  final toothWidth = size.x / teeth.length;

  for (var depth = 0; depth <= maximumDepth; depth += 3) {
    final y = size.y - topBottomPadding - (depth / maximumDepth) * plotHeight;
    canvas
      ..setStrokeColor(depth == 6 ? _amber : _border)
      ..setLineWidth(depth == 6 ? 0.8 : 0.4)
      ..drawLine(0, y, size.x, y)
      ..strokePath();
  }

  for (var index = 0; index <= teeth.length; index++) {
    final x = index * toothWidth;
    canvas
      ..setStrokeColor(index == 8 ? _navy : _border)
      ..setLineWidth(index == 8 ? 0.8 : 0.35)
      ..drawLine(x, topBottomPadding, x, size.y - topBottomPadding)
      ..strokePath();
    if (index < teeth.length && chart.tooth(teeth[index]).missing) {
      canvas
        ..setFillColor(_softGrey)
        ..drawRect(x, topBottomPadding, toothWidth, plotHeight)
        ..fillPath();
    }
  }
  if (blank) return;

  _paintPdfSeries(
    canvas,
    size,
    chart: chart,
    teeth: teeth,
    sites: buccalPeriodontalSites,
    color: _blue,
  );
  _paintPdfSeries(
    canvas,
    size,
    chart: chart,
    teeth: teeth,
    sites: lingualPeriodontalSites,
    color: _teal,
  );
}

void _paintPdfSeries(
  PdfGraphics canvas,
  PdfPoint size, {
  required PeriodontalChart chart,
  required List<int> teeth,
  required List<PeriodontalSite> sites,
  required PdfColor color,
}) {
  const maximumDepth = 15.0;
  const padding = 2.0;
  final plotHeight = size.y - padding * 2;
  final step = size.x / (teeth.length * 3);
  final points = <({double x, double y, int depth, bool bop})?>[];

  for (var toothIndex = 0; toothIndex < teeth.length; toothIndex++) {
    final fdi = teeth[toothIndex];
    final tooth = chart.tooth(fdi);
    final visualSites = _visualSiteOrder(fdi, sites);
    for (var siteIndex = 0; siteIndex < visualSites.length; siteIndex++) {
      final measurement = tooth.measurement(visualSites[siteIndex]);
      final depth = tooth.missing ? null : measurement.probingDepth;
      if (depth == null) {
        points.add(null);
        continue;
      }
      points.add((
        x: (toothIndex * 3 + siteIndex + 0.5) * step,
        y: size.y - padding - (depth.clamp(0, 15) / maximumDepth) * plotHeight,
        depth: depth,
        bop: measurement.bleedingOnProbing,
      ));
    }
  }

  canvas
    ..setStrokeColor(color)
    ..setLineWidth(1.1);
  var pathOpen = false;
  for (final point in points) {
    if (point == null) {
      if (pathOpen) canvas.strokePath();
      pathOpen = false;
      continue;
    }
    if (!pathOpen) {
      canvas.moveTo(point.x, point.y);
      pathOpen = true;
    } else {
      canvas.lineTo(point.x, point.y);
    }
  }
  if (pathOpen) canvas.strokePath();

  for (final point in points.whereType<
      ({
        double x,
        double y,
        int depth,
        bool bop,
      })>()) {
    final pointColor = point.depth >= 6
        ? _red
        : point.depth >= 4
            ? _amber
            : color;
    canvas
      ..setFillColor(pointColor)
      ..drawEllipse(point.x, point.y, 1.5, 1.5)
      ..fillPath();
    if (point.bop) {
      canvas
        ..setStrokeColor(_red)
        ..setLineWidth(0.7)
        ..drawEllipse(point.x, point.y, 2.7, 2.7)
        ..strokePath();
    }
  }
}

pw.Widget _surfaceTable({
  required String title,
  required List<int> teeth,
  required List<PeriodontalSite> sites,
  required PeriodontalChart chart,
  required bool blank,
}) {
  final cellHeight = blank ? 18.2 : 12.2;
  final rows = <pw.TableRow>[
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: _paleBlue),
      children: [
        _pdfCell(
          title,
          bold: true,
          color: _navy,
          height: cellHeight,
        ),
        for (final fdi in teeth)
          _pdfCell(
            '$fdi',
            bold: true,
            color: _navy,
            center: true,
            height: cellHeight,
          ),
      ],
    ),
    for (final metric in ['PD', 'GM', 'CAL', 'BOP', 'PI'])
      pw.TableRow(
        children: [
          _pdfCell(
            metric,
            bold: true,
            color: _navy,
            height: cellHeight,
          ),
          for (final fdi in teeth)
            _pdfCell(
              blank
                  ? metric == 'BOP' || metric == 'PI'
                      ? '-/-/-'
                      : '__/__/__'
                  : _surfaceValue(chart.tooth(fdi), sites, metric),
              color: metric == 'BOP'
                  ? _red
                  : metric == 'PI'
                      ? _amber
                      : null,
              center: true,
              height: cellHeight,
            ),
        ],
      ),
    pw.TableRow(
      children: [
        _pdfCell(
          'Mob/F',
          bold: true,
          color: _navy,
          height: cellHeight,
        ),
        for (final fdi in teeth)
          _pdfCell(
            blank
                ? '__/__'
                : chart.tooth(fdi).missing
                    ? 'Missing'
                    : '${chart.tooth(fdi).mobility}/${chart.tooth(fdi).furcation}',
            center: true,
            height: cellHeight,
          ),
      ],
    ),
  ];
  return pw.Table(
    border: pw.TableBorder.all(color: _border, width: 0.45),
    columnWidths: {
      0: const pw.FixedColumnWidth(48),
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
  if (tooth.missing) return '-';
  return sites.map((site) {
    final measurement = tooth.measurement(site);
    return switch (metric) {
      'PD' => measurement.probingDepth?.toString() ?? '.',
      'GM' => measurement.gingivalMargin?.toString() ?? '.',
      'CAL' => measurement.clinicalAttachmentLevel?.toString() ?? '.',
      'BOP' => measurement.bleedingOnProbing ? '+' : '-',
      'PI' => measurement.plaque ? '+' : '-',
      _ => '.',
    };
  }).join('/');
}

pw.Widget _pdfCell(
  String value, {
  bool bold = false,
  PdfColor? color,
  bool center = false,
  double height = 12.2,
}) {
  return pw.Container(
    height: height,
    alignment: center ? pw.Alignment.center : pw.Alignment.centerLeft,
    padding: const pw.EdgeInsets.symmetric(horizontal: 1.6, vertical: 1.3),
    child: pw.Text(
      value,
      textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
      maxLines: 1,
      style: pw.TextStyle(
        fontSize: 5.25,
        fontWeight: bold ? pw.FontWeight.bold : null,
        color: color,
      ),
    ),
  );
}

pw.Widget _pdfFooter({required PeriodontalChart chart, required bool blank}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Container(height: 0.6, color: _border),
      pw.SizedBox(height: 4),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Text(
              blank
                  ? 'Notes / Σημειώσεις: ________________________________________________________________'
                  : chart.notes.trim().isEmpty
                      ? 'Notes / Σημειώσεις: -'
                      : 'Notes / Σημειώσεις: ${chart.notes.trim()}',
              maxLines: 2,
              overflow: pw.TextOverflow.clip,
              style: const pw.TextStyle(fontSize: 6.5),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Text(
            'Blue/teal: PD profile | Amber: 4-5 mm | Red: >=6 mm | Red ring: BOP',
            style: const pw.TextStyle(fontSize: 6, color: _navy),
          ),
        ],
      ),
    ],
  );
}

List<PeriodontalSite> _visualSiteOrder(
  int fdi,
  List<PeriodontalSite> sites,
) {
  final quadrant = fdi ~/ 10;
  return quadrant == 1 || quadrant == 4
      ? sites.reversed.toList(growable: false)
      : sites;
}
