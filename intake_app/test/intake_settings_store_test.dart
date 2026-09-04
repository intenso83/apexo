import 'dart:io';

import 'package:apexo_patient_intake/intake_settings_store.dart';
import 'package:apexo_patient_intake/staff_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stores a salted verifier rather than the settings password', () async {
    final directory = await Directory.systemTemp.createTemp('intake_settings_');
    addTearDown(() => directory.delete(recursive: true));
    final store = IntakeSettingsStore(directory: directory, iterations: 20);

    await store.setInitialPassword('correct horse');

    final entries = await directory.list().toList();
    final saved = await entries.whereType<File>().single.readAsString();
    expect(saved, isNot(contains('correct horse')));
    expect(saved, contains('PBKDF2-HMAC-SHA256'));

    final restored = IntakeSettingsStore(directory: directory, iterations: 20);
    await restored.load();
    expect((await restored.verifyPassword('correct horse')).success, isTrue);
    expect((await restored.verifyPassword('wrong password')).success, isFalse);
  });

  test('locks settings after five incorrect attempts', () async {
    final directory = await Directory.systemTemp.createTemp('intake_lockout_');
    addTearDown(() => directory.delete(recursive: true));
    final store = IntakeSettingsStore(directory: directory, iterations: 10);
    await store.setInitialPassword('a secure password');

    PasswordVerificationResult? result;
    for (var attempt = 0; attempt < 5; attempt++) {
      result = await store.verifyPassword('definitely wrong');
    }

    expect(result!.locked, isTrue);
    expect((await store.verifyPassword('a secure password')).success, isFalse);
  });

  test('copies a selected practice logo into private app storage', () async {
    final directory = await Directory.systemTemp.createTemp('intake_logo_');
    addTearDown(() => directory.delete(recursive: true));
    final source = File(
      '${directory.path}${Platform.pathSeparator}selected-logo.png',
    );
    await source.writeAsBytes(const [0x89, 0x50, 0x4e, 0x47]);
    final store = IntakeSettingsStore(directory: directory, iterations: 10);

    final importedPath = await store.importCustomLogo(source.path);

    expect(importedPath, isNot(source.path));
    expect(await File(importedPath).readAsBytes(), await source.readAsBytes());
  });

  testWidgets('settings screen is usable on a phone-sized display', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final directory = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'intake_ui_${DateTime.now().microsecondsSinceEpoch}',
    )..createSync();
    addTearDown(() => directory.deleteSync(recursive: true));
    final store = IntakeSettingsStore(directory: directory, iterations: 10);

    await tester.pumpWidget(
      MaterialApp(home: StaffSettingsScreen(store: store)),
    );
    await tester.pump();

    expect(find.text('Patient form settings'), findsOneWidget);
    expect(find.text('Pages'), findsOneWidget);
    await tester.tap(find.text('Entries'));
    await tester.pumpAndSettle();
    expect(find.text('Page to edit'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
