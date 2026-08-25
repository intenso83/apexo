class PatientContactType {
  static const homePhone = 'home_phone';
  static const workPhone = 'work_phone';
  static const mobile = 'mobile';
  static const phone = 'phone';
  static const email = 'email';
  static const other = 'other';

  static const values = {
    homePhone,
    workPhone,
    mobile,
    phone,
    email,
    other,
  };

  static bool isTelephone(String value) =>
      value == homePhone ||
      value == workPhone ||
      value == mobile ||
      value == phone;
}

/// A structured patient contact used by the patient-fields prototype.
///
/// [rawValue] is deliberately kept separate from [normalizedValue] so a
/// migration never destroys the exact DentalWin value while preparing a
/// searchable representation.
class PatientContact {
  String id;
  String type;
  String label;
  String rawValue;
  String normalizedValue;
  bool isPrimary;
  bool? smsAllowed;
  String notes;

  PatientContact.fromJson(Map<String, dynamic> json)
      : id = json['id']?.toString() ?? '',
        type = json['type']?.toString() ?? PatientContactType.other,
        label = json['label']?.toString() ?? '',
        rawValue = json['raw_value']?.toString() ?? '',
        normalizedValue = json['normalized_value']?.toString() ?? '',
        isPrimary = json['is_primary'] == true,
        smsAllowed = json['sms_allowed'] as bool?,
        notes = json['notes']?.toString() ?? '';

  PatientContact copy() => PatientContact.fromJson(toJson());

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'type': type,
      if (label.isNotEmpty) 'label': label,
      'raw_value': rawValue,
      if (normalizedValue.isNotEmpty) 'normalized_value': normalizedValue,
      if (isPrimary) 'is_primary': true,
      if (smsAllowed != null) 'sms_allowed': smsAllowed,
      if (notes.isNotEmpty) 'notes': notes,
    };
  }
}
