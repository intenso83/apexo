import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';

import 'periodontal_chart_model.dart';
import 'periodontal_chart_pdf.dart';
import 'periodontal_chart_store.dart';

class PatientPeriodontalChart extends StatefulWidget {
  const PatientPeriodontalChart({
    super.key,
    required this.patient,
    this.charts,
    this.onChartSaved,
  });

  final Patient patient;
  final List<PeriodontalChart>? charts;
  final ValueChanged<PeriodontalChart>? onChartSaved;

  @override
  State<PatientPeriodontalChart> createState() =>
      _PatientPeriodontalChartState();
}

class _PatientPeriodontalChartState extends State<PatientPeriodontalChart> {
  PeriodontalChart? _draft;
  PeriodontalChart? _viewing;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream:
          widget.charts == null ? periodontalCharts.observableMap.stream : null,
      builder: (context, snapshot) {
        final charts =
            widget.charts ?? periodontalCharts.forPatient(widget.patient.id);
        final chart = _draft ?? _viewing;
        if (chart != null) {
          return PeriodontalChartEditor(
            chart: chart,
            patient: widget.patient,
            readOnly: _draft == null,
            onCancel: () => setState(() {
              _draft = null;
              _viewing = null;
            }),
            onSave: _draft == null ? null : _saveDraft,
          );
        }
        return _PeriodontalHistory(
          charts: charts,
          patient: widget.patient,
          onCreate: () {
            setState(() {
              _draft = PeriodontalChart.newExam(
                patientID: widget.patient.id,
                previous: charts.isEmpty ? null : charts.first,
              );
            });
          },
          onOpen: (chart) => setState(() => _viewing = chart),
        );
      },
    );
  }

  void _saveDraft() {
    final chart = _draft!;
    chart.recordedAt = DateTime.now().toUtc();
    chart.title = 'Periodontal chart ${chart.revisionNumber}';
    if (widget.onChartSaved != null) {
      widget.onChartSaved!(chart);
    } else {
      periodontalCharts.addChart(chart);
    }
    setState(() => _draft = null);
  }
}

class _PeriodontalHistory extends StatelessWidget {
  const _PeriodontalHistory({
    required this.charts,
    required this.patient,
    required this.onCreate,
    required this.onOpen,
  });

  final List<PeriodontalChart> charts;
  final Patient patient;
  final VoidCallback onCreate;
  final ValueChanged<PeriodontalChart> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(txt('periodontalChart'),
                      style: theme.typography.subtitle),
                  const SizedBox(height: 3),
                  Text(
                    txt('periodontalChartHistoryDescription'),
                    style: theme.typography.caption,
                  ),
                ],
              ),
            ),
            FilledButton(
              key: const ValueKey('new-periodontal-exam'),
              onPressed: onCreate,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(FluentIcons.add, size: 14),
                  const SizedBox(width: 6),
                  Text(txt('newPeriodontalExam')),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (charts.isEmpty)
          InfoBar(
            severity: InfoBarSeverity.info,
            title: Text(txt('noPeriodontalExams')),
            content: Text(txt('noPeriodontalExamsDescription')),
          )
        else
          for (final chart in charts) ...[
            _HistoryCard(
              chart: chart,
              onOpen: () => onOpen(chart),
              onPrint: () =>
                  printPeriodontalChart(chart: chart, patient: patient),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.chart,
    required this.onOpen,
    required this.onPrint,
  });

  final PeriodontalChart chart;
  final VoidCallback onOpen;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final summary = chart.summary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.resources.cardStrokeColorDefault),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.accentColor.withAlpha(24),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${chart.revisionNumber}',
              style: theme.typography.subtitle?.copyWith(
                color: theme.accentColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('dd/MM/yyyy HH:mm')
                      .format(chart.recordedAt.toLocal()),
                  style: theme.typography.bodyStrong,
                ),
                const SizedBox(height: 4),
                Text(
                  '${txt('periodontalMeasuredSites')}: ${summary.measuredSites}  ·  '
                  'BOP ${summary.bleedingPercentage.toStringAsFixed(0)}%  ·  '
                  '${txt('periodontalMaxPocket')} ${summary.maximumProbingDepth} mm',
                  style: theme.typography.caption,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(FluentIcons.print, size: 16),
            onPressed: onPrint,
          ),
          const SizedBox(width: 4),
          Button(onPressed: onOpen, child: Text(txt('open'))),
        ],
      ),
    );
  }
}

