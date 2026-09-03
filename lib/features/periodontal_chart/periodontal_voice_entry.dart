import 'periodontal_chart_model.dart';

enum PeriodontalVoiceMetric { probingDepth, gingivalMargin }

class PeriodontalVoiceTarget {
  const PeriodontalVoiceTarget({
    required this.fdi,
    required this.site,
    required this.metric,
  });

  final int fdi;
  final PeriodontalSite site;
  final PeriodontalVoiceMetric metric;
}

/// Deterministic adapter between measurements and future speech recognition.
///
/// This class deliberately has no microphone or cloud dependency. A later
/// on-device or remote recognizer only needs to pass validated transcripts to
/// [applyTranscript]. The chart UI and persistence model remain unchanged.
class PeriodontalVoiceEntrySession {
  PeriodontalVoiceEntrySession({
    required this.chart,
    this.metric = PeriodontalVoiceMetric.probingDepth,
  }) : targets = _targets(chart, metric);

  final PeriodontalChart chart;
  final PeriodontalVoiceMetric metric;
  final List<PeriodontalVoiceTarget> targets;
  int cursor = 0;

  PeriodontalVoiceTarget? get current =>
      cursor >= 0 && cursor < targets.length ? targets[cursor] : null;
  bool get isComplete => cursor >= targets.length;

  int applyTranscript(String transcript) {
    final values = PeriodontalNumberParser.parse(transcript);
    var applied = 0;
    for (final value in values) {
      if (isComplete) break;
      applyValue(value);
      applied++;
    }
    return applied;
  }

  void applyValue(int value) {
    final target = current;
    if (target == null) return;
    final measurement = chart.tooth(target.fdi).measurement(target.site);
    switch (target.metric) {
      case PeriodontalVoiceMetric.probingDepth:
        measurement.probingDepth = value.clamp(0, 15);
      case PeriodontalVoiceMetric.gingivalMargin:
        measurement.gingivalMargin = value.clamp(-10, 15);
    }
    cursor++;
  }

  void skip() {
    if (!isComplete) cursor++;
  }

  void undo() {
    if (cursor > 0) cursor--;
  }

  static List<PeriodontalVoiceTarget> _targets(
    PeriodontalChart chart,
    PeriodontalVoiceMetric metric,
  ) {
    return [
      for (final fdi in allPeriodontalTeeth)
        if (!chart.tooth(fdi).missing)
          for (final site in PeriodontalSite.values)
            PeriodontalVoiceTarget(fdi: fdi, site: site, metric: metric),
    ];
  }
}

class PeriodontalNumberParser {
  PeriodontalNumberParser._();

  static const _numberWords = <String, int>{
    // English
    'zero': 0,
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'eleven': 11,
    'twelve': 12,
    'thirteen': 13,
    'fourteen': 14,
    'fifteen': 15,
    // Greek, normalized without accents.
    'μηδεν': 0,
    'ενα': 1,
    'μια': 1,
    'δυο': 2,
    'τρια': 3,
    'τεσσερα': 4,
    'πεντε': 5,
    'εξι': 6,
    'επτα': 7,
    'εφτα': 7,
    'οκτω': 8,
    'οχτω': 8,
    'εννεα': 9,
    'εννια': 9,
    'δεκα': 10,
    'εντεκα': 11,
    'δωδεκα': 12,
    'δεκατρια': 13,
    'δεκατεσσερα': 14,
    'δεκαπεντε': 15,
    // German
    'null': 0,
    'eins': 1,
    'ein': 1,
    'zwei': 2,
    'drei': 3,
    'vier': 4,
    'funf': 5,
    'fuenf': 5,
    'sechs': 6,
    'sieben': 7,
    'acht': 8,
    'neun': 9,
    'zehn': 10,
    'elf': 11,
    'zwolf': 12,
    'zwoelf': 12,
    'dreizehn': 13,
    'vierzehn': 14,
    'funfzehn': 15,
    'fuenfzehn': 15,
  };

  static List<int> parse(String transcript) {
    final normalized = _normalize(transcript)
        .replaceAll(RegExp(r'[^a-zα-ω0-9\-]+', unicode: true), ' ');
    final tokens = normalized.split(RegExp(r'\s+')).where((x) => x.isNotEmpty);
    final values = <int>[];
    var negativeNext = false;
    for (final token in tokens) {
      if ({'minus', 'μειον', 'negative'}.contains(token)) {
        negativeNext = true;
        continue;
      }
      final parsed = int.tryParse(token) ?? _numberWords[token];
      if (parsed == null) continue;
      values.add(negativeNext ? -parsed : parsed);
      negativeNext = false;
    }
    return values;
  }

  static String _normalize(String input) {
    var value = input.toLowerCase();
    const replacements = <String, String>{
      'ά': 'α',
      'έ': 'ε',
      'ή': 'η',
      'ί': 'ι',
      'ϊ': 'ι',
      'ΐ': 'ι',
      'ό': 'ο',
      'ύ': 'υ',
      'ϋ': 'υ',
      'ΰ': 'υ',
      'ώ': 'ω',
      'ä': 'a',
      'ö': 'o',
      'ü': 'u',
      'ß': 'ss',
    };
    for (final entry in replacements.entries) {
      value = value.replaceAll(entry.key, entry.value);
    }
    return value;
  }
}
