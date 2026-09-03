import 'package:apexo/features/periodontal_chart/periodontal_chart_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PeriodontalChart', () {
    test('creates a complete permanent-dentition six-site baseline', () {
      final chart = PeriodontalChart.newExam(patientID: 'patient-1');

      expect(chart.teeth.length, 32);
      expect(chart.teeth[18]!.sites.length, 6);
      expect(chart.summary.measuredSites, 0);
    });

    test('calculates CAL and clinical summary while skipping missing teeth',
        () {
      final chart = PeriodontalChart.newExam(patientID: 'patient-1');
      final first = chart.tooth(18).measurement(PeriodontalSite.mesioBuccal)
        ..probingDepth = 6
        ..gingivalMargin = 2
        ..bleedingOnProbing = true
        ..plaque = true;
      chart.tooth(17).missing = true;
      chart.tooth(17).measurement(PeriodontalSite.mesioBuccal)
        ..probingDepth = 9
        ..bleedingOnProbing = true;

      expect(first.clinicalAttachmentLevel, 8);
      expect(chart.summary.measuredSites, 1);
      expect(chart.summary.maximumProbingDepth, 6);
      expect(chart.summary.deepSites, 1);
      expect(chart.summary.veryDeepSites, 1);
      expect(chart.summary.bleedingPercentage, 100);
      expect(chart.summary.plaquePercentage, 100);
    });

    test('round-trips every structured measurement field', () {
      final chart = PeriodontalChart.newExam(patientID: 'patient-1');
      chart.tooth(36)
        ..implant = true
        ..mobility = 2
        ..furcation = 3;
      chart.tooth(36).measurement(PeriodontalSite.distoLingual)
        ..probingDepth = 7
        ..gingivalMargin = -1
        ..bleedingOnProbing = true
        ..plaque = true
        ..suppuration = true;

      final restored = PeriodontalChart.fromJson(chart.toJson());
      final tooth = restored.tooth(36);
      final site = tooth.measurement(PeriodontalSite.distoLingual);

      expect(restored.patientID, 'patient-1');
      expect(tooth.implant, isTrue);
      expect(tooth.mobility, 2);
      expect(tooth.furcation, 3);
      expect(site.probingDepth, 7);
      expect(site.gingivalMargin, -1);
      expect(site.clinicalAttachmentLevel, 6);
      expect(site.bleedingOnProbing, isTrue);
      expect(site.plaque, isTrue);
      expect(site.suppuration, isTrue);
    });

    test('new exam keeps tooth state but clears old clinical measurements', () {
      final first = PeriodontalChart.newExam(patientID: 'patient-1');
      first.tooth(11).measurement(PeriodontalSite.buccal).probingDepth = 4;
      first.tooth(16).implant = true;
      first.tooth(18).missing = true;

      final second = PeriodontalChart.newExam(
        patientID: 'patient-1',
        previous: first,
      );

      expect(second.id, isNot(first.id));
      expect(second.previousChartID, first.id);
      expect(second.revisionNumber, 2);
      expect(second.tooth(11).measurement(PeriodontalSite.buccal).probingDepth,
          isNull);
      expect(second.tooth(16).implant, isTrue);
      expect(second.tooth(18).missing, isTrue);
    });
  });
}
