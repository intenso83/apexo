import 'package:apexo/features/odontogram/treatment_target.dart';

class ProcedureHandlingDecision {
  const ProcedureHandlingDecision({
    required this.mode,
    required this.inferred,
    required this.needsReview,
    required this.rule,
  });

  final ProcedureHandlingMode mode;
  final bool inferred;
  final bool needsReview;
  final String rule;
}

/// Conservative compatibility classifier for the DentalWin catalogue that was
/// imported before procedures had an explicit handling-mode field.
///
/// It never replaces an explicit user choice. Ambiguous matches fall back to a
/// patient-level entry and are visibly marked for review in Settings.
ProcedureHandlingDecision classifyProcedureHandling({
  required String procedureName,
  required String groupName,
}) {
  final procedure = _normalize(procedureName);
  final group = _normalize(groupName);

  // The procedure name is the most specific signal and must win over its
  // parent group. In Greek, "ακινητη" (fixed) contains the full
  // substring "κινητη" (removable), so classifying the combined
  // group/name text made fixed crowns look like removable prostheses.
  if (_hasAny(procedure, const [
    'bridge',
    'maryland',
    'γεφυρ',
  ])) {
    return _decision(ProcedureHandlingMode.bridge, 'bridge_keyword');
  }

  if (_hasAny(procedure, const [
    'filling',
    'restoration',
    'composite',
    'amalgam',
    'sealant',
    'inlay',
    'onlay',
    'εμφραξ',
    'σφραγ',
    'ρητιν',
  ])) {
    return _decision(ProcedureHandlingMode.surfaceBased, 'surface_keyword');
  }

  if (_hasAny(procedure, const [
    'crown',
    'veneer',
    'extraction',
    'implant',
    'endodont',
    'root canal',
    'pulpotomy',
    'στεφαν',
    'οψη',
    'εξαγωγ',
    'εξακτικ',
    'εμφυτευ',
    'ενδοδοντ',
    'απονευρ',
    'πολφοτομ',
  ])) {
    return _decision(ProcedureHandlingMode.wholeTooth, 'whole_tooth_keyword');
  }

  if (_hasAny(procedure, const [
    'removable',
    'denture',
    'partial denture',
    'κινητη προσθετικ',
    'οδοντοστοιχ',
  ])) {
    return _decision(
      ProcedureHandlingMode.removableProsthesis,
      'removable_keyword',
    );
  }

  if (_hasAny(procedure, const [
    'general',
    'diagnos',
    'prevent',
    'consult',
    'x-ray',
    'radiograph',
    'orthodont',
    'periodont',
    'γενικ',
    'διαγνωσ',
    'προληψ',
    'ακτινογραφ',
    'ορθοδοντ',
    'περιοδοντ',
  ])) {
    return _decision(ProcedureHandlingMode.patientLevel, 'patient_keyword');
  }

  // Group-level fallbacks come only after procedure-specific recognition.
  if (_hasAny(group, const ['bridge', 'maryland', 'γεφυρ'])) {
    return _decision(ProcedureHandlingMode.bridge, 'bridge_group');
  }
  if (_hasAny(group, const ['fixed prosth', 'ακινητη προσθετικ'])) {
    return _decision(ProcedureHandlingMode.wholeTooth, 'fixed_group');
  }
  if (_hasAny(group, const [
    'removable',
    'denture',
    'κινητη προσθετικ',
    'οδοντοστοιχ',
  ])) {
    return _decision(
      ProcedureHandlingMode.removableProsthesis,
      'removable_group',
    );
  }
  if (_hasAny(group, const [
    'endodont',
    'implant',
    'ενδοδοντ',
    'εμφυτευ',
    'εξακτικ',
  ])) {
    return _decision(ProcedureHandlingMode.wholeTooth, 'whole_tooth_group');
  }
  if (_hasAny(group, const [
    'general',
    'diagnos',
    'prevent',
    'orthodont',
    'periodont',
    'γενικ',
    'διαγνωσ',
    'προληψ',
    'ορθοδοντ',
    'περιοδοντ',
  ])) {
    return _decision(ProcedureHandlingMode.patientLevel, 'patient_group');
  }

  return const ProcedureHandlingDecision(
    mode: ProcedureHandlingMode.patientLevel,
    inferred: true,
    needsReview: true,
    rule: 'safe_fallback',
  );
}

ProcedureHandlingDecision _decision(
  ProcedureHandlingMode mode,
  String rule,
) =>
    ProcedureHandlingDecision(
      mode: mode,
      inferred: true,
      needsReview: false,
      rule: rule,
    );

bool _hasAny(String value, List<String> needles) => needles.any(value.contains);

String _normalize(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll('ά', 'α')
    .replaceAll('έ', 'ε')
    .replaceAll('ή', 'η')
    .replaceAll('ί', 'ι')
    .replaceAll('ϊ', 'ι')
    .replaceAll('ΐ', 'ι')
    .replaceAll('ό', 'ο')
    .replaceAll('ύ', 'υ')
    .replaceAll('ϋ', 'υ')
    .replaceAll('ΰ', 'υ')
    .replaceAll('ώ', 'ω')
    .replaceAll('ς', 'σ');
