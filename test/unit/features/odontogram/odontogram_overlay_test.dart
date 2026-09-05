import 'package:apexo/features/odontogram/odontogram_event_model.dart';
import 'package:apexo/features/odontogram/odontogram_assets.dart';
import 'package:apexo/features/odontogram/odontogram_overlay_model.dart';
import 'package:apexo/features/odontogram/odontogram_overlay_painter.dart';
import 'package:apexo/features/odontogram/treatment_target.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('markers preserve independent restorations in stable source order', () {
    OdontogramEvent event({
      required String id,
      required int recordedAt,
      required String surface,
      String status = 'completed',
      int? color,
    }) =>
        OdontogramEvent.fromJson({
          'id': id,
          'patientID': 'patient1234567',
          'toothFdi': 16,
          'surfaces': [surface],
          'procedureID': 'procedure123456',
          'procedureNameSnapshot': 'Filling',
          'overlayKind': 'filling',
          'drawingBehavior': 'filling',
          'status': status,
          'recordedAt': recordedAt,
          if (color != null) 'materialColorArgb': color,
        });

    final markers = odontogramOverlayMarkersForTooth([
      event(
        id: 'new-filling',
        recordedAt: 200,
        surface: 'distal',
        color: 0xFF112233,
      ),
      event(id: 'old-filling', recordedAt: 100, surface: 'mesial'),
      event(
        id: 'cancelled-filling',
        recordedAt: 300,
        surface: 'facial',
        status: 'cancelled',
      ),
    ], 16);

    expect(markers.map((marker) => marker.eventID), [
      'old-filling',
      'new-filling',
    ]);
    expect(markers.first.surfaces, {DentalSurface.mesial});
    expect(markers.last.surfaces, {DentalSurface.distal});
    expect(markers.last.materialColorArgb, 0xFF112233);
  });

  test('an active replacement suppresses only its explicit predecessor', () {
    OdontogramEvent event(String id, {String supersedes = ''}) =>
        OdontogramEvent.fromJson({
          'id': id,
          'patientID': 'patient1234567',
          'toothFdi': 16,
          'surfaces': ['occlusalIncisal'],
          'procedureID': 'procedure123456',
          'procedureNameSnapshot': 'Filling',
          'overlayKind': 'filling',
          'recordedAt': id == 'replacement' ? 200 : 100,
          if (supersedes.isNotEmpty) 'supersedesEventID': supersedes,
        });

    final markers = odontogramOverlayMarkersForTooth([
      event('replacement', supersedes: 'old-event'),
      event('old-event'),
      event('independent-event'),
    ], 16);
    expect(markers.map((marker) => marker.eventID), [
      'independent-event',
      'replacement',
    ]);
  });

  test('saved material color overrides the built-in treatment color', () {
    expect(
      odontogramTreatmentMaterialColor(
        OdontogramOverlayKind.filling,
        materialColorArgb: 0xFF7B2CBF,
      ).toARGB32(),
      0xFF7B2CBF,
    );
  });

  test('bridge marker preserves the mapped unit role', () {
    final event = OdontogramEvent.fromJson({
      'patientID': 'patient1234567',
      'targetScope': TreatmentTargetScope.bridge.name,
      'procedureID': 'procedure123456',
      'procedureNameSnapshot': 'Bridge',
      'overlayKind': 'bridge',
      'bridgeUnits': [
        {'toothFdi': 14, 'role': 'abutment'},
        {'toothFdi': 15, 'role': 'pontic'},
      ],
    });

    final marker = odontogramOverlayMarkersForTooth([event], 15).single;
    expect(marker.kind, OdontogramOverlayKind.bridge);
    expect(marker.bridgeRole, BridgeUnitRole.pontic);
  });

  test('oral view keeps crown filling and extraction overlays', () {
    expect(
      odontogramOverlayVisibleInView(
        OdontogramOverlayKind.crown,
        OdontogramView.oral,
      ),
      isTrue,
    );
    expect(
      odontogramOverlayVisibleInView(
        OdontogramOverlayKind.filling,
        OdontogramView.oral,
      ),
      isTrue,
    );
    expect(
      odontogramOverlayVisibleInView(
        OdontogramOverlayKind.extraction,
        OdontogramView.oral,
      ),
      isTrue,
    );
    for (final hiddenKind in [
      OdontogramOverlayKind.rootCanal,
      OdontogramOverlayKind.implant,
      OdontogramOverlayKind.bridge,
    ]) {
      expect(
        odontogramOverlayVisibleInView(hiddenKind, OdontogramView.oral),
        isFalse,
      );
      expect(
        odontogramOverlayVisibleInView(hiddenKind, OdontogramView.facial),
        isTrue,
      );
    }
  });
}
