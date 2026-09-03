import 'package:apexo/core/model.dart';

const upperPeriodontalTeeth = <int>[
  18,
  17,
  16,
  15,
  14,
  13,
  12,
  11,
  21,
  22,
  23,
  24,
  25,
  26,
  27,
  28,
];

const lowerPeriodontalTeeth = <int>[
  48,
  47,
  46,
  45,
  44,
  43,
  42,
  41,
  31,
  32,
  33,
  34,
  35,
  36,
  37,
  38,
];

const allPeriodontalTeeth = <int>[
  ...upperPeriodontalTeeth,
  ...lowerPeriodontalTeeth,
];

/// Canonical six-site periodontal order.
///
/// Keeping this order stable is important: the visual editor, keyboard entry,
/// PDF export and future voice transcription adapter all consume the same
/// sequence.
enum PeriodontalSite {
  mesioBuccal,
  buccal,
  distoBuccal,
  mesioLingual,
  lingual,
  distoLingual,
}

const buccalPeriodontalSites = <PeriodontalSite>[
  PeriodontalSite.mesioBuccal,
  PeriodontalSite.buccal,
  PeriodontalSite.distoBuccal,
];

const lingualPeriodontalSites = <PeriodontalSite>[
  PeriodontalSite.mesioLingual,
  PeriodontalSite.lingual,
  PeriodontalSite.distoLingual,
];

extension PeriodontalSiteLabels on PeriodontalSite {
  String get abbreviation => switch (this) {
        PeriodontalSite.mesioBuccal => 'MB',
        PeriodontalSite.buccal => 'B',
        PeriodontalSite.distoBuccal => 'DB',
        PeriodontalSite.mesioLingual => 'ML',
        PeriodontalSite.lingual => 'L',
        PeriodontalSite.distoLingual => 'DL',
      };
}

class PeriodontalMeasurement {
  PeriodontalMeasurement({
    this.probingDepth,
    this.gingivalMargin,
    this.bleedingOnProbing = false,
    this.plaque = false,
    this.suppuration = false,
  });

  int? probingDepth;

  /// Millimetres from the CEJ: positive for recession, negative for gingival
  /// enlargement. CAL is therefore probing depth + gingival margin.
  int? gingivalMargin;
  bool bleedingOnProbing;
  bool plaque;
  bool suppuration;

  int? get clinicalAttachmentLevel {
    if (probingDepth == null) return null;
    return probingDepth! + (gingivalMargin ?? 0);
  }