class PeriodontalChartEditor extends StatefulWidget {
  const PeriodontalChartEditor({
    super.key,
    required this.chart,
    required this.patient,
    required this.readOnly,
    required this.onCancel,
    this.onSave,
  });

  final PeriodontalChart chart;
  final Patient patient;
  final bool readOnly;
  final VoidCallback onCancel;
  final VoidCallback? onSave;

  @override
  State<PeriodontalChartEditor> createState() => _PeriodontalChartEditorState();
}

class _PeriodontalChartEditorState extends State<PeriodontalChartEditor> {
  late final TextEditingController _notesController;

  PeriodontalChart get chart => widget.chart;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: chart.notes);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EditorHeader(
          chart: chart,
          readOnly: widget.readOnly,
          onBack: widget.onCancel,
          onPrint: () =>
              printPeriodontalChart(chart: chart, patient: widget.patient),
        ),
        const SizedBox(height: 10),
        _SummaryStrip(summary: chart.summary),
        const SizedBox(height: 10),
        InfoBar(
          severity: InfoBarSeverity.info,
          title: Text(txt('periodontalVoiceReady')),
          content: Text(txt('periodontalVoiceReadyDescription')),
        ),
        const SizedBox(height: 12),
        _ArchEditor(
          label: txt('upperArch'),
          teeth: upperPeriodontalTeeth,
          chart: chart,
          readOnly: widget.readOnly,
          onChanged: _changed,
        ),
        const SizedBox(height: 14),
        _ArchEditor(
          label: txt('lowerArch'),
          teeth: lowerPeriodontalTeeth,
          chart: chart,
          readOnly: widget.readOnly,
          onChanged: _changed,
        ),
        const SizedBox(height: 14),
        InfoLabel(
          label: txt('notes'),
          child: TextBox(
            controller: _notesController,
            enabled: !widget.readOnly,
            minLines: 2,
            maxLines: 4,
            onChanged: (value) => chart.notes = value,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Button(
              onPressed: widget.onCancel,
              child: Text(widget.readOnly ? txt('back') : txt('cancel')),
            ),
            if (!widget.readOnly) ...[
              const SizedBox(width: 8),
              FilledButton(
                key: const ValueKey('save-periodontal-exam'),
                onPressed: widget.onSave,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(FluentIcons.save, size: 14),
                    const SizedBox(width: 6),
                    Text(txt('savePeriodontalExam')),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _changed() => setState(() {});
}

class _EditorHeader extends StatelessWidget {
  const _EditorHeader({
    required this.chart,
    required this.readOnly,
    required this.onBack,
    required this.onPrint,
  });

  final PeriodontalChart chart;
  final bool readOnly;
  final VoidCallback onBack;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Row(
      children: [
        IconButton(
          icon: const Icon(FluentIcons.back, size: 16),
          onPressed: onBack,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${txt('periodontalChart')} · #${chart.revisionNumber}',
                style: theme.typography.subtitle,
              ),
              Text(
                readOnly
                    ? DateFormat('dd/MM/yyyy HH:mm')
                        .format(chart.recordedAt.toLocal())
                    : txt('newPeriodontalExamDescription'),
                style: theme.typography.caption,
              ),
            ],
          ),
        ),
        Button(
          onPressed: onPrint,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(FluentIcons.print, size: 14),
              const SizedBox(width: 6),
              Text(txt('print')),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.summary});

  final PeriodontalSummary summary;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _SummaryTile(
          label: txt('periodontalMeasuredSites'),
          value: '${summary.measuredSites}',
          icon: FluentIcons.number_field,
        ),
        _SummaryTile(
          label: 'BOP',
          value: '${summary.bleedingPercentage.toStringAsFixed(0)}%',
          icon: FluentIcons.drop,
          alert: summary.bleedingPercentage >= 20,
        ),
        _SummaryTile(
          label: txt('periodontalPlaque'),
          value: '${summary.plaquePercentage.toStringAsFixed(0)}%',
          icon: FluentIcons.circle_fill,
          alert: summary.plaquePercentage >= 20,
        ),
        _SummaryTile(
          label: txt('periodontalMaxPocket'),
          value: '${summary.maximumProbingDepth} mm',
          icon: FluentIcons.down,
          alert: summary.maximumProbingDepth >= 6,
        ),
        _SummaryTile(
          label: 'PD ≥ 4 mm',
          value: '${summary.deepSites}',
          icon: FluentIcons.warning,
        ),
        _SummaryTile(
          label: 'PD ≥ 6 mm',
          value: '${summary.veryDeepSites}',
          icon: FluentIcons.warning,
          alert: summary.veryDeepSites > 0,
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    this.alert = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final color = alert ? Colors.red.dark : theme.accentColor;
    return Container(
      width: 132,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withAlpha(55)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.caption),
                Text(value,
                    style: theme.typography.bodyStrong?.copyWith(color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchEditor extends StatelessWidget {
  const _ArchEditor({
    required this.label,
    required this.teeth,
    required this.chart,
    required this.readOnly,
    required this.onChanged,
  });

  final String label;
  final List<int> teeth;
  final PeriodontalChart chart;
  final bool readOnly;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.typography.bodyStrong),
        const SizedBox(height: 7),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final fdi in teeth) ...[
                _ToothEditor(
                  tooth: chart.tooth(fdi),
                  readOnly: readOnly,
                  onChanged: onChanged,
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ToothEditor extends StatelessWidget {
  const _ToothEditor({
    required this.tooth,
    required this.readOnly,
    required this.onChanged,
  });

  final PeriodontalTooth tooth;
  final bool readOnly;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Container(
      width: 214,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: tooth.missing
            ? theme.resources.cardStrokeColorDefault.withAlpha(30)
            : theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: tooth.implant
              ? Colors.teal
              : theme.resources.cardStrokeColorDefault,
          width: tooth.implant ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('${tooth.fdi}', style: theme.typography.subtitle),
              const Spacer(),
              Text(txt('missingTooth'), style: theme.typography.caption),
              const SizedBox(width: 4),
              Checkbox(
                checked: tooth.missing,
                onChanged: readOnly
                    ? null
                    : (value) {
                        tooth.missing = value == true;
                        onChanged();
                      },
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Checkbox(
                checked: tooth.implant,
                onChanged: readOnly || tooth.missing
                    ? null
                    : (value) {
                        tooth.implant = value == true;
                        onChanged();
                      },
              ),
              const SizedBox(width: 4),
              Text(txt('periodontalImplant'), style: theme.typography.caption),
              const Spacer(),
              _SmallNumber(
                tooltip: txt('periodontalMobility'),
                value: tooth.mobility,
                min: 0,
                max: 3,
                enabled: !readOnly && !tooth.missing,
                onChanged: (value) {
                  tooth.mobility = value ?? 0;
                  onChanged();
                },
              ),
              const SizedBox(width: 4),
              _SmallNumber(
                tooltip: txt('periodontalFurcation'),
                value: tooth.furcation,
                min: 0,
                max: 3,
                enabled: !readOnly && !tooth.missing,
                onChanged: (value) {
                  tooth.furcation = value ?? 0;
                  onChanged();
                },
              ),
            ],
          ),
          const SizedBox(height: 7),
          Opacity(
            opacity: tooth.missing ? 0.35 : 1,
            child: IgnorePointer(
              ignoring: tooth.missing,
              child: Column(
                children: [
                  _SurfaceEditor(
                    label: txt('periodontalBuccal'),
                    sites: buccalPeriodontalSites,
                    tooth: tooth,
                    readOnly: readOnly,
                    onChanged: onChanged,
                  ),
                  const Divider(size: 13),
                  _SurfaceEditor(
                    label: tooth.fdi < 30
                        ? txt('periodontalPalatal')
                        : txt('periodontalLingual'),
                    sites: lingualPeriodontalSites,
                    tooth: tooth,
                    readOnly: readOnly,
                    onChanged: onChanged,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SurfaceEditor extends StatelessWidget {
  const _SurfaceEditor({
    required this.label,
    required this.sites,
    required this.tooth,
    required this.readOnly,
    required this.onChanged,
  });

  final String label;
  final List<PeriodontalSite> sites;
  final PeriodontalTooth tooth;
  final bool readOnly;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Column(
      children: [
        Text(label,
            style: theme.typography.caption?.copyWith(
              fontWeight: FontWeight.w600,
            )),
        const SizedBox(height: 3),
        _MetricRow(
          label: '',
          children: [
            for (final site in sites)
              SizedBox(
                width: 40,
                child: Text(
                  site.abbreviation,
                  textAlign: TextAlign.center,
                  style: theme.typography.caption,
                ),
              ),
          ],
        ),
        _MetricRow(
          label: 'PD',
          children: [
            for (final site in sites)
              _SmallNumber(
                tooltip: '${site.abbreviation} · PD',
                value: tooth.measurement(site).probingDepth,
                min: 0,
                max: 15,
                enabled: !readOnly,
                alert: (tooth.measurement(site).probingDepth ?? 0) >= 6,
                onChanged: (value) {
                  tooth.measurement(site).probingDepth = value;
                  onChanged();
                },
              ),
          ],
        ),
        const SizedBox(height: 3),
        _MetricRow(
          label: 'GM',
          children: [
            for (final site in sites)
              _SmallNumber(
                tooltip: '${site.abbreviation} · GM',
                value: tooth.measurement(site).gingivalMargin,
                min: -10,
                max: 15,
                enabled: !readOnly,
                onChanged: (value) {
                  tooth.measurement(site).gingivalMargin = value;
                  onChanged();
                },
              ),
          ],
        ),
        const SizedBox(height: 3),
        _MetricRow(
          label: 'CAL',
          children: [
            for (final site in sites)
              SizedBox(
                width: 40,
                child: Text(
                  tooth.measurement(site).clinicalAttachmentLevel?.toString() ??
                      '–',
                  textAlign: TextAlign.center,
                  style: theme.typography.bodyStrong,
                ),
              ),
          ],
        ),
        const SizedBox(height: 3),
        _MetricRow(
          label: 'BOP',
          children: [
            for (final site in sites)
              _SiteFlag(
                tooltip: '${site.abbreviation} · BOP',
                checked: tooth.measurement(site).bleedingOnProbing,
                color: Colors.red,
                enabled: !readOnly,
                onChanged: (value) {
                  tooth.measurement(site).bleedingOnProbing = value;
                  onChanged();
                },
              ),
          ],
        ),
        const SizedBox(height: 3),
        _MetricRow(
          label: 'PI',
          children: [
            for (final site in sites)
              _SiteFlag(
                tooltip: '${site.abbreviation} · PI',
                checked: tooth.measurement(site).plaque,
                color: Colors.orange,
                enabled: !readOnly,
                onChanged: (value) {
                  tooth.measurement(site).plaque = value;
                  onChanged();
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(label, style: FluentTheme.of(context).typography.caption),
        ),
        ...children,
      ],
    );
  }
}

class _SmallNumber extends StatelessWidget {
  const _SmallNumber({
    required this.tooltip,
    required this.value,
    required this.min,
    required this.max,
    required this.enabled,
    required this.onChanged,
    this.alert = false,
  });

  final String tooltip;
  final int? value;
  final int min;
  final int max;
  final bool enabled;
  final ValueChanged<int?> onChanged;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 40,
        decoration: alert
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red.dark),
              )
            : null,
        child: NumberBox<int>(
          value: value,
          min: min,
          max: max,
          mode: SpinButtonPlacementMode.none,
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}

class _SiteFlag extends StatelessWidget {
  const _SiteFlag({
    required this.tooltip,
    required this.checked,
    required this.color,
    required this.enabled,
    required this.onChanged,
  });

  final String tooltip;
  final bool checked;
  final Color color;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 28,
      child: Tooltip(
        message: tooltip,
        child: ToggleButton(
          checked: checked,
          onChanged: enabled ? onChanged : null,
          child: Icon(
            checked ? FluentIcons.circle_fill : FluentIcons.circle_ring,
            size: 10,
            color: checked ? color : null,
          ),
        ),
      ),
    );
  }
}
