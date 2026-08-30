import 'dart:convert';

import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/odontogram/treatment_target.dart';
import 'package:apexo/features/settings/settings_stores.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as image_lib;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'treatment_plan_model.dart';
import 'treatment_plan_translations.dart';

class TreatmentPlanBrandingSnapshot {
  const TreatmentPlanBrandingSnapshot({
    required this.brandEl,
    required this.brandEn,
    required this.brandDe,
    required this.logoBytes,
  });

  final String brandEl;
  final String brandEn;
  final String brandDe;
  final Uint8List logoBytes;

  String brand(TreatmentPlanLanguage language) => switch (language) {
        TreatmentPlanLanguage.el => brandEl,
        TreatmentPlanLanguage.en => brandEn,
        TreatmentPlanLanguage.de => brandDe,
      };
}

Future<TreatmentPlanBrandingSnapshot> loadTreatmentPlanBranding() async {
  Uint8List logoBytes;
  final stored = globalSettings.treatmentPlanLogoBase64;
  if (stored.isNotEmpty) {
    logoBytes = base64Decode(stored);
  } else {
    logoBytes = (await rootBundle.load('assets/images/treatment_plan_logo.gif'))
        .buffer
        .asUint8List();
  }
  return TreatmentPlanBrandingSnapshot(
    brandEl: globalSettings.treatmentPlanBrandEl,
    brandEn: globalSettings.treatmentPlanBrandEn,
    brandDe: globalSettings.treatmentPlanBrandDe,
    logoBytes: logoBytes,
  );
}

