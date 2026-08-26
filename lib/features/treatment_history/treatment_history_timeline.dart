import 'package:apexo/features/settings/settings_stores.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:fluent_ui/fluent_ui.dart';

import 'treatment_history_model.dart';
import 'treatment_history_store.dart';

class TreatmentHistoryTimeline extends StatelessWidget {
  const TreatmentHistoryTimeline({
    super.key,
    required this.patientID,
    this.entries,
  });

  final String patientID;
  final List<TreatmentHistoryEntry>? entries;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: entries == null ? treatmentHistory.observableMap.stream : null,
      builder: (context, snapshot) {
        final items = entries ?? treatmentHistory.forPatient(patientID);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InfoBar(
              severity: InfoBarSeverity.info,
              title: Text(txt('treatmentHistoryPilot')),
              content: Text(txt('treatmentHistoryPilotDescription')),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              InfoBar(title: Text(txt('noTreatmentHistoryFound')))
            else
              ...items.map((entry) => _TreatmentHistoryCard(entry: entry)),
          ],
        );
      },
    );
  }
}

class _TreatmentHistoryCard extends StatelessWidget {
  const _TreatmentHistoryCard({required this.entry});

  final TreatmentHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final plan = entry.isTreatmentPlanItem;
    final statusColor = plan ? Colors.orange : Colors.teal;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(color: statusColor, width: 5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  entry.treatmentName,
                  style: theme.typography.bodyStrong,
                ),
              ),
              const SizedBox(width: 8),
              _Pill(
                label: txt(plan ? 'treatmentPlanItem' : 'completedTreatment'),
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Pill(
                label: entry.date == null
                    ? txt('dateNotAvailable')
                    : DF.allNumbers(entry.date!),
              ),
              if (entry.displayedTooth.isNotEmpty)
                _Pill(label: '${txt('tooth')}: ${entry.displayedTooth}'),
              if (entry.therapyGroup.isNotEmpty)
                _Pill(label: entry.therapyGroup),
              if (!entry.hasMappedCatalog)
                _Pill(label: txt('legacyCustomTreatment')),
            ],
          ),
          if (entry.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(entry.notes.trim()),
          ],
          if (entry.chargeRaw.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              '${txt('price')}: ${entry.chargeRaw}',
              style: theme.typography.caption,
            ),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? FluentTheme.of(context).accentColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: foreground, fontSize: 12),
      ),
    );
  }
}
