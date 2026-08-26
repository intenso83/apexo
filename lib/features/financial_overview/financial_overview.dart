import 'dart:math' as math;

import 'package:apexo/core/multi_stream_builder.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/settings/settings_stores.dart';
import 'package:apexo/features/treatment_history/treatment_history_model.dart';
import 'package:apexo/features/treatment_history/treatment_history_store.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:fluent_ui/fluent_ui.dart';

class LegacyFinancialSnapshot {
  LegacyFinancialSnapshot._({
    required this.completedRows,
    required this.plannedRows,
    required this.parsedChargeRows,
    required this.parsedCreditRows,
    required this.parsedTotalRows,
    required this.recordedCharges,
    required this.recordedCredits,
    required this.recordedSourceTotal,
    required this.plannedSourceValue,
  });

  final int completedRows;
  final int plannedRows;
  final int parsedChargeRows;
  final int parsedCreditRows;
  final int parsedTotalRows;
  final double recordedCharges;
  final double recordedCredits;
  final double recordedSourceTotal;
  final double plannedSourceValue;

  int get rows => completedRows + plannedRows;
  double get calculatedChargeMinusCredit => recordedCharges - recordedCredits;
  double get discrepancy => recordedSourceTotal - calculatedChargeMinusCredit;
  bool get sourceTotalsReconcile => discrepancy.abs() < 0.005;

  factory LegacyFinancialSnapshot.fromEntries(
    Iterable<TreatmentHistoryEntry> entries,
  ) {
    var completedRows = 0;
    var plannedRows = 0;
    var parsedChargeRows = 0;
    var parsedCreditRows = 0;
    var parsedTotalRows = 0;
    var charges = 0.0;
    var credits = 0.0;
    var sourceTotal = 0.0;
    var plannedValue = 0.0;

    for (final entry in entries) {
      final charge = parseLegacyMoney(entry.chargeRaw);
      final credit = parseLegacyMoney(entry.creditRaw);
      final total = parseLegacyMoney(entry.totalRaw);
      if (entry.isTreatmentPlanItem) {
        plannedRows++;
        plannedValue += total ?? charge ?? 0;
        continue;
      }
      completedRows++;
      if (charge != null) {
        parsedChargeRows++;
        charges += charge;
      }
      if (credit != null) {
        parsedCreditRows++;
        credits += credit;
      }
      if (total != null) {
        parsedTotalRows++;
        sourceTotal += total;
      }
    }

    return LegacyFinancialSnapshot._(
      completedRows: completedRows,
      plannedRows: plannedRows,
      parsedChargeRows: parsedChargeRows,
      parsedCreditRows: parsedCreditRows,
      parsedTotalRows: parsedTotalRows,
      recordedCharges: charges,
      recordedCredits: credits,
      recordedSourceTotal: sourceTotal,
      plannedSourceValue: plannedValue,
    );
  }

  static double? parseLegacyMoney(String raw) {
    var value = raw.trim().replaceAll(RegExp(r'\s'), '');
    if (value.isEmpty) return null;
    var negative = false;
    if (value.startsWith('(') && value.endsWith(')')) {
      negative = true;
      value = value.substring(1, value.length - 1);
    }
    if (!RegExp(r'^[+-]?\d+(?:[.,]\d+)?$').hasMatch(value)) return null;
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null) return null;
    return negative ? -parsed : parsed;
  }
}

class ApexoFinancialSnapshot {
  const ApexoFinancialSnapshot({
    required this.appointments,
    required this.charges,
    required this.payments,
  });

  final int appointments;
  final double charges;
  final double payments;

  double get balance => charges - payments;

  factory ApexoFinancialSnapshot.fromAppointments(
    Iterable<Appointment> appointments,
  ) {
    final included = appointments
        .where((appointment) =>
            appointment.archived != true && appointment.locked == false)
        .toList();
    return ApexoFinancialSnapshot(
      appointments: included.length,
      charges: included.fold(0, (sum, item) => sum + item.price),
      payments: included.fold(0, (sum, item) => sum + item.paid),
    );
  }
}

class PatientFinancialOverview extends StatelessWidget {
  const PatientFinancialOverview({
    super.key,
    required this.patientID,
    this.historyEntries,
    this.appointmentEntries,
    this.currencySymbol,
  });

  final String patientID;
  final List<TreatmentHistoryEntry>? historyEntries;
  final List<Appointment>? appointmentEntries;
  final String? currencySymbol;

  @override
  Widget build(BuildContext context) {
    return MStreamBuilder(
      streams: [
        treatmentHistory.observableMap.stream,
        appointments.observableMap.stream,
      ],
      builder: (context, snapshot) {
        final history =
            historyEntries ?? treatmentHistory.forPatient(patientID);
        final doneAppointments = appointmentEntries ??
            (appointments.byPatient[patientID]?['done'] ?? const []);
        return _FinancialOverviewBody(
          apexo: ApexoFinancialSnapshot.fromAppointments(doneAppointments),
          legacy: LegacyFinancialSnapshot.fromEntries(history),
          history: history,
          currencySymbol: currencySymbol ?? currency(),
        );
      },
    );
  }
}

class _FinancialOverviewBody extends StatelessWidget {
  const _FinancialOverviewBody({
    required this.apexo,
    required this.legacy,
    required this.history,
    required this.currencySymbol,
  });

  final ApexoFinancialSnapshot apexo;
  final LegacyFinancialSnapshot legacy;
  final List<TreatmentHistoryEntry> history;
  final String currencySymbol;

