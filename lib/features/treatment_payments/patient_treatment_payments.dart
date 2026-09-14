import 'package:apexo/core/multi_stream_builder.dart';
import 'package:apexo/features/odontogram/odontogram_event_model.dart';
import 'package:apexo/features/odontogram/odontogram_event_store.dart';
import 'package:apexo/features/treatment_payments/treatment_bill_store.dart';
import 'package:apexo/features/settings/settings_stores.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/services/login.dart';
import 'package:apexo/services/perm.dart';
import 'package:fluent_ui/fluent_ui.dart';

/// New, explicitly confirmed charges. Appointment finances and the imported
/// DentalWin snapshot remain separate until a reconciliation is approved.
class PatientTreatmentPayments extends StatefulWidget {
  const PatientTreatmentPayments({super.key, required this.patientID});

  final String patientID;

  @override
  State<PatientTreatmentPayments> createState() =>
      _PatientTreatmentPaymentsState();
}

class _PatientTreatmentPaymentsState extends State<PatientTreatmentPayments> {
  String? _selectedEventID;
  String? _editingPaymentID;
  bool _editingCharge = false;
  final _chargeController = TextEditingController();
  final _partialController = TextEditingController();
  final _correctionController = TextEditingController();
  bool _newReceipt = false;
  String? _error;

  bool get _canEdit => login.isAdmin || login.perm(Perm.patients).full;

  // A legacy bill can block synchronization for the whole bill store, not
  // just its patient. Keep all payment changes read-only until reconciliation.
  bool get _legacyBillLoaded => treatmentBills.docs.values.any(
        (bill) => bill.id == bill.odontogramEventID,
      );

  bool get _canEditPayments => _canEdit && !_legacyBillLoaded;

  @override
  void dispose() {
    _chargeController.dispose();
    _partialController.dispose();
    _correctionController.dispose();
    super.dispose();
  }