  factory PeriodontalMeasurement.fromJson(Map<String, dynamic> json) {
    return PeriodontalMeasurement(
      probingDepth: _nullableInt(json['probing_depth']),
      gingivalMargin: _nullableInt(json['gingival_margin']),
      bleedingOnProbing: json['bleeding_on_probing'] == true,
      plaque: json['plaque'] == true,
      suppuration: json['suppuration'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        if (probingDepth != null) 'probing_depth': probingDepth,
        if (gingivalMargin != null) 'gingival_margin': gingivalMargin,
        if (bleedingOnProbing) 'bleeding_on_probing': true,
        if (plaque) 'plaque': true,
        if (suppuration) 'suppuration': true,
      };

  PeriodontalMeasurement copy() => PeriodontalMeasurement.fromJson(toJson());
}

class PeriodontalTooth {
  PeriodontalTooth({
    required this.fdi,
    this.missing = false,
    this.implant = false,
    this.mobility = 0,
    this.furcation = 0,
    Map<PeriodontalSite, PeriodontalMeasurement>? sites,
  }) : sites = sites ??
            {
              for (final site in PeriodontalSite.values)
                site: PeriodontalMeasurement(),
            };

  int fdi;
  bool missing;
  bool implant;
  int mobility;
  int furcation;
  Map<PeriodontalSite, PeriodontalMeasurement> sites;

  PeriodontalMeasurement measurement(PeriodontalSite site) =>
      sites.putIfAbsent(site, PeriodontalMeasurement.new);

  factory PeriodontalTooth.fromJson(Map<String, dynamic> json) {
    final fdi = _nullableInt(json['fdi']) ?? 0;
    final rawSites = Map<String, dynamic>.from(json['sites'] ?? const {});
    return PeriodontalTooth(
      fdi: fdi,
      missing: json['missing'] == true,
      implant: json['implant'] == true,
      mobility: (_nullableInt(json['mobility']) ?? 0).clamp(0, 3),
      furcation: (_nullableInt(json['furcation']) ?? 0).clamp(0, 3),
      sites: {
        for (final site in PeriodontalSite.values)
          site: rawSites[site.name] is Map
              ? PeriodontalMeasurement.fromJson(
                  Map<String, dynamic>.from(rawSites[site.name] as Map),
                )
              : PeriodontalMeasurement(),
      },
    );
  }

  Map<String, dynamic> toJson() => {
        'fdi': fdi,
        if (missing) 'missing': true,
        if (implant) 'implant': true,
        if (mobility > 0) 'mobility': mobility,
        if (furcation > 0) 'furcation': furcation,
        'sites': {
          for (final entry in sites.entries)
            entry.key.name: entry.value.toJson(),
        },
      };

  PeriodontalTooth copy() => PeriodontalTooth.fromJson(toJson());
}

class PeriodontalSummary {
  const PeriodontalSummary({
    required this.measuredSites,
    required this.bleedingSites,
    required this.plaqueSites,
    required this.deepSites,
    required this.veryDeepSites,
    required this.maximumProbingDepth,
  });

  final int measuredSites;
  final int bleedingSites;
  final int plaqueSites;
  final int deepSites;
  final int veryDeepSites;
  final int maximumProbingDepth;

  double get bleedingPercentage =>
      measuredSites == 0 ? 0 : bleedingSites * 100 / measuredSites;
  double get plaquePercentage =>
      measuredSites == 0 ? 0 : plaqueSites * 100 / measuredSites;
}

/// One immutable periodontal examination snapshot.
class PeriodontalChart extends Model {
  PeriodontalChart.fromJson(super.json) : super.fromJson();

  String patientID = '';
  int revisionNumber = 1;
  String previousChartID = '';
  DateTime recordedAt = DateTime.now().toUtc();
  String notes = '';
  Map<int, PeriodontalTooth> teeth = {};

  PeriodontalTooth tooth(int fdi) =>
      teeth.putIfAbsent(fdi, () => PeriodontalTooth(fdi: fdi));

  PeriodontalSummary get summary {
    var measured = 0;
    var bleeding = 0;
    var plaque = 0;
    var deep = 0;
    var veryDeep = 0;
    var maximum = 0;
    for (final tooth in teeth.values) {
      if (tooth.missing) continue;
      for (final measurement in tooth.sites.values) {
        final depth = measurement.probingDepth;
        if (depth == null) continue;
        measured++;
        if (measurement.bleedingOnProbing) bleeding++;
        if (measurement.plaque) plaque++;
        if (depth >= 4) deep++;
        if (depth >= 6) veryDeep++;
        if (depth > maximum) maximum = depth;
      }
    }
    return PeriodontalSummary(
      measuredSites: measured,
      bleedingSites: bleeding,
      plaqueSites: plaque,
      deepSites: deep,
      veryDeepSites: veryDeep,
      maximumProbingDepth: maximum,
    );
  }

  factory PeriodontalChart.newExam({
    required String patientID,
    PeriodontalChart? previous,
  }) {
    final chart = PeriodontalChart.fromJson({
      'patient_id': patientID,
      'revision_number': (previous?.revisionNumber ?? 0) + 1,
      if (previous != null) 'previous_chart_id': previous.id,
      'recorded_at': DateTime.now().toUtc().toIso8601String(),
    });
    // A new examination must never silently reuse old probing values. Only
    // durable tooth state is carried forward; every clinical site begins
    // blank and must be measured again.
    if (previous != null) {
      for (final fdi in allPeriodontalTeeth) {
        final oldTooth = previous.tooth(fdi);
        chart.teeth[fdi] = PeriodontalTooth(
          fdi: fdi,
          missing: oldTooth.missing,
          implant: oldTooth.implant,
        );
      }
    }
    chart.title = 'Periodontal chart ${chart.revisionNumber}';
    return chart;
  }

  @override
  void fromJson(Map<String, dynamic> json) {
    super.fromJson(json);
    patientID = json['patient_id']?.toString() ?? patientID;
    revisionNumber = _nullableInt(json['revision_number']) ?? revisionNumber;
    previousChartID = json['previous_chart_id']?.toString() ?? previousChartID;
    recordedAt =
        DateTime.tryParse(json['recorded_at']?.toString() ?? '')?.toUtc() ??
            recordedAt;
    notes = json['notes']?.toString() ?? notes;
    final rawTeeth = Map<String, dynamic>.from(json['teeth'] ?? const {});
    teeth = {
      for (final entry in rawTeeth.entries)
        if (entry.value is Map)
          int.tryParse(entry.key) ?? 0: PeriodontalTooth.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          ),
    }..remove(0);
    for (final fdi in allPeriodontalTeeth) {
      teeth.putIfAbsent(fdi, () => PeriodontalTooth(fdi: fdi));
    }
    title = title.isEmpty ? 'Periodontal chart $revisionNumber' : title;
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['patient_id'] = patientID;
    json['revision_number'] = revisionNumber;
    if (previousChartID.isNotEmpty) {
      json['previous_chart_id'] = previousChartID;
    }
    json['recorded_at'] = recordedAt.toUtc().toIso8601String();
    if (notes.trim().isNotEmpty) json['notes'] = notes.trim();
    json['teeth'] = {
      for (final entry in teeth.entries)
        entry.key.toString(): entry.value.toJson(),
    };
    return json;
  }

  @override
  PeriodontalChart copy(bool blank) =>
      PeriodontalChart.fromJson(blank ? {} : toJson());
}

int? _nullableInt(dynamic value) {
  if (value == null || value.toString().trim().isEmpty) return null;
  if (value is num) return value.round();
  return int.tryParse(value.toString());
}