  String money(double value) {
    final suffix =
        currencySymbol.trim().isEmpty ? '' : ' ${currencySymbol.trim()}';
    return '${value.toStringAsFixed(2)}$suffix';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoBar(
          severity: InfoBarSeverity.warning,
          title: Text(txt('financialOverviewPilotTitle')),
          content: Text(txt('financialOverviewPilotDescription')),
        ),
        const SizedBox(height: 12),
        _Section(
          title: txt('currentApexoFinancials'),
          child: _SummaryCards(
            cards: [
              _SummaryCardData(
                label: txt('recordedCharges'),
                value: money(apexo.charges),
                icon: FluentIcons.money,
                color: Colors.blue,
              ),
              _SummaryCardData(
                label: txt('paid'),
                value: money(apexo.payments),
                icon: FluentIcons.payment_card,
                color: Colors.teal,
              ),
              _SummaryCardData(
                label: apexo.balance > 0
                    ? txt('underpaid')
                    : apexo.balance < 0
                        ? txt('overpaid')
                        : txt('fullyPaid'),
                value: money(apexo.balance.abs()),
                icon: apexo.balance.abs() < 0.005
                    ? FluentIcons.accept
                    : FluentIcons.warning,
                color:
                    apexo.balance.abs() < 0.005 ? Colors.teal : Colors.orange,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          title: txt('legacyDentalWinFinancialSnapshot'),
          child: legacy.rows == 0
              ? InfoBar(title: Text(txt('noFinancialHistoryFound')))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SummaryCards(
                      cards: [
                        _SummaryCardData(
                          label: txt('recordedCharges'),
                          value: money(legacy.recordedCharges),
                          icon: FluentIcons.add_to_shopping_list,
                          color: Colors.blue,
                        ),
                        _SummaryCardData(
                          label: txt('recordedCredits'),
                          value: money(legacy.recordedCredits),
                          icon: FluentIcons.remove_from_shopping_list,
                          color: Colors.teal,
                        ),
                        _SummaryCardData(
                          label: txt('recordedSourceTotal'),
                          value: money(legacy.recordedSourceTotal),
                          icon: FluentIcons.calculator,
                          color: Colors.purple,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    InfoBar(
                      severity: legacy.sourceTotalsReconcile
                          ? InfoBarSeverity.info
                          : InfoBarSeverity.warning,
                      title: Text(txt('financialValuesNotAuthoritative')),
                      content: Text(
                        legacy.sourceTotalsReconcile
                            ? txt('financialReconciliationStillPending')
                            : '${txt('financialSourceTotalsDoNotReconcile')} '
                                '${money(legacy.discrepancy.abs())}',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _YearBreakdown(
                      history: history,
                      money: money,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FluentTheme.of(context).cardColor,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: FluentTheme.of(context).typography.subtitle),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.cards});

  final List<_SummaryCardData> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = math.max(220.0, constraints.maxWidth);
        final width = available >= 720
            ? (available - 20) / 3
            : available >= 460
                ? (available - 10) / 2
                : available;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: cards
              .map((card) => SizedBox(width: width, child: _SummaryCard(card)))
              .toList(),
        );
      },
    );
  }
}

class _SummaryCardData {
  const _SummaryCardData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(this.data);

  final _SummaryCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: data.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: data.color, width: 4)),
      ),
      child: Row(
        children: [
          Icon(data.icon, color: data.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.label,
                    style: FluentTheme.of(context).typography.caption),
                const SizedBox(height: 3),
                Text(data.value,
                    style: FluentTheme.of(context).typography.bodyStrong),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _YearBreakdown extends StatelessWidget {
  const _YearBreakdown({required this.history, required this.money});

  final List<TreatmentHistoryEntry> history;
  final String Function(double) money;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<TreatmentHistoryEntry>>{};
    for (final entry in history.where((item) => item.isCompletedTreatment)) {
      final year = entry.date?.year.toString() ?? txt('dateNotAvailable');
      grouped.putIfAbsent(year, () => []).add(entry);
    }
    final years = grouped.keys.toList()
      ..sort((a, b) {
        final ai = int.tryParse(a);
        final bi = int.tryParse(b);
        if (ai == null && bi == null) return a.compareTo(b);
        if (ai == null) return 1;
        if (bi == null) return -1;
        return bi.compareTo(ai);
      });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          txt('financialYearBreakdown'),
          style: FluentTheme.of(context).typography.bodyStrong,
        ),
        const SizedBox(height: 7),
        _FinancialRow(
          year: txt('year'),
          charges: txt('recordedCharges'),
          credits: txt('recordedCredits'),
          total: txt('recordedSourceTotal'),
          header: true,
        ),
        ...years.map((year) {
          final snapshot = LegacyFinancialSnapshot.fromEntries(grouped[year]!);
          return _FinancialRow(
            year: year,
            charges: money(snapshot.recordedCharges),
            credits: money(snapshot.recordedCredits),
            total: money(snapshot.recordedSourceTotal),
          );
        }),
      ],
    );
  }
}

class _FinancialRow extends StatelessWidget {
  const _FinancialRow({
    required this.year,
    required this.charges,
    required this.credits,
    required this.total,
    this.header = false,
  });

  final String year;
  final String charges;
  final String credits;
  final String total;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final style = header
        ? FluentTheme.of(context).typography.caption?.copyWith(
              fontWeight: FontWeight.bold,
            )
        : FluentTheme.of(context).typography.body;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: header ? Colors.grey.withValues(alpha: 0.08) : null,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(year, style: style)),
          Expanded(flex: 3, child: Text(charges, style: style)),
          Expanded(flex: 3, child: Text(credits, style: style)),
          Expanded(flex: 3, child: Text(total, style: style)),
        ],
      ),
    );
  }
}
