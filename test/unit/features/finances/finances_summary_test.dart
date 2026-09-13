import 'package:apexo/features/expenses/expense_model.dart';
import 'package:apexo/features/finances/finances_summary.dart';
import 'package:apexo/features/treatment_payments/treatment_bill_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TreatmentBillAccount account(
    String id,
    double charge,
    List<TreatmentPayment> payments,
  ) =>
      TreatmentBillAccount(
        bill: TreatmentBill.fromJson({
          'id': id,
          'patientID': 'patient-$id',
          'odontogramEventID': id,
          'treatmentNameSnapshot': 'Treatment $id',
          'chargeAmount': charge,
        }),
        chargeAmount: charge,
        payments: payments,
      );

  TreatmentPayment payment(
    String id,
    double amount, {
    required bool rec,
    bool voided = false,
  }) =>
      TreatmentPayment(
        id: id,
        amount: amount,
        paidAt: DateTime(2026, 9, 12),
        receipt: rec,
        voidedAt: voided ? DateTime(2026, 9, 13) : null,
      );

  test('Rec/noRec income totals exclude voided entries and split exactly', () {
    final summary = FinancesSummary(
      accounts: [
        account('event-a', 500, [
          payment('p-1', 200, rec: true),
          payment('p-2', 100, rec: false),
          payment('p-3', 50, rec: true, voided: true),
        ]),
        account('event-b', 80, [payment('p-4', 80, rec: true)]),
      ],
      expenseRecords: const [],
    );

    expect(summary.confirmedCharges, 580);
    expect(summary.income, 380);
    expect(summary.recIncome, 280);
    expect(summary.noRecIncome, 100);
    expect(summary.treatmentBalance, 200);
    expect(summary.entriesFor(IncomeReceiptFilter.all), hasLength(3));
    expect(summary.entriesFor(IncomeReceiptFilter.rec), hasLength(2));
    expect(summary.entriesFor(IncomeReceiptFilter.noRec), hasLength(1));
    expect(summary.incomeFor(IncomeReceiptFilter.rec), 280);
  });

  test('corrected effective payment changes sums without counting revisions',
      () {
    final summary = FinancesSummary(
      accounts: [
        account('event-a', 500, [
          TreatmentPayment(
            id: 'p-1',
            amount: 300,
            paidAt: DateTime(2026, 9, 12),
            receipt: false,
            revisions: [
              TreatmentPaymentRevision(
                kind: TreatmentPaymentRevisionKind.amount,
                at: DateTime(2026, 9, 13),
                oldAmount: 500,
                newAmount: 300,
              ),
            ],
          ),
        ]),
      ],
      expenseRecords: const [],
    );

    expect(summary.income, 300);
    expect(summary.noRecIncome, 300);
    expect(summary.recIncome, 0);
    expect(summary.treatmentBalance, 200);
  });

  test('overpayment cannot hide a different outstanding treatment', () {
    final summary = FinancesSummary(
      accounts: [
        account('event-overpaid', 100, [payment('p-extra', 200, rec: true)]),
        account('event-unpaid', 100, []),
      ],
      expenseRecords: const [],
    );

    expect(summary.treatmentBalance, 100);
    expect(summary.treatmentOverpayment, 100);
  });

  test('expenses use order cost and paid amount, not catalogue or suppliers',
      () {
    final summary = FinancesSummary(
      accounts: const [],
      expenseRecords: [
        Expense.fromJson({
          'id': 'order-a',
          'supplierId': 'supplier-a',
          'cost': 120,
          'paidAmount': 40,
          'processed': true,
        }),
        Expense.fromJson({
          'id': 'order-b',
          'supplierId': 'supplier-a',
          'cost': 60,
          'paidAmount': 60,
        }),
        Expense.fromJson({'id': 'supplier-a', 'isSupplier': true}),
        Expense.fromJson({
          'id': 'catalogue-a',
          'isCatalogueItem': true,
          'catalogueItemName': 'Item',
        }),
      ],
    );

    expect(summary.expenseOrders, hasLength(2));
    expect(summary.recordedExpenseCost, 180);
    expect(summary.recordedExpensePaid, 100);
    expect(summary.expenseBalance, 80);
  });
}
