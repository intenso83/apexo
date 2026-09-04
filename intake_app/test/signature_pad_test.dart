import 'dart:ui';

import 'package:apexo_patient_intake/signature_pad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('captures stylus movement inside a scrollable page', (
    tester,
  ) async {
    final controller = SignatureController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 100),
                SignaturePad(
                  controller: controller,
                  label: 'Sign here',
                  clearLabel: 'Clear',
                ),
                const SizedBox(height: 600),
              ],
            ),
          ),
        ),
      ),
    );

    final pad = find.byKey(const ValueKey('signature_pad'));
    final start = tester.getCenter(pad) - const Offset(80, 20);
    final stylus = await tester.createGesture(kind: PointerDeviceKind.stylus);
    await stylus.down(start);
    await stylus.moveTo(start + const Offset(50, 25));
    await stylus.moveTo(start + const Offset(110, -5));
    await stylus.up();
    await tester.pump();

    expect(controller.isEmpty, isFalse);
    expect(controller.strokes.single.length, greaterThanOrEqualTo(3));
    expect(controller.toJson().single.first['x'], inInclusiveRange(0, 1));
    expect(tester.takeException(), isNull);
  });
}
