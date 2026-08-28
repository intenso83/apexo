import 'treatment_target.dart';

/// The visual mark drawn over a tooth after a treatment event is recorded.
///
/// This is deliberately separate from [ProcedureHandlingMode]. Two procedures
/// can share the same whole-tooth workflow while drawing very different marks,
/// for example a crown and a root-canal treatment.
enum OdontogramOverlayKind {
  none,
  filling,
  crown,
  rootCanal,
  extraction,
  implant,
  bridge,
}

/// Conservative compatibility classifier for catalogue items that predate the
/// explicit odontogram-overlay setting.
///
/// Procedure-name matches take priority over the group name. This prevents a
/// crown procedure inside an endodontic group from being painted as a root
/// canal merely because of its group.
OdontogramOverlayKind inferOdontogramOverlay({
  required String procedureName,
  required String groupName,
  TreatmentTargetScope? targetScope,
}) {
  if (targetScope == TreatmentTargetScope.bridge) {
    return OdontogramOverlayKind.bridge;
  }

  final procedure = _normalize(procedureName);
  final group = _normalize(groupName);
  final fromProcedure = _classifyText(procedure);
  if (fromProcedure != null) return fromProcedure;

  final fromGroup = _classifyText(group);
  if (fromGroup != null) return fromGroup;

  return OdontogramOverlayKind.none;
}

OdontogramOverlayKind? _classifyText(String value) {
  if (_hasAny(value, const [
    'root canal',
    'endodont',
    'pulpotomy',
    'ενδοδοντ',
    'απονευρ',
    'πολφοτομ',
  ])) {
    return OdontogramOverlayKind.rootCanal;
  }
  if (_hasAny(value, const [
    'extraction',
    'extract ',
    'εξαγωγ',
    'εξακτικ',
  ])) {
    return OdontogramOverlayKind.extraction;
  }
  if (_hasAny(value, const [
    'implant',
    'εμφυτευ',
  ])) {
    return OdontogramOverlayKind.implant;
  }
  if (_hasAny(value, const [
    'crown',
    'veneer',
    'στεφαν',
    'οψη',
  ])) {
    return OdontogramOverlayKind.crown;
  }
  if (_hasAny(value, const [
    'bridge',
    'maryland',
    'γεφυρ',
  ])) {
    return OdontogramOverlayKind.bridge;
  }
  if (_hasAny(value, const [
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
    return OdontogramOverlayKind.filling;
  }
  return null;
}

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