  String _money(double amount) =>
      '${amount.toStringAsFixed(2)} ${currency().trim()}';

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  double? _parseAmount(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.'));

  void _select(_BillEntry entry) {
    setState(() {
      _selectedEventID = entry.eventID;
      _editingPaymentID = null;
      _editingCharge = false;
      _chargeController.text =
          (entry.bill?.chargeAmount ?? entry.event?.priceSnapshot ?? 0)
              .toStringAsFixed(2);
      _partialController.clear();
      _error = null;
    });
  }

  void _confirmCharge(_BillEntry entry) {
    if (!_canEditPayments) return;
    final amount = _parseAmount(_chargeController);
    if (amount == null || !amount.isFinite || amount < 0) {
      setState(() => _error = txt('treatmentPaymentInvalidCharge'));
      return;
    }
    try {
      treatmentBills.confirmCharge(
        patientID: widget.patientID,
        odontogramEventID: entry.eventID,
        treatmentNameSnapshot: entry.name,
        amount: amount,
      );
      setState(() {
        _editingCharge = false;
        _error = null;
      });
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  void _addPayment(TreatmentBillAccount bill, {required bool settle}) {
    if (!_canEditPayments) return;
    final amount = settle ? bill.balance : _parseAmount(_partialController);
    if (amount == null ||
        !amount.isFinite ||
        amount <= 0 ||
        amount > bill.balance + 0.005) {
      setState(() => _error = txt('treatmentPaymentInvalidAmount'));
      return;
    }
    try {
      treatmentBills.addPayment(
        odontogramEventID: bill.odontogramEventID,
        amount: amount,
        receipt: _newReceipt,
      );
      setState(() {
        _error = null;
        _partialController.clear();
        _newReceipt = false;
      });
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  void _correctPayment(TreatmentBillAccount bill, TreatmentPayment payment) {
    if (!_canEditPayments) return;
    final amount = _parseAmount(_correctionController);
    if (amount == null || !amount.isFinite || amount <= 0) {
      setState(() => _error = txt('treatmentPaymentInvalidAmount'));
      return;
    }
    try {
      treatmentBills.correctPayment(
        odontogramEventID: bill.odontogramEventID,
        paymentID: payment.id,
        amount: amount,
      );
      setState(() {
        _editingPaymentID = null;
        _error = null;
      });
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  Future<void> _voidPayment(
      TreatmentBillAccount bill, TreatmentPayment payment) async {
    if (!_canEditPayments) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: Text(txt('treatmentPaymentVoidTitle')),
        content: Text(txt('treatmentPaymentVoidQuestion')),
        actions: [
          Button(
            child: Text(txt('cancel')),
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          FilledButton(
            child: Text(txt('treatmentPaymentVoid')),
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !_canEditPayments) return;
    try {
      treatmentBills.voidPayment(
        odontogramEventID: bill.odontogramEventID,
        paymentID: payment.id,
      );
      setState(() {
        _editingPaymentID = null;
        _error = null;
      });
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  void _setReceipt(
      TreatmentBillAccount bill, TreatmentPayment payment, bool value) {
    if (!_canEditPayments) return;
    try {
      treatmentBills.setReceipt(
        odontogramEventID: bill.odontogramEventID,
        paymentID: payment.id,
        receipt: value,
      );
      setState(() => _error = null);
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MStreamBuilder(
      streams: [
        odontogramEvents.observableMap.stream,
        treatmentBills.observableMap.stream,
        treatmentPaymentEntries.observableMap.stream,
      ],
      builder: (context, snapshot) {
        final allEvents = odontogramEvents.forPatient(widget.patientID);
        final supersededIDs = allEvents
            .map((event) => event.supersedesEventID)
            .where((id) => id.isNotEmpty)
            .toSet();
        final bills = treatmentBills.accountsForPatient(widget.patientID);
        final billByEventID = {
          for (final bill in bills) bill.odontogramEventID: bill,
        };
        final entries = <_BillEntry>[
          for (final event in allEvents)
            if (billByEventID.containsKey(event.id) ||
                (event.eventKind == OdontogramEventKind.treatment &&
                    event.status == OdontogramEventStatus.completed &&
                    event.treatmentHistoryID.isEmpty &&
                    !supersededIDs.contains(event.id)))
              _BillEntry(event.id, event, billByEventID[event.id]),
          for (final bill in bills)
            if (!allEvents.any((event) => event.id == bill.odontogramEventID))
              _BillEntry(bill.odontogramEventID, null, bill),
        ];
        entries.sort((a, b) => b.date.compareTo(a.date));
        final selected = entries.isEmpty
            ? null
            : entries
                    .where((entry) => entry.eventID == _selectedEventID)
                    .firstOrNull ??
                entries.first;
        if (selected != null && _selectedEventID != selected.eventID) {
          _selectedEventID = selected.eventID;
          _chargeController.text = (selected.bill?.chargeAmount ??
                  selected.event?.priceSnapshot ??
                  0)
              .toStringAsFixed(2);
          _editingCharge = false;
        }
        final charges =
            bills.fold<double>(0, (sum, bill) => sum + bill.chargeAmount);
        final paid =
            bills.fold<double>(0, (sum, bill) => sum + bill.paidAmount);
        final outstanding = bills.fold<double>(
            0, (sum, bill) => sum + (bill.balance > 0 ? bill.balance : 0));
        final overpaid = bills.fold<double>(
            0, (sum, bill) => sum + (bill.balance < 0 ? -bill.balance : 0));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(txt('treatmentPaymentsTitle'),
                style: FluentTheme.of(context).typography.subtitle),
            const SizedBox(height: 5),
            Text(txt('treatmentPaymentsDescription')),
            const SizedBox(height: 12),
            if (_legacyBillLoaded) ...[
              InfoBar(
                key: const Key('treatment-payment-legacy-warning'),
                severity: InfoBarSeverity.warning,
                title: Text(txt('treatmentPaymentLegacyReadOnlyTitle')),
                content: Text(txt('treatmentPaymentLegacyReadOnlyBody')),
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Total(label: txt('recordedCharges'), value: _money(charges)),
                _Total(label: txt('paid'), value: _money(paid)),
                _Total(label: txt('underpaid'), value: _money(outstanding)),
                if (overpaid > 0)
                  _Total(label: txt('overpaid'), value: _money(overpaid)),
              ],
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              InfoBar(title: Text(txt('treatmentPaymentsEmpty')))
            else
              LayoutBuilder(builder: (context, constraints) {
                final stacked = constraints.maxWidth < 740;
                final list = _treatmentList(entries);
                final detail = _treatmentDetail(selected!);
                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [list, const SizedBox(height: 12), detail],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: list),
                    const SizedBox(width: 12),
                    Expanded(flex: 4, child: detail),
                  ],
                );
              }),
          ],
        );
      },
    );
  }

  Widget _treatmentList(List<_BillEntry> entries) {
    return _Box(
      title: txt('treatmentPaymentsTreatments'),
      child: Column(
        children: entries.map((entry) {
          final bill = entry.bill;
          final status = bill == null
              ? txt('treatmentPaymentUncharged')
              : bill.isOverpaid
                  ? txt('overpaid')
                  : bill.isFullyPaid
                      ? txt('fullyPaid')
                      : bill.paidAmount > 0
                          ? txt('treatmentPaymentPartial')
                          : txt('underpaid');
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Button(
              key: Key('treatment-payment-treatment-${entry.eventID}'),
              onPressed: () => _select(entry),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.name,
                        style: FluentTheme.of(context).typography.bodyStrong),
                    const SizedBox(height: 3),
                    Text('${entry.location} · $status'),
                    if (bill != null)
                      Text(
                          '${txt('recordedCharges')}: ${_money(bill.chargeAmount)}  ·  ${txt('paid')}: ${_money(bill.paidAmount)}  ·  ${txt('underpaid')}: ${_money(bill.balance)}'),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _treatmentDetail(_BillEntry entry) {
    final bill = entry.bill;
    return _Box(
      title: txt('treatmentPaymentSelected'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(entry.name,
              style: FluentTheme.of(context).typography.bodyStrong),
          Text(entry.location),
          const SizedBox(height: 12),
          if (bill == null) ...[
            InfoBar(
              title: Text(txt('treatmentPaymentUncharged')),
              content: Text(txt('treatmentPaymentReferencePriceInfo')),
            ),
            const SizedBox(height: 10),
            InfoLabel(
              label: txt('treatmentPaymentChargeAmount'),
              child: TextBox(
                key: const Key('treatment-payment-charge-input'),
                controller: _chargeController,
                enabled: _canEditPayments,
              ),
            ),
            const SizedBox(height: 9),
            FilledButton(
              key: const Key('treatment-payment-confirm-charge'),
              onPressed: _canEditPayments ? () => _confirmCharge(entry) : null,
              child: Text(txt('treatmentPaymentConfirmCharge')),
            ),
          ] else ...[
            Text('${txt('recordedCharges')}: ${_money(bill.chargeAmount)}'),
            if (_canEdit) ...[
              const SizedBox(height: 5),
              if (!_editingCharge)
                Button(
                  key: const Key('treatment-payment-edit-charge'),
                  onPressed: _canEditPayments
                      ? () => setState(() {
                            _chargeController.text =
                                bill.chargeAmount.toStringAsFixed(2);
                            _editingCharge = true;
                            _error = null;
                          })
                      : null,
                  child: Text(txt('treatmentPaymentCorrectAmount')),
                )
              else ...[
                InfoLabel(
                  label: txt('treatmentPaymentChargeAmount'),
                  child: TextBox(
                    key: const Key('treatment-payment-charge-correction-input'),
                    controller: _chargeController,
                    enabled: _canEditPayments,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 7,
                  children: [
                    FilledButton(
                      key:
                          const Key('treatment-payment-save-charge-correction'),
                      onPressed:
                          _canEditPayments ? () => _confirmCharge(entry) : null,
                      child: Text(txt('save')),
                    ),
                    Button(
                      onPressed: () => setState(() => _editingCharge = false),
                      child: Text(txt('cancel')),
                    ),
                  ],
                ),
              ],
            ],
            Text('${txt('paid')}: ${_money(bill.paidAmount)}'),
            Text('${txt('underpaid')}: ${_money(bill.balance)}'),
            const SizedBox(height: 10),
            if (bill.isOverpaid) ...[
              InfoBar(
                severity: InfoBarSeverity.error,
                title: Text(txt('overpaid')),
                content: Text(txt('treatmentPaymentOverpaidReconcile')),
              ),
            ] else if (bill.balance > 0.005) ...[
              InfoLabel(
                label: txt('treatmentPaymentPartialAmount'),
                child: TextBox(
                  key: const Key('treatment-payment-partial-input'),
                  controller: _partialController,
                  enabled: _canEditPayments,
                ),
              ),
              const SizedBox(height: 7),
              Checkbox(
                key: const Key('treatment-payment-new-rec'),
                checked: _newReceipt,
                onChanged: _canEditPayments
                    ? (value) => setState(() => _newReceipt = value == true)
                    : null,
                content: const Text('Rec'),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  FilledButton(
                    key: const Key('treatment-payment-settle'),
                    onPressed: _canEditPayments
                        ? () => _addPayment(bill, settle: true)
                        : null,
                    child: Text(
                        '${txt('treatmentPaymentSettle')} ${_money(bill.balance)}'),
                  ),
                  Button(
                    key: const Key('treatment-payment-add-partial'),
                    onPressed: _canEditPayments
                        ? () => _addPayment(bill, settle: false)
                        : null,
                    child: Text(txt('treatmentPaymentAddPartial')),
                  ),
                ],
              ),
            ] else
              InfoBar(title: Text(txt('fullyPaid'))),
            const SizedBox(height: 15),
            Text(txt('treatmentPaymentHistory'),
                style: FluentTheme.of(context).typography.bodyStrong),
            const SizedBox(height: 5),
            if (bill.payments.isEmpty)
              Text(txt('treatmentPaymentNone'))
            else
              ...bill.payments.reversed
                  .map((payment) => _paymentRow(bill, payment)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            InfoBar(
              severity: InfoBarSeverity.error,
              title: Text(txt('error')),
              content: Text(_error!),
            ),
          ],
        ],
      ),
    );
  }

  Widget _paymentRow(TreatmentBillAccount bill, TreatmentPayment payment) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 9,
            runSpacing: 5,
            children: [
              Text(
                  '${_date(payment.paidAt)} · ${_money(payment.amount)}${payment.isActive ? '' : ' · ${txt('treatmentPaymentVoided')}'}'),
              if (payment.isActive) ...[
                Checkbox(
                  key: Key('treatment-payment-rec-${payment.id}'),
                  checked: payment.receipt,
                  onChanged: _canEditPayments
                      ? (value) => _setReceipt(bill, payment, value == true)
                      : null,
                  content: const Text('Rec'),
                ),
                Button(
                  key: Key('treatment-payment-edit-${payment.id}'),
                  onPressed: _canEditPayments
                      ? () => setState(() {
                            _editingPaymentID = payment.id;
                            _correctionController.text =
                                payment.amount.toStringAsFixed(2);
                            _error = null;
                          })
                      : null,
                  child: Text(txt('treatmentPaymentCorrect')),
                ),
              ],
            ],
          ),
          if (payment.revisions.isNotEmpty)
            Text(txt('treatmentPaymentCorrected'),
                style: FluentTheme.of(context).typography.caption),
          if (payment.isActive && _editingPaymentID == payment.id) ...[
            const SizedBox(height: 7),
            InfoLabel(
              label: txt('treatmentPaymentCorrectAmount'),
              child: TextBox(
                key: const Key('treatment-payment-correction-input'),
                controller: _correctionController,
                enabled: _canEditPayments,
              ),
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                FilledButton(
                  key: const Key('treatment-payment-save-correction'),
                  onPressed: _canEditPayments
                      ? () => _correctPayment(bill, payment)
                      : null,
                  child: Text(txt('save')),
                ),
                Button(
                  onPressed: () => setState(() => _editingPaymentID = null),
                  child: Text(txt('cancel')),
                ),
                Button(
                  key: const Key('treatment-payment-void'),
                  onPressed: _canEditPayments
                      ? () => _voidPayment(bill, payment)
                      : null,
                  child: Text(txt('treatmentPaymentVoid')),
                ),
              ],
            ),
          ],
          const Divider(),
        ],
      ),
    );
  }
}

class _BillEntry {
  const _BillEntry(this.eventID, this.event, this.bill);

  final String eventID;
  final OdontogramEvent? event;
  final TreatmentBillAccount? bill;

  String get name =>
      event?.procedureNameSnapshot ?? bill?.treatmentNameSnapshot ?? '';
  String get location =>
      event?.toothFdi == null ? '' : '${txt('tooth')} ${event!.toothFdi}';
  DateTime get date => event?.recordedAt ?? bill!.confirmedAt;
}

class _Box extends StatelessWidget {
  const _Box({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
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

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 160),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: FluentTheme.of(context).cardColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            Text(value, style: FluentTheme.of(context).typography.bodyStrong)
          ],
        ),
      );
}
