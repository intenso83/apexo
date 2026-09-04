import 'package:apexo_patient_intake/form_configuration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mandatory identity entries cannot be switched off', () {
    final configuration = IntakeFormConfiguration.defaults();
    for (final id in mandatoryFieldIds) {
      final item = configuration.itemById(id)!;
      expect(configuration.canDisableItem(item), isFalse);
      item.enabled = false;
    }

    configuration.normalize();

    for (final id in mandatoryFieldIds) {
      expect(configuration.itemById(id)!.enabled, isTrue);
    }
  });

  test('normalization always preserves one contact method', () {
    final configuration = IntakeFormConfiguration.defaults();
    for (final id in contactFieldIds) {
      configuration.itemById(id)!.enabled = false;
    }

    configuration.normalize();

    expect(
      contactFieldIds.where((id) => configuration.itemById(id)!.enabled).length,
      1,
    );
  });

  test('page, item order, visibility and movement survive serialization', () {
    final configuration = IntakeFormConfiguration.defaults();
    final medicalPage = configuration.pageById('medical_context')!;
    medicalPage.order = 0;
    configuration.pageById('identity')!.order = 2;
    final allergies = configuration.itemById('allergies')!
      ..enabled = false
      ..pageId = 'care'
      ..order = 0;
    configuration.markChanged();

    final restored = IntakeFormConfiguration.fromJson(configuration.toJson());

    expect(restored.orderedPages.first.id, medicalPage.id);
    expect(restored.itemById(allergies.id)!.enabled, isFalse);
    expect(restored.itemById(allergies.id)!.pageId, 'care');
  });
}
