import 'package:apexo/features/expenses/expense_model.dart';
import 'package:apexo/features/treatment_payments/treatment_bill_model.dart';

/// The global finances page deliberately counts only explicit, current Apexo
/// treatment bills. Appointment `paid` values and imported DentalWin snapshots
/// are separate sources and must not be added to this ledger.
enum IncomeReceiptFilter { all, rec, noRec }

class TreatmentIncomeEntry {
  const TreatmentIncomeEntry({required this.account, required this.payment});

  final TreatmentBillAccount account;
  final TreatmentPayment payment;
}

class FinancesSummary {
  FinancesSummary({
    required Iterable<TreatmentBillAccount> accounts,
    required Iterable<Expense> expenseRecords,
  }) {
    final activeAccounts = accounts.toList();
    final entries = <TreatmentIncomeEntry>[];
    for (final account in activeAccounts) {
      for (final payment in account.payments) {
        if (payment.isActive) {
          entries.add(TreatmentIncomeEntry(account: account, payment: payment));
        }
      }
    }
    entries.sort((a, b) => b.payment.paidAt.compareTo(a.payment.paidAt));
    incomeEntries = entries;
    confirmedCharges = activeAccounts.fold<double>(
      0,
      (sum, account) => sum + account.chargeAmount,
    );
    income = entries.fold<double>(
      0,
      (sum, entry) => sum + entry.payment.amount,
    );
    recIncome = entries.where((entry) => entry.payment.receipt).fold<double>(
          0,
          (sum, entry) => sum + entry.payment.amount,
        );
    noRecIncome = income - recIncome;
    treatmentBalance = activeAccounts.fold<double>(
      0,
      (sum, account) => sum + (account.balance > 0 ? account.balance : 0),
    );
    treatmentOverpayment = activeAccounts.fold<double>(
      0,
      (sum, account) => sum + (account.balance < 0 ? -account.balance : 0),
    );
    final orders = expenseRecords.where((expense) => expense.isOrder).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    expenseOrders = orders;
    recordedExpenseCost = orders.fold<double>(
      0,
      (sum, order) => sum + order.cost,
    );
    recordedExpensePaid = orders.fold<double>(
      0,
      (sum, order) => sum + order.paidAmount,
    );
    expenseBalance = orders.fold<double>(
      0,
      (sum, order) => sum + (order.cost - order.paidAmount),
    );
  }

  late final List<TreatmentIncomeEntry> incomeEntries;
  late final List<Expense> expenseOrders;
  late final double confirmedCharges;
  late final double income;
  late final double recIncome;
  late final double noRecIncome;
  late final double treatmentBalance;
  late final double treatmentOverpayment;
  late final double recordedExpenseCost;
  late final double recordedExpensePaid;
  late final double expenseBalance;

  List<TreatmentIncomeEntry> entriesFor(IncomeReceiptFilter filter) =>
      switch (filter) {
        IncomeReceiptFilter.all => incomeEntries,
        IncomeReceiptFilter.rec =>
          incomeEntries.where((entry) => entry.payment.receipt).toList(),
        IncomeReceiptFilter.noRec =>
          incomeEntries.where((entry) => !entry.payment.receipt).toList(),
      };

  double incomeFor(IncomeReceiptFilter filter) => switch (filter) {
        IncomeReceiptFilter.all => income,
        IncomeReceiptFilter.rec => recIncome,
        IncomeReceiptFilter.noRec => noRecIncome,
      };
}
