import 'package:apexo/features/odontogram/odontogram_event_model.dart';
import 'package:apexo/features/odontogram/selected_tooth_treatment_panel.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  testWidgets(
      'filters tooth and bridge references, sorts newest first and stays bounded',
      (tester) async {
    var showAllPressed = false;
    final events = [
      _toothEvent(
        id: 'older-direct',
        fdi: 46,
        procedure: 'Older filling',
        recordedAt: DateTime(2024, 1, 1),
      ),
      _toothEvent(
        id: 'other-tooth',
        fdi: 11,
        procedure: 'Other tooth treatment',
        recordedAt: DateTime(2026, 1, 1),
      ),
      _bridgeEvent(
        id: 'newest-bridge',
        procedure: 'Three-unit bridge',
        recordedAt: DateTime(2025, 5, 1),
      ),
      _toothEvent(
        id: 'middle-direct',
        fdi: 46,
        procedure: 'Recent filling',
        recordedAt: DateTime(2025, 4, 1),
      ),
      OdontogramEvent.fromJson({
        'id': 'patient-level',
        'patientID': 'patient-1',
        'procedureNameSnapshot': 'General consultation',
        'targetScope': 'patient',
      }),
    ];

    await pumpApexoApp(
      tester,
      SizedBox(
        width: 380,
        child: SelectedToothTreatmentPanel(
          selectedFdi: 46,
          events: events,
          maxVisibleEvents: 2,
          maxListHeight: 300,
          onShowAll: () => showAllPressed = true,
        ),
      ),
    );

    expect(find.text('${txt('selectedTooth')} 46'), findsOneWidget);
    expect(find.text('Three-unit bridge'), findsOneWidget);
    expect(find.text('Recent filling'), findsOneWidget);
    expect(find.text('Older filling'), findsNothing);
    expect(find.text('Other tooth treatment'), findsNothing);
    expect(find.text('General consultation'), findsNothing);
    expect(
        find.textContaining('46 ${txt('bridgeRole_pontic')}'), findsOneWidget);

    final bridgeTop = tester.getTopLeft(find.text('Three-unit bridge')).dy;
    final directTop = tester.getTopLeft(find.text('Recent filling')).dy;
    expect(bridgeTop, lessThan(directTop));

    expect(find.byKey(const Key('selected-tooth-treatment-show-all')),
        findsOneWidget);
    await tester.tap(
      find.byKey(const Key('selected-tooth-treatment-show-all')),
    );
    await tester.pump(const Duration(milliseconds: 150));
    expect(showAllPressed, isTrue);
  });

  testWidgets('shows localized empty state for a tooth with no references',
      (tester) async {
    await pumpApexoApp(
      tester,
      SizedBox(
        width: 320,
        child: SelectedToothTreatmentPanel(
          selectedFdi: 38,
          events: [
            _toothEvent(
              id: 'tooth-37',
              fdi: 37,
              procedure: 'Treatment on 37',
              recordedAt: DateTime(2025, 1, 1),
            ),
          ],
        ),
      ),
    );

    expect(find.byKey(const Key('selected-tooth-treatment-empty')),
        findsOneWidget);
    expect(find.text(txt('noOdontogramEvents')), findsOneWidget);
    expect(
        find.byKey(const Key('selected-tooth-treatment-list')), findsNothing);
  });

  testWidgets('shows surfaces, material swatch, laboratory and notes',
      (tester) async {
    final event = _toothEvent(
      id: 'detailed-event',
      fdi: 46,
      procedure: 'Composite restoration',
      recordedAt: DateTime(2025, 3, 2),
      surfaces: const ['mesial', 'facial'],
      materialColorArgb: 0xFFAA3344,
      laboratory: 'Praxis Lab',
      notes: 'Shade A2; review contact point.',
    );

    await pumpApexoApp(
      tester,
      SizedBox(
        width: 380,
        child: SelectedToothTreatmentPanel(
          selectedFdi: 46,
          events: [event],
        ),
      ),
    );

    expect(find.textContaining(txt('surfaceMesial')), findsOneWidget);
    expect(find.textContaining(txt('surfaceFacial')), findsOneWidget);
    expect(find.byKey(const Key('selected-tooth-material-detailed-event')),
        findsOneWidget);
    expect(find.text('${txt('laboratory')}: Praxis Lab'), findsOneWidget);
    expect(find.text('Shade A2; review contact point.'), findsOneWidget);
  });

  testWidgets('makes every matching event available in the bounded scroll',
      (tester) async {
    final events = List.generate(
      8,
      (index) => _toothEvent(
        id: 'scroll-event-$index',
        fdi: 46,
        procedure: 'Treatment ${index + 1}',
        recordedAt: DateTime(2025, 1, index + 1),
      ),
    );

    await pumpApexoApp(
      tester,
      SizedBox(
        width: 380,
        child: SelectedToothTreatmentPanel(
          selectedFdi: 46,
          events: events,
          maxListHeight: 220,
        ),
      ),
    );

    expect(odontogramEventsForSelectedTooth(events, 46), hasLength(8));
    expect(find.byKey(const Key('selected-tooth-treatment-hidden-count')),
        findsNothing);
    expect(find.text('Treatment 8'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Treatment 1'),
      180,
      scrollable: find.descendant(
        of: find.byKey(const Key('selected-tooth-treatment-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Treatment 1'), findsOneWidget);
  });
}

OdontogramEvent _toothEvent({
  required String id,
  required int fdi,
  required String procedure,
  required DateTime recordedAt,
  List<String> surfaces = const ['occlusalIncisal'],
  int? materialColorArgb,
  String laboratory = '',
  String notes = '',
}) {
  final event = OdontogramEvent.fromJson({
    'id': id,
    'patientID': 'patient-1',
    'procedureNameSnapshot': procedure,
    'targetScope': 'tooth',
    'toothFdi': fdi,
    'surfaces': surfaces,
    'status': 'completed',
    if (materialColorArgb != null) 'materialColorArgb': materialColorArgb,
    if (laboratory.isNotEmpty) 'laboratoryNameSnapshot': laboratory,
    if (notes.isNotEmpty) 'notes': notes,
  });
  event.recordedAt = recordedAt;
  return event;
}

OdontogramEvent _bridgeEvent({
  required String id,
  required String procedure,
  required DateTime recordedAt,
}) {
  final event = OdontogramEvent.fromJson({
    'id': id,
    'patientID': 'patient-1',
    'procedureNameSnapshot': procedure,
    'targetScope': 'bridge',
    'status': 'existing',
    'bridgeUnits': const [
      {'toothFdi': 45, 'role': 'abutment'},
      {'toothFdi': 46, 'role': 'pontic'},
      {'toothFdi': 47, 'role': 'abutment'},
    ],
  });
  event.recordedAt = recordedAt;
  return event;
}
