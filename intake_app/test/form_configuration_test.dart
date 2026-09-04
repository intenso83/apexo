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
    final conditionsPage = configuration.pageById('conditions')!;
    conditionsPage.order = 0;
    configuration.pageById('identity')!.order = 2;
    final allergies = configuration.itemById('allergies')!
      ..enabled = false
      ..pageId = 'care'
      ..order = 0;
    configuration.markChanged();

    final restored = IntakeFormConfiguration.fromJson(configuration.toJson());

    expect(restored.orderedPages.first.id, conditionsPage.id);
    expect(restored.itemById(allergies.id)!.enabled, isFalse);
    expect(restored.itemById(allergies.id)!.pageId, 'care');
  });

  test('practice branding survives serialization', () {
    final configuration = IntakeFormConfiguration.defaults()
      ..practiceNames['el'] = 'ΔΟΚΙΜΑΣΤΙΚΟ ΟΔΟΝΤΙΑΤΡΕΙΟ'
      ..practiceNames['en'] = 'TEST DENTAL PRACTICE'
      ..customLogoPath = '/private/practice-logo.png';

    final restored = IntakeFormConfiguration.fromJson(configuration.toJson());

    expect(restored.practiceName('el'), 'ΔΟΚΙΜΑΣΤΙΚΟ ΟΔΟΝΤΙΑΤΡΕΙΟ');
    expect(restored.practiceName('en'), 'TEST DENTAL PRACTICE');
    expect(restored.customLogoPath, '/private/practice-logo.png');
  });

  test(
    'removed page and retired questions cannot return from old settings',
    () {
      final configuration = IntakeFormConfiguration.defaults();

      expect(configuration.pageById('medical_context'), isNull);
      expect(configuration.itemById('penicillin_allergy'), isNull);
      expect(configuration.itemById('latex_allergy'), isNull);
      expect(configuration.itemById('alcohol_use'), isNull);
      expect(configuration.itemById('antibiotic_allergy'), isNotNull);
    },
  );
}
