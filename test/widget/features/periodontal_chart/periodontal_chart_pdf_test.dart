import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/periodontal_chart/periodontal_chart_model.dart';
import 'package:apexo/features/periodontal_chart/periodontal_chart_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('builds a landscape periodontal PDF with clinical data',
      (tester) async {
    final patient = Patient.fromJson({
      'id': 'patient1234567',
      'title': 'Demo Patient',
    });
    final chart = PeriodontalChart.newExam(patientID: patient.id);
    chart.notes = 'Periodontal reassessment';
    chart.tooth(16).measurement(PeriodontalSite.mesioBuccal)
      ..probingDepth = 6
      ..gingivalMargin = 2
      ..bleedingOnProbing = true;

    final bytes = await buildPeriodontalChartPdf(
      chart: chart,
      patient: patient,
    );

    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
