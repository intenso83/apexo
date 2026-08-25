const _greekSearchReplacements = <String, String>{
  'ά': 'α',
  'ὰ': 'α',
  'ἀ': 'α',
  'ἁ': 'α',
  'έ': 'ε',
  'ὲ': 'ε',
  'ἐ': 'ε',
  'ἑ': 'ε',
  'ή': 'η',
  'ὴ': 'η',
  'ἠ': 'η',
  'ἡ': 'η',
  'ί': 'ι',
  'ὶ': 'ι',
  'ϊ': 'ι',
  'ΐ': 'ι',
  'ἰ': 'ι',
  'ἱ': 'ι',
  'ό': 'ο',
  'ὸ': 'ο',
  'ὀ': 'ο',
  'ὁ': 'ο',
  'ύ': 'υ',
  'ὺ': 'υ',
  'ϋ': 'υ',
  'ΰ': 'υ',
  'ὐ': 'υ',
  'ὑ': 'υ',
  'ώ': 'ω',
  'ὼ': 'ω',
  'ὠ': 'ω',
  'ὡ': 'ω',
  'ς': 'σ',
};

/// Produces the same searchable representation for stored patient data and
/// user-entered queries. Modern and common polytonic Greek marks are folded,
/// Arabic alif variants retain Apexo's existing behavior, and whitespace is
/// collapsed.
String normalizePatientSearch(String input) {
  var value = input.toLowerCase().replaceAll(RegExp('أ|إ'), 'ا');
  for (final replacement in _greekSearchReplacements.entries) {
    value = value.replaceAll(replacement.key, replacement.value);
  }
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}
