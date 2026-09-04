import 'dart:io';

import 'package:apexo/features/odontogram/treatment_target.dart';
import 'package:apexo/features/therapy_catalog/therapy_catalog_demo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('beta demo catalogue exposes the complete translated treatment list',
      () {
    final raw =
        File('assets/therapy_catalogue_translations.json').readAsStringSync();
    final catalogue = parseDemoTherapyCatalogue(raw);

    expect(catalogue.groups, hasLength(14));
    expect(catalogue.procedures, hasLength(279));
    expect(catalogue.groups.map((group) => group.id).toSet(), hasLength(14));
    expect(
      catalogue.procedures.map((procedure) => procedure.id).toSet(),
      hasLength(279),
    );
    expect(
      catalogue.procedures.every((procedure) => procedure.id.length == 15),
      isTrue,
    );
    expect(
      catalogue.procedures
          .map((procedure) => procedure.handlingMode)
          .whereType<ProcedureHandlingMode>()
          .toSet(),
      containsAll(ProcedureHandlingMode.values),
    );
    expect(
      catalogue.procedures.every(
        (procedure) => catalogue.groups
            .any((group) => group.id == procedure.therapyGroupID),
      ),
      isTrue,
    );
  });
}
