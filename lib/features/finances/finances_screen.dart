import 'package:apexo/common_widgets/money_display.dart';
import 'package:apexo/core/multi_stream_builder.dart';
import 'package:apexo/features/expenses/expense_model.dart';
import 'package:apexo/features/expenses/expenses_store.dart';
import 'package:apexo/features/finances/finances_summary.dart';
import 'package:apexo/features/patients/open_patient_panel.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/features/settings/settings_stores.dart';
import 'package:apexo/features/treatment_payments/treatment_bill_store.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/services/login.dart';
import 'package:apexo/utils/constants.dart';
import 'package:fluent_ui/fluent_ui.dart';

/// Current Apexo finances. Legacy appointment `paid` and imported DentalWin
/// figures are intentionally excluded so that treatment income is not counted
/// twice or presented as a reconciled historical account.
class FinancesScreen extends StatefulWidget {
  const FinancesScreen({super.key});

  @override
  State<FinancesScreen> createState() => _FinancesScreenState();
}

class _FinancesScreenState extends State<FinancesScreen> {
  IncomeReceiptFilter _receiptFilter = IncomeReceiptFilter.all;
  int _visibleIncome = 50;
  int _visibleExpenses = 30;

  @override
  Widget build(BuildContext context) {
    final canViewIncome = login.isAdmin || login.perm(Perm.revenue).read;
    final canViewExpenses = login.isAdmin || login.perm(Perm.expenses).some;
    return MStreamBuilder(
      streams: [
        treatmentBills.observableMap.stream,
        treatmentPaymentEntries.observableMap.stream,
        expenses.observableMap.stream,
        patients.observableMap.stream,
      ],
      builder: (context, _) {
        final summary = FinancesSummary(
          accounts: canViewIncome
              ? treatmentBills.allAccounts
              : const <TreatmentBillAccount>[],
          expenseRecords: canViewExpenses ? expenses.present.values : const [],
        );
        final filtered = summary.entriesFor(_receiptFilter);
        final shownIncome = filtered.take(_visibleIncome).toList();
        final shownExpenses =
            summary.expenseOrders.take(_visibleExpenses).toList();
        final theme = FluentTheme.of(context);

        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Text(txt('finances'), style: theme.typography.title),
            const SizedBox(height: 12),
            if (canViewIncome) ...[
              InfoBar(
                title: Text(txt('financesScopeNote')),
                severity: InfoBarSeverity.info,
              ),
              const SizedBox(height: 14),
              _MoneyCards(cards: [
                _MoneyCardData(
                  label: txt('confirmedTreatmentCharges'),
                  amount: summary.confirmedCharges,
                  icon: FluentIcons.payment_card,
                  accent: theme.accentColor,
                ),
                _MoneyCardData(
                  label: txt('collectedTreatmentIncome'),
                  amount: summary.income,
                  icon: FluentIcons.currency,
                  accent: Colors.teal,
                ),
                _MoneyCardData(
                  label: txt('outstandingTreatmentBalances'),
                  amount: summary.treatmentBalance,
                  icon: FluentIcons.history,
                  accent: Colors.orange,
                ),
                if (summary.treatmentOverpayment > 0)
                  _MoneyCardData(
                    label: txt('overpaid'),
                    amount: summary.treatmentOverpayment,
                    icon: FluentIcons.warning,
                    accent: Colors.red,
                  ),
              ]),
              const SizedBox(height: 18),
              _sectionTitle(context, txt('incomeTransactions')),
              const SizedBox(height: 9),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _filterButton(IncomeReceiptFilter.all, txt('all'),
                      key: const Key('finances_filter_all')),
                  _filterButton(IncomeReceiptFilter.rec, 'Rec',
                      key: const Key('finances_filter_rec')),
                  _filterButton(IncomeReceiptFilter.noRec, 'noRec',
                      key: const Key('finances_filter_norec')),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '${txt('total')}: ${_money(summary.incomeFor(_receiptFilter))}',
                      key: const Key('finances_selected_income_total'),
                      style: theme.typography.bodyStrong,
                    ),
                  ),
                  Text(
                    '(${filtered.length} ${txt('payments')})',
                    style: theme.typography.caption,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (filtered.isEmpty)
                InfoBar(title: Text(txt('noTreatmentPayments')))
              else ...[
                for (final entry in shownIncome) _incomeRow(context, entry),
                if (shownIncome.length < filtered.length)
                  _moreButton(
                    label: txt('moreTransactions'),
                    onPressed: () => setState(() => _visibleIncome += 50),
                  ),
              ],
            ],
            if (canViewExpenses) ...[
              if (canViewIncome) const SizedBox(height: 25),
              _sectionTitle(context, txt('recordedExpenses')),
              const SizedBox(height: 8),
              InfoBar(
                title: Text(txt('expensesScopeNote')),
                severity: InfoBarSeverity.info,
              ),
              const SizedBox(height: 12),
              _MoneyCards(cards: [
                _MoneyCardData(
                  label: txt('recordedExpenseCosts'),
                  amount: summary.recordedExpenseCost,
                  icon: FluentIcons.receipt_processing,
                  accent: Colors.orange,
                ),
                _MoneyCardData(
                  label: txt('recordedSupplierPayments'),
                  amount: summary.recordedExpensePaid,
                  icon: FluentIcons.payment_card,
                  accent: Colors.teal,
                ),
                _MoneyCardData(
                  label: txt('supplierBalanceFromAmounts'),
                  amount: summary.expenseBalance,
                  icon: FluentIcons.history,
                  accent: Colors.red,
                ),
              ]),
              const SizedBox(height: 12),
              if (summary.expenseOrders.isEmpty)
                InfoBar(title: Text(txt('noExpenseOrders')))
              else ...[
                for (final order in shownExpenses) _expenseRow(context, order),
                if (shownExpenses.length < summary.expenseOrders.length)
                  _moreButton(
                    label: txt('moreExpenseOrders'),
                    onPressed: () => setState(() => _visibleExpenses += 30),
                  ),
              ],
            ],
          ],
        );
      },
    );
  }

  Widget _filterButton(IncomeReceiptFilter filter, String label, {Key? key}) {
    return ToggleButton(
      key: key,
      checked: _receiptFilter == filter,
      onChanged: (_) => setState(() {
        _receiptFilter = filter;
        _visibleIncome = 50;
      }),
      child: Text(label),
    );
  }

  Widget _incomeRow(BuildContext context, TreatmentIncomeEntry entry) {
    final patient = patients.get(entry.account.patientID);
    final patientName = patient?.title ?? txt('unidentified');
    final payment = entry.payment;
    final canEdit = login.isAdmin || login.perm(Perm.patients).full;
    return _ledgerRow(
      context,
      title: entry.account.treatmentNameSnapshot,
      subtitle: '$patientName · ${DF.allNumbers(payment.paidAt)}',
      amount: payment.amount,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: payment.receipt
                  ? Colors.teal.withValues(alpha: 0.12)
                  : Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(payment.receipt ? 'Rec' : 'noRec'),
          ),
          if (canEdit) ...[
            const SizedBox(width: 5),
            IconButton(
              key: Key('finances_edit_payment_${payment.id}'),
              icon: const Icon(FluentIcons.edit, size: 14),
              onPressed: () => _editPayment(context, entry),
            ),
          ],
        ],
      ),
      onPressed: canEdit
          ? null
          : patient == null
              ? null
              : () => openPatient(patient),
    );
  }

  Future<void> _editPayment(
    BuildContext context,
    TreatmentIncomeEntry entry,
  ) async {
    if (!(login.isAdmin || login.perm(Perm.patients).full)) return;
    final account = entry.account;
    final payment = entry.payment;
    final input =
        TextEditingController(text: payment.amount.toStringAsFixed(2));
    var receipt = payment.receipt;
    String? error;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => ContentDialog(
            title: Text(txt('treatmentPaymentCorrect')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${account.treatmentNameSnapshot} · ${DF.allNumbers(payment.paidAt)}'),
                const SizedBox(height: 10),
                InfoLabel(
                  label: txt('treatmentPaymentCorrectAmount'),
                  child: TextBox(
                    key: const Key('finances_correction_amount'),
                    controller: input,
                  ),
                ),
                const SizedBox(height: 10),
                Checkbox(
                  key: const Key('finances_correction_receipt'),
                  checked: receipt,
                  onChanged: (value) =>
                      setDialogState(() => receipt = value == true),
                  content: const Text('Rec'),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  InfoBar(
                    severity: InfoBarSeverity.error,
                    title: Text(txt('error')),
                    content: Text(error!),
                  ),
                ],
              ],
            ),
            actions: [
              Button(
                key: const Key('finances_void_payment'),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: dialogContext,
                    builder: (confirmContext) => ContentDialog(
                      title: Text(txt('treatmentPaymentVoidTitle')),
                      content: Text(txt('treatmentPaymentVoidQuestion')),
                      actions: [
                        Button(
                          child: Text(txt('cancel')),
                          onPressed: () => Navigator.pop(confirmContext, false),
                        ),
                        FilledButton(
                          child: Text(txt('treatmentPaymentVoid')),
                          onPressed: () => Navigator.pop(confirmContext, true),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true || !dialogContext.mounted) return;
                  try {
                    treatmentBills.voidPayment(
                      odontogramEventID: account.odontogramEventID,
                      paymentID: payment.id,
                    );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  } catch (failure) {
                    setDialogState(() => error = failure.toString());
                  }
                },
                child: Text(txt('treatmentPaymentVoid')),
              ),
              Button(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(txt('cancel')),
              ),
              FilledButton(
                key: const Key('finances_save_correction'),
                onPressed: () {
                  final amount = double.tryParse(
                    input.text.trim().replaceAll(',', '.'),
                  );
                  final newCents = amount == null ? 0 : (amount * 100).round();
                  final maxCents = account.chargeCents -
                      (account.paidCents - payment.amountCents);
                  if (amount == null ||
                      !amount.isFinite ||
                      newCents <= 0 ||
                      newCents > maxCents ||
                      (amount * 100 - newCents).abs() > 0.000001) {
                    setDialogState(
                        () => error = txt('treatmentPaymentInvalidAmount'));
                    return;
                  }
                  try {
                    if (newCents != payment.amountCents) {
                      treatmentBills.correctPayment(
                        odontogramEventID: account.odontogramEventID,
                        paymentID: payment.id,
                        amount: newCents / 100,
                      );
                    }
                    if (receipt != payment.receipt) {
                      treatmentBills.setReceipt(
                        odontogramEventID: account.odontogramEventID,
                        paymentID: payment.id,
                        receipt: receipt,
                      );
                    }
                    Navigator.pop(dialogContext);
                  } catch (failure) {
                    setDialogState(() => error = failure.toString());
                  }
                },
                child: Text(txt('save')),
              ),
            ],
          ),
        ),
      );
    } finally {
      input.dispose();
    }
  }

  Widget _expenseRow(BuildContext context, Expense order) {
    final supplier = expenses.get(order.supplierId);
    final name = supplier?.supplierName.isNotEmpty == true
        ? supplier!.supplierName
        : txt('unidentified');
    return _ledgerRow(
      context,
      title: name,
      subtitle:
          '${DF.allNumbers(order.date)} · ${txt('paid')}: ${_money(order.paidAmount)}',
      amount: order.cost,
      trailing: Text(
        '${txt('totalDue')}: ${_money(order.cost - order.paidAmount)}',
        style: FluentTheme.of(context).typography.caption,
      ),
    );
  }

  Widget _ledgerRow(
    BuildContext context, {
    required String title,
    required String subtitle,
    required double amount,
    Widget? trailing,
    VoidCallback? onPressed,
  }) {
    final theme = FluentTheme.of(context);
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.typography.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_money(amount), style: theme.typography.bodyStrong),
              if (trailing != null) ...[
                const SizedBox(height: 4),
                trailing,
              ],
            ],
          ),
        ],
      ),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border.all(
          color: theme.resources.dividerStrokeColorDefault,
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: onPressed == null
          ? content
          : HoverButton(
              onPressed: onPressed, builder: (context, states) => content),
    );
  }

  Widget _moreButton({required String label, required VoidCallback onPressed}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Button(onPressed: onPressed, child: Text(label)),
      ),
    );
  }
}

Widget _sectionTitle(BuildContext context, String text) => Text(
      text,
      style: FluentTheme.of(context).typography.subtitle,
    );

String _money(double amount) =>
    '${formatMoneyInText(amount.toStringAsFixed(2))} ${currency()}';

class _MoneyCardData {
  const _MoneyCardData({
    required this.label,
    required this.amount,
    required this.icon,
    required this.accent,
  });

  final String label;
  final double amount;
  final IconData icon;
  final Color accent;
}

class _MoneyCards extends StatelessWidget {
  const _MoneyCards({required this.cards});

  final List<_MoneyCardData> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 800
          ? 3
          : constraints.maxWidth >= 500
              ? 2
              : 1;
      final width = (constraints.maxWidth - 10 * (columns - 1)) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final card in cards)
            SizedBox(
              width: width,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: card.accent.withValues(alpha: 0.09),
                  border:
                      Border(left: BorderSide(color: card.accent, width: 4)),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  children: [
                    Icon(card.icon, color: card.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: FluentTheme.of(context).typography.caption,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _money(card.amount),
                            style:
                                FluentTheme.of(context).typography.bodyStrong,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}
