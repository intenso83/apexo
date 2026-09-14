@Tags(['live_backend', 'serial'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:apexo/common_widgets/error_dialog.dart';
import 'package:apexo/core/save_local.dart';
import 'package:apexo/core/save_remote.dart';
import 'package:apexo/core/store.dart';
import 'package:apexo/features/finances/finances_summary.dart';
import 'package:apexo/features/odontogram/odontogram_event_model.dart';
import 'package:apexo/features/odontogram/odontogram_event_store.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/features/treatment_payments/treatment_bill_store.dart';
import 'package:apexo/utils/constants.dart';
import 'package:apexo/utils/uuid.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:path/path.dart' as p;
import 'package:pocketbase/pocketbase.dart';

/// Starts its own PocketBase with a freshly created temporary pb_data tree.
/// It never accepts a server URL, never uses test/secret.dart, and never calls
/// the older live-test reset/truncate helpers. Set APEXO_PAYMENT_E2E_PB_EXE to
/// an absolute PocketBase executable path to opt in.
void main() {
  final executablePath = Platform.environment['APEXO_PAYMENT_E2E_PB_EXE'];
  test(
    'treatment payment ledger survives PocketBase sync and fresh client reload',
    () async {
      final executable = File(executablePath!);
      expect(p.isAbsolute(executable.path), isTrue);
      expect(await executable.exists(), isTrue,
          reason: 'The opt-in PocketBase executable must exist.');

      final originalWorkingDirectory = Directory.current;
      final tempRoot = Directory('tmp').absolute;
      await tempRoot.create();
      final scratch = await tempRoot.createTemp('apexo-payment-e2e-');
      final pbData =
          Directory('${scratch.path}${Platform.pathSeparator}pb_data');
      final hooks = Directory('${scratch.path}${Platform.pathSeparator}hooks');
      final migrations =
          Directory('${scratch.path}${Platform.pathSeparator}migrations');
      final public =
          Directory('${scratch.path}${Platform.pathSeparator}public');
      Process? server;
      try {
        // A newly created temp directory is the only server data target.
        expect(await pbData.exists(), isFalse);
        await hooks.create();
        await migrations.create();
        await public.create();

        final nonce = _nonce();
        final email = 'payment-e2e-$nonce@example.invalid';
        final password = 'E2e-$nonce-${_nonce()}!';
        final bootstrap = await Process.run(executable.path, [
          'superuser',
          'create',
          email,
          password,
          '--dir=${pbData.path}',
          '--automigrate=false',
          '--hooksDir=${hooks.path}',
          '--migrationsDir=${migrations.path}',
          '--publicDir=${public.path}',
        ]);
        expect(bootstrap.exitCode, 0,
            reason: 'Could not bootstrap the temporary PocketBase instance.');

        final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final port = socket.port;
        await socket.close();
        server = await Process.start(executable.path, [
          'serve',
          '--http=127.0.0.1:$port',
          '--dir=${pbData.path}',
          '--automigrate=false',
          '--hooksDir=${hooks.path}',
          '--migrationsDir=${migrations.path}',
          '--publicDir=${public.path}',
        ]);
        // Drain output without exposing the generated credentials or records.
        server.stdout.drain<void>();
        server.stderr.drain<void>();
        final pb = PocketBase('http://127.0.0.1:$port');
        await _waitForHealth(pb);
        await pb.collection('_superusers').authWithPassword(email, password);

        // This must be a fresh database. Never repair/reset a pre-existing one.
        await expectLater(
          pb.collection(dataCollectionName).getList(perPage: 1),
          throwsA(isA<ClientException>()),
        );
        await pb.collections.import([dataCollectionImport]);
        await pb.settings.update(body: {
          'batch': {
            'enabled': true,
            'maxRequests': 101,
            'timeout': 3,
            'maxBodySize': 0,
          },
        });
        final empty =
            await pb.collection(dataCollectionName).getList(perPage: 1);
        expect(empty.totalItems, 0);

        // App-level singleton state falls back to a relative apexo-files Hive
        // directory in tests. Point that fallback at this disposable tree.
        Directory.current = scratch.path;
        patients.init();
        odontogramEvents.init();
        treatmentPaymentEntries.init();
        treatmentBills.init();
        final stores = <_BoundStore>[
          _BoundStore(patients, 'patients'),
          _BoundStore(odontogramEvents, 'odontogram_events'),
          _BoundStore(treatmentPaymentEntries, 'treatment_payment_entries'),
          _BoundStore(treatmentBills, 'treatment_bills'),
        ];
        for (final bound in stores) {
          await bound.bind(pb, scratch, 'first');
        }

        final patientID = uuid();
        final eventID = uuid();
        patients.set(Patient.fromJson({
          'id': patientID,
          'title': 'Synthetic payment test',
        }));
        odontogramEvents.set(OdontogramEvent.fromJson({
          'id': eventID,
          'patientID': patientID,
          'targetScope': 'tooth',
          'toothFdi': 11,
          'procedureID': 'synthetic-procedure',
          'procedureNameSnapshot': 'Synthetic treatment',
          'eventKind': 'treatment',
          'status': 'completed',
          'priceSnapshot': 999,
        }));
        await patients.waitUntilChangesAreProcessed();
        await odontogramEvents.waitUntilChangesAreProcessed();
        expect(odontogramEvents.get(eventID), isNotNull);
        expect(await _remoteCount(pb, 'patients'), 1);
        expect(await _remoteCount(pb, 'odontogram_events'), 1);
        expect(treatmentBills.accountsForPatient(patientID), isEmpty);

        var account = treatmentBills.confirmCharge(
          patientID: patientID,
          odontogramEventID: eventID,
          treatmentNameSnapshot: 'Synthetic treatment',
          amount: 500,
        );
        expect(account.chargeAmount, 500);
        expect(account.balance, 500);
        await treatmentBills.waitUntilChangesAreProcessed();
        final persistedEvent =
            await pb.collection(dataCollectionName).getOne(eventID);
        expect(
          persistedEvent.getStringValue('store'),
          'odontogram_events',
          reason: 'Confirming a charge must not overwrite its treatment event.',
        );
        account = treatmentBills.addPayment(
          odontogramEventID: eventID,
          amount: 200,
          receipt: false,
        );
        final partialID = account.payments.single.id;
        expect(account.balance, 300);
        account = treatmentBills.settle(
          odontogramEventID: eventID,
          receipt: true,
        );
        final settlementID = account.payments
            .singleWhere((payment) => payment.id != partialID)
            .id;
        expect(account.paidAmount, 500);
        expect(account.isFullyPaid, isTrue);
        _expectFinances(
            charges: 500, income: 500, rec: 300, noRec: 200, balance: 0);

        account = treatmentBills.correctPayment(
          odontogramEventID: eventID,
          paymentID: settlementID,
          amount: 250,
        );
        expect(account.balance, 50);
        account = treatmentBills.setReceipt(
          odontogramEventID: eventID,
          paymentID: partialID,
          receipt: true,
        );
        _expectFinances(
            charges: 500, income: 450, rec: 450, noRec: 0, balance: 50);
        account = treatmentBills.confirmCharge(
          patientID: patientID,
          odontogramEventID: eventID,
          treatmentNameSnapshot: 'Synthetic treatment',
          amount: 450,
        );
        expect(account.isFullyPaid, isTrue);
        account = treatmentBills.voidPayment(
          odontogramEventID: eventID,
          paymentID: partialID,
        );
        expect(account.payments, hasLength(2));
        expect(account.payments.singleWhere((p) => p.id == partialID).isActive,
            isFalse);
        _expectFinances(
            charges: 450, income: 250, rec: 250, noRec: 0, balance: 200);

        await treatmentBills.waitUntilChangesAreProcessed();
        await treatmentPaymentEntries.waitUntilChangesAreProcessed();
        for (final bound in stores) {
          await bound.sync();
        }
        expect(await _remoteCount(pb, 'patients'), 1);
        expect(await _remoteCount(pb, 'odontogram_events'), 1);
        expect(await _remoteCount(pb, 'treatment_bills'), 1);
        expect(await _remoteCount(pb, 'treatment_payment_entries'), 6);
        final persistedBill = await pb.collection(dataCollectionName).getList(
              filter: 'store="treatment_bills"',
              perPage: 2,
            );
        expect(persistedBill.items, hasLength(1));
        final originalBill = persistedBill.items.single;
        expect(originalBill.data['data']['chargeAmount'], 500);
        // A second offline client derives the same ID; upserting that bill
        // must keep one bill and leave the separate event row untouched.
        await treatmentBills.remote!.put([
          RowToWriteRemotely(
            id: originalBill.id,
            data: jsonEncode(treatmentBills.forEvent(eventID)),
          ),
        ]);
        expect(await _remoteCount(pb, 'treatment_bills'), 1);
        expect(await _remoteCount(pb, 'odontogram_events'), 1);

        // A separate empty Hive profile represents a second client/restart.
        for (final bound in stores) {
          await bound.bind(pb, scratch, 'second');
        }
        expect(patients.get(patientID), isNotNull);
        expect(odontogramEvents.get(eventID), isNotNull);
        final reloaded = treatmentBills.accountForEvent(eventID)!;
        expect(reloaded.chargeAmount, 450);
        expect(reloaded.paidAmount, 250);
        expect(reloaded.balance, 200);
        expect(reloaded.payments, hasLength(2));
        expect(reloaded.payments.singleWhere((p) => p.id == partialID).isActive,
            isFalse);
        expect(
            reloaded.payments.singleWhere((p) => p.id == settlementID).amount,
            250);
        expect(treatmentPaymentEntries.forEvent(eventID), hasLength(6));
        _expectFinances(
            charges: 450, income: 250, rec: 250, noRec: 0, balance: 200);

        // An old queued bill must never be allowed to replace a restored
        // treatment event, through either Store sync or direct remote put.
        final legacyEventID = uuid();
        odontogramEvents.set(OdontogramEvent.fromJson({
          'id': legacyEventID,
          'patientID': patientID,
          'targetScope': 'tooth',
          'toothFdi': 12,
          'procedureID': 'synthetic-legacy',
          'procedureNameSnapshot': 'Synthetic legacy treatment',
          'eventKind': 'treatment',
          'status': 'completed',
        }));
        await odontogramEvents.waitUntilChangesAreProcessed();
        final legacyBill = TreatmentBill.fromJson({
          'id': legacyEventID,
          'patientID': patientID,
          'odontogramEventID': legacyEventID,
          'treatmentNameSnapshot': 'Synthetic legacy treatment',
          'chargeAmount': 100,
        });
        // Bypass TreatmentBills.set as an observer or bulk loader could do.
        // The immediate Store persistence path must still be unable to
        // replace the event on the shared PocketBase data collection.
        // The headless runner has no app BuildContext for the expected
        // "remote write rejected" dialog; keep the persistence path intact.
        final previousErrorDialogShown = errorDialogShown;
        errorDialogShown = true;
        try {
          treatmentBills.observableMap.set(legacyBill);
          await treatmentBills.waitUntilChangesAreProcessed();
        } finally {
          errorDialogShown = previousErrorDialogShown;
        }
        expect(
          (await pb.collection(dataCollectionName).getOne(legacyEventID))
              .getStringValue('store'),
          'odontogram_events',
        );
        expect(
          (await treatmentBills.local!.getDeferred())
              .containsKey(legacyEventID),
          isTrue,
        );
        await treatmentBills.reload();
        final legacySync = await treatmentBills.synchronize();
        expect(legacySync.single.exception, contains('legacy treatment bill'));
        await expectLater(
          treatmentBills.remote!.put([
            RowToWriteRemotely(
              id: legacyEventID,
              data: jsonEncode(legacyBill),
            ),
          ]),
          throwsStateError,
        );
        expect(
          (await pb.collection(dataCollectionName).getOne(legacyEventID))
              .getStringValue('store'),
          'odontogram_events',
        );

        // Even a rare collision with a different store's existing record is
        // rejected before PocketBase's cross-store upsert can replace it.
        const unrelatedEventID = 'otherbilltest01';
        final occupiedBillID = treatmentBillRecordID(unrelatedEventID);
        await pb.collection(dataCollectionName).create(body: {
          'id': occupiedBillID,
          'store': 'odontogram_events',
          'data': {'id': occupiedBillID, 'title': 'Synthetic other row'},
        });
        await expectLater(
          treatmentBills.remote!.put([
            RowToWriteRemotely(
              id: occupiedBillID,
              data: jsonEncode(TreatmentBill.fromJson({
                'id': occupiedBillID,
                'patientID': patientID,
                'odontogramEventID': unrelatedEventID,
                'treatmentNameSnapshot': 'Synthetic other charge',
                'chargeAmount': 1,
              })),
            ),
          ]),
          throwsStateError,
        );
        expect(
          (await pb.collection(dataCollectionName).getOne(occupiedBillID))
              .getStringValue('store'),
          'odontogram_events',
        );

        for (final bound in stores) {
          await bound.close();
        }
      } finally {
        for (final Store store in [
          patients,
          odontogramEvents,
          treatmentPaymentEntries,
          treatmentBills
        ]) {
          await store.deactivatePersistenceSession();
          await store.local?.dispose();
          store.local = null;
          store.remote = null;
          store.endSession();
        }
        await Hive.close();
        Directory.current = originalWorkingDirectory.path;
        if (server != null) {
          server.kill();
          await server.exitCode
              .timeout(const Duration(seconds: 5), onTimeout: () => -1);
        }
        // Only the exact child returned by createTemp above may be removed.
        final resolvedRoot = await tempRoot.resolveSymbolicLinks();
        final resolvedScratch = await scratch.resolveSymbolicLinks();
        final safeChild = p.isWithin(resolvedRoot, resolvedScratch) &&
            p.basename(resolvedScratch).startsWith('apexo-payment-e2e-');
        if (!safeChild) {
          fail('Refusing to remove a scratch path outside ignored tmp/.');
        }
        if (await scratch.exists()) await scratch.delete(recursive: true);
      }
    },
    skip: executablePath == null
        ? 'Set APEXO_PAYMENT_E2E_PB_EXE to a PocketBase executable.'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _BoundStore {
  const _BoundStore(this.store, this.name);

  final Store store;
  final String name;

  Future<void> bind(PocketBase pb, Directory scratch, String client) async {
    await store.loaded;
    await store.deactivatePersistenceSession();
    await store.local?.dispose();
    final hiveDir =
        Directory('${scratch.path}${Platform.pathSeparator}hive-$client');
    await hiveDir.create();
    store.local = SaveLocal(
      name: name,
      uniqueId: 'payment-e2e-$client',
      storagePath: hiveDir.path,
    );
    store.remote = store is TreatmentBills
        ? TreatmentBillSaveRemote(pbInstance: pb)
        : SaveRemote(pbInstance: pb, storeName: name);
    store.manualSyncOnly = true;
    await store.remote!.checkOnline();
    await store.deleteMemoryAndLoadFromPersistence();
    await sync();
  }

  Future<void> sync() async {
    final result = await store.synchronize();
    expect(
      result.where((step) =>
          step.exception != null && step.exception != 'nothing to sync'),
      isEmpty,
      reason: '$name did not synchronize cleanly.',
    );
  }

  Future<void> close() async {
    await store.deactivatePersistenceSession();
    await store.local?.dispose();
    store.local = null;
    store.remote = null;
  }
}

Future<int> _remoteCount(PocketBase pb, String store) async {
  final page = await pb.collection(dataCollectionName).getList(
        filter: 'store="$store"',
        perPage: 1,
      );
  return page.totalItems;
}

Future<void> _waitForHealth(PocketBase pb) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    try {
      await pb.health.check().timeout(const Duration(milliseconds: 500));
      return;
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }
  fail('Temporary PocketBase did not start.');
}

void _expectFinances({
  required double charges,
  required double income,
  required double rec,
  required double noRec,
  required double balance,
}) {
  final summary = FinancesSummary(
    accounts: treatmentBills.allAccounts,
    expenseRecords: const [],
  );
  expect(summary.confirmedCharges, charges);
  expect(summary.income, income);
  expect(summary.recIncome, rec);
  expect(summary.noRecIncome, noRec);
  expect(summary.treatmentBalance, balance);
  expect(summary.treatmentOverpayment, 0);
}

String _nonce() {
  final random = Random.secure();
  return List.generate(12, (_) => random.nextInt(36).toRadixString(36)).join();
}
