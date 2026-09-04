import 'dart:convert';

import 'package:apexo/features/therapy_catalog/procedure_catalog_model.dart';
import 'package:apexo/features/therapy_catalog/procedure_handling_classifier.dart';
import 'package:apexo/features/therapy_catalog/therapy_group_model.dart';
import 'package:flutter/services.dart';

class DemoTherapyCatalogue {
  const DemoTherapyCatalogue({
    required this.groups,
    required this.procedures,
  });

  final List<TherapyGroup> groups;
  final List<ProcedureCatalogItem> procedures;
}

const _demoGroupColors = <String, int>{
  'Οδον. Χειρουργική 1': 0xFF0F8B8D,
  'Οδοντ. Χειρουργική 2': 0xFF5B6BC0,
  'Ενδοδοντία': 0xFF246BCE,
  'Εξακτική/Χειρουργική': 0xFFE05D5D,
  'Ακίνητη Προσθετική': 0xFF2E9D63,
  'Κινητή Προσθετική': 0xFFE08A1E,
  'Ορθοδοντική': 0xFF477A8B,
  'Περιοδοντολογία': 0xFFB34FA2,
  'Εμφυτεύματα': 0xFF6D7F2B,
  'Πρόληψη': 0xFF8E6548,
  'Διάγνωση': 0xFF7A5AF8,
  'Παιδοδοντία': 0xFF008F7A,
  'Γενικά': 0xFFC05C84,
  'Uncategorized legacy review': 0xFF777777,
};

Future<DemoTherapyCatalogue> loadDemoTherapyCatalogue() async {
  final raw =
      await rootBundle.loadString('assets/therapy_catalogue_translations.json');
  return parseDemoTherapyCatalogue(raw);
}

DemoTherapyCatalogue parseDemoTherapyCatalogue(String raw) {
  final rows = (jsonDecode(raw) as List<dynamic>)
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .where((row) =>
          (row['recordID']?.toString().isNotEmpty ?? false) &&
          (row['greek']?.toString().trim().isNotEmpty ?? false) &&
          (row['groupGreek']?.toString().trim().isNotEmpty ?? false))
      .toList();

  final discoveredGroupNames = <String>[];
  for (final row in rows) {
    final groupName = row['groupGreek'].toString().trim();
    if (!discoveredGroupNames.contains(groupName)) {
      discoveredGroupNames.add(groupName);
    }
  }
  final groupNames = <String>[
    ..._demoGroupColors.keys.where(discoveredGroupNames.contains),
    ...discoveredGroupNames.where(
      (name) => !_demoGroupColors.containsKey(name),
    ),
  ];

  final groups = <TherapyGroup>[];
  final groupByName = <String, TherapyGroup>{};
  for (var index = 0; index < groupNames.length; index++) {
    final name = groupNames[index];
    final group = TherapyGroup.fromJson({
      'id': 'demogrp${(index + 1).toString().padLeft(8, '0')}',
      'name': name,
      'displayOrder': index,
      'colorValue': _demoGroupColors[name] ?? 0xFF64748B,
      'sourceID': 'demo',
      'migration': const {'source': 'beta_demo_fixture'},
    });
    groups.add(group);
    groupByName[name] = group;
  }

  final procedures = <ProcedureCatalogItem>[];
  for (final row in rows) {
    final name = row['greek'].toString().trim();
    final groupName = row['groupGreek'].toString().trim();
    final group = groupByName[groupName]!;
    final decision = classifyProcedureHandling(
      procedureName: name,
      groupName: groupName,
    );
    final procedure = ProcedureCatalogItem.fromJson({
      'id': row['recordID'].toString(),
      'name': name,
      'therapyGroupID': group.id,
      'therapyGroupSourceID': group.sourceID,
      'sourceCode': row['sourceCode']?.toString() ?? '',
      'basePrice': 0,
      'migration': const {'source': 'beta_demo_fixture'},
    });
    procedure.applyHandlingMode(decision.mode);
    procedures.add(procedure);
  }

  return DemoTherapyCatalogue(groups: groups, procedures: procedures);
}
