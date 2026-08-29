import 'package:apexo/features/odontogram/odontogram_event_model.dart';
import 'package:apexo/features/odontogram/odontogram_assets.dart';
import 'package:apexo/features/odontogram/odontogram_overlay_model.dart';
import 'package:apexo/features/odontogram/odontogram_overlay_painter.dart';
import 'package:apexo/features/odontogram/treatment_target.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('markers keep one newest non-cancelled symbol of each kind', () {
    OdontogramEvent event(String kind, String status) =>
        OdontogramEvent.fromJson({
          'patientID': 'patient1234567',
          'toothFdi': 16,
          'surfaces': ['wholeTooth'],
          'procedureID': 'procedure123456',
          'procedureNameSnapshot': kind,
          'overlayKind': kind,
          'status': status,
        });

    final markers = odontogramOverlayMarkersForTooth([
      event('crown', 'planned'),
      event('crown', 'completed'),
      event('rootCanal', 'completed'),
      event('extraction', 'cancelled'),
    ], 16);

    expect(markers.map((marker) => marker.kind), [
      OdontogramOverlayKind.crown,
      OdontogramOverlayKind.rootCanal,
    ]);
    expect(markers.first.status, OdontogramEventStatus.planned);
    expect(markers.first.surfaces, {DentalSurface.wholeTooth});
    expect(markers.first.procedureName, 'crown');
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

  test('oral view is reserved for crown and filling overlays', () {
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
    for (final hiddenKind in [
      OdontogramOverlayKind.rootCanal,
      OdontogramOverlayKind.implant,
      OdontogramOverlayKind.extraction,
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