Future<Uint8List> buildTreatmentPlanPdf({
  required TreatmentPlan plan,
  required Patient patient,
  required TreatmentPlanBrandingSnapshot branding,
  required String currencyCode,
  ByteData? regularFontData,
  ByteData? boldFontData,
}) async {
  // Readex in the original project does not contain Greek glyphs. DejaVu Sans
  // keeps all three supported plan languages embedded in the exported PDF.
  final regularData =
      regularFontData ?? await rootBundle.load('assets/fonts/DejaVuSans.ttf');
  final boldData =
      boldFontData ?? await rootBundle.load('assets/fonts/DejaVuSans.ttf');
  final regular = pw.Font.ttf(regularData);
  final bold = pw.Font.ttf(boldData);
  final theme = pw.ThemeData.withFont(base: regular, bold: bold);
  final document = pw.Document(theme: theme);
  final language = plan.language;
  final localeName = switch (language) {
    TreatmentPlanLanguage.el => 'el_GR',
    TreatmentPlanLanguage.en => 'en_US',
    TreatmentPlanLanguage.de => 'de_DE',
  };
  final money = NumberFormat.currency(
    locale: localeName,
    symbol: currencyCode,
    decimalDigits: 2,
  );
  final date = DateFormat('dd/MM/yyyy');
  final logo = _pdfLogo(branding.logoBytes);
  const navy = PdfColor.fromInt(0xFF173B57);
  const blue = PdfColor.fromInt(0xFF547B92);
  const paleBlue = PdfColor.fromInt(0xFFEAF4F8);
  const paleTeal = PdfColor.fromInt(0xFFE6F6F3);
  const teal = PdfColor.fromInt(0xFF138A80);
  const grey = PdfColor.fromInt(0xFF647480);
  const border = PdfColor.fromInt(0xFFD7E4E9);

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(34, 28, 34, 30),
      header: (_) => pw.Column(
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logo != null)
                pw.Container(
                  width: 44,
                  height: 48,
                  margin: const pw.EdgeInsets.only(right: 12),
                  child: pw.Image(logo, fit: pw.BoxFit.contain),
                ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      branding.brand(language),
                      style: pw.TextStyle(
                        color: navy,
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      planText('treatmentPlan', language),
                      style: const pw.TextStyle(color: blue, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 9),
          pw.Container(height: 2, color: blue),
          pw.SizedBox(height: 12),
        ],
      ),
      footer: (context) => pw.Column(
        children: [
          pw.Container(height: 0.7, color: border),
          pw.SizedBox(height: 5),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                branding.brand(language),
                style: const pw.TextStyle(color: grey, fontSize: 7),
              ),
              pw.Text(
                '${context.pageNumber} / ${context.pagesCount}',
                style: const pw.TextStyle(color: grey, fontSize: 7),
              ),
            ],
          ),
        ],
      ),
      build: (_) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: paleBlue,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: border),
          ),
          child: pw.Row(
            children: [
              pw.Expanded(
                flex: 3,
                child: _labelValue(
                  planText('patient', language),
                  patient.title,
                  navy,
                  grey,
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                flex: 2,
                child: _labelValue(
                  planText('alternative', language),
                  plan.title,
                  navy,
                  grey,
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _labelValue(
                  planText('date', language),
                  date.format(plan.updatedAt),
                  navy,
                  grey,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
        if (plan.items.isEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.all(18),
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: border),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(planText('treatmentPlan', language)),
          )
        else
          _itemsTable(
            plan: plan,
            money: money,
            language: language,
            navy: navy,
            blue: blue,
            paleBlue: paleBlue,
            grey: grey,
            border: border,
          ),
        pw.SizedBox(height: 14),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Container(
            width: 270,
            padding: const pw.EdgeInsets.all(11),
            decoration: pw.BoxDecoration(
              color: paleTeal,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: border),
            ),
            child: pw.Column(
              children: [
                _summaryRow(
                  planText('grossTotal', language),
                  money.format(plan.gross),
                  grey,
                ),
                if (plan.itemDiscountTotal > 0)
                  _summaryRow(
                    planText('itemDiscounts', language),
                    '- ${money.format(plan.itemDiscountTotal)}',
                    grey,
                  ),
                if (plan.wholePlanDiscount > 0)
                  _summaryRow(
                    planText('planDiscount', language),
                    '- ${money.format(plan.wholePlanDiscount)}',
                    grey,
                  ),
                if (plan.totalDiscount > 0) ...[
                  pw.Divider(color: border),
                  _summaryRow(
                    planText('discountTotal', language),
                    '- ${money.format(plan.totalDiscount)}',
                    teal,
                    bold: true,
                  ),
                ],
                pw.Divider(color: border),
                _summaryRow(
                  planText('finalTotal', language),
                  money.format(plan.total),
                  navy,
                  bold: true,
                  fontSize: 12,
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 18),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: border),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                planText('consent', language),
                style: pw.TextStyle(
                  color: navy,
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 7),
              pw.Text(
                plan.consentText(language),
                style: const pw.TextStyle(color: grey, fontSize: 8.5),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                decoration: pw.BoxDecoration(
                  color: paleBlue,
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Text(
                  _consentStatus(plan.consentStatus, language),
                  style: pw.TextStyle(
                    color: blue,
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 30),
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.only(top: 4),
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(top: pw.BorderSide(color: grey)),
                      ),
                      child: pw.Text(
                        planText('signature', language),
                        style: const pw.TextStyle(color: grey, fontSize: 8),
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 30),
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.only(top: 4),
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(top: pw.BorderSide(color: grey)),
                      ),
                      child: pw.Text(
                        planText('date', language),
                        style: const pw.TextStyle(color: grey, fontSize: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          planText('estimateNotice', language),
          style: const pw.TextStyle(color: grey, fontSize: 7.5),
          textAlign: pw.TextAlign.center,
        ),
      ],
    ),
  );
  return document.save();
}

Future<void> previewTreatmentPlanPdf({
  required TreatmentPlan plan,
  required Patient patient,
}) async {
  final branding = await loadTreatmentPlanBranding();
  final bytes = await buildTreatmentPlanPdf(
    plan: plan,
    patient: patient,
    branding: branding,
    currencyCode: currency(),
  );
  await Printing.layoutPdf(
    name: 'Treatment plan - ${patient.title} - ${plan.title}',
    format: PdfPageFormat.a4,
    onLayout: (_) async => bytes,
  );
}

pw.MemoryImage? _pdfLogo(Uint8List source) {
  final decoded = image_lib.decodeImage(source);
  if (decoded == null) return null;
  return pw.MemoryImage(Uint8List.fromList(image_lib.encodePng(decoded)));
}

pw.Widget _labelValue(
  String label,
  String value,
  PdfColor valueColor,
  PdfColor labelColor,
) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(label, style: pw.TextStyle(color: labelColor, fontSize: 7)),
      pw.SizedBox(height: 2),
      pw.Text(
        value,
        style: pw.TextStyle(
          color: valueColor,
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    ],
  );
}

pw.Widget _itemsTable({
  required TreatmentPlan plan,
  required NumberFormat money,
  required TreatmentPlanLanguage language,
  required PdfColor navy,
  required PdfColor blue,
  required PdfColor paleBlue,
  required PdfColor grey,
  required PdfColor border,
}) {
  final headers = [
    '#',
    planText('treatment', language),
    planText('target', language),
    planText('quantity', language),
    planText('unitPrice', language),
    planText('discount', language),
    planText('amount', language),
  ];
  final widths = <int, pw.TableColumnWidth>{
    0: const pw.FixedColumnWidth(22),
    1: const pw.FlexColumnWidth(3.4),
    2: const pw.FlexColumnWidth(1.5),
    3: const pw.FixedColumnWidth(38),
    4: const pw.FixedColumnWidth(68),
    5: const pw.FixedColumnWidth(62),
    6: const pw.FixedColumnWidth(68),
  };
  return pw.Table(
    columnWidths: widths,
    border: pw.TableBorder.all(color: border, width: 0.6),
    children: [
      pw.TableRow(
        decoration: pw.BoxDecoration(color: paleBlue),
        children: headers
            .map((header) => pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    header,
                    style: pw.TextStyle(
                      color: navy,
                      fontSize: 7.2,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ))
            .toList(),
      ),
      ...plan.items.asMap().entries.map((entry) {
        final item = entry.value;
        final discount = item.monetaryDiscount == 0
            ? '-'
            : money.format(item.monetaryDiscount);
        final cells = [
          '${entry.key + 1}',
          item.displayName(language),
          _targetLabel(item, language),
          '${item.quantity}',
          money.format(item.unitPrice),
          discount,
          money.format(item.net),
        ];
        return pw.TableRow(
          children: cells
              .map((cell) => pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      cell,
                      style: pw.TextStyle(
                        color: cell == cells.last ? blue : grey,
                        fontSize: 7.4,
                        fontWeight: cell == cells.last
                            ? pw.FontWeight.bold
                            : pw.FontWeight.normal,
                      ),
                    ),
                  ))
              .toList(),
        );
      }),
    ],
  );
}

pw.Widget _summaryRow(
  String label,
  String amount,
  PdfColor color, {
  bool bold = false,
  double fontSize = 9,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          amount,
          style: pw.TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    ),
  );
}

String _targetLabel(
  TreatmentPlanItem item,
  TreatmentPlanLanguage language,
) {
  switch (item.targetScope) {
    case TreatmentTargetScope.patient:
      return planText('generalPatient', language);
    case TreatmentTargetScope.tooth:
      return item.toothFdi == null
          ? '-'
          : '${planText('tooth', language)} ${item.toothFdi}';
    case TreatmentTargetScope.bridge:
      final teeth = item.bridgeUnits.map((unit) => unit.toothFdi).join(', ');
      return teeth.isEmpty
          ? planText('bridge', language)
          : '${planText('bridge', language)} $teeth';
    case TreatmentTargetScope.removableProsthesis:
      return switch (item.arch) {
        DentalArch.upper => planText('upperArch', language),
        DentalArch.lower => planText('lowerArch', language),
        DentalArch.both => planText('bothArches', language),
        DentalArch.unspecified => '-',
      };
  }
}

String _consentStatus(
  TreatmentPlanConsentStatus status,
  TreatmentPlanLanguage language,
) =>
    planText(status.name, language);
