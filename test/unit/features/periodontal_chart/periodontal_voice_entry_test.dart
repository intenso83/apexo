import 'package:apexo/features/periodontal_chart/periodontal_chart_model.dart';
import 'package:apexo/features/periodontal_chart/periodontal_voice_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PeriodontalNumberParser', () {
    test('recognizes digits plus English, Greek and German number words', () {
      expect(
        PeriodontalNumberParser.parse('3 four πέντε sechs 7'),
        [3, 4, 5, 6, 7],
      );
    });

    test('recognizes negative gingival-margin values', () {
      expect(
        PeriodontalNumberParser.parse('minus two, μείον τρία, minus vier'),
        [-2, -3, -4],
      );
    });
  });

  group('PeriodontalVoiceEntrySession', () {
    test('uses the same deterministic six-site sequence as the chart', () {
      final chart = PeriodontalChart.newExam(patientID: 'patient-1');
      chart.tooth(18).missing = true;
      final session = PeriodontalVoiceEntrySession(chart: chart);

      expect(session.current!.fdi, 17);
      expect(session.current!.site, PeriodontalSite.mesioBuccal);
      expect(session.applyTranscript('three two four'), 3);
      expect(
        chart.tooth(17).measurement(PeriodontalSite.mesioBuccal).probingDepth,
        3,
      );
      expect(
        chart.tooth(17).measurement(PeriodontalSite.buccal).probingDepth,
        2,
      );
      expect(
        chart.tooth(17).measurement(PeriodontalSite.distoBuccal).probingDepth,
        4,
      );
    });

    test('supports undo without coupling to a microphone implementation', () {
      final chart = PeriodontalChart.newExam(patientID: 'patient-1');
      final session = PeriodontalVoiceEntrySession(chart: chart);

      session.applyValue(5);
      session.undo();
      session.applyValue(4);

      expect(
        chart.tooth(18).measurement(PeriodontalSite.mesioBuccal).probingDepth,
        4,
      );
      expect(session.cursor, 1);
    });
  });
}
