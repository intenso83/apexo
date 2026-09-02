import 'package:apexo/common_widgets/tag_input.dart';
import 'package:apexo/features/patients/patient_contact.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/utils/parsed_phone_number.dart';
import 'package:apexo/utils/phone_numbers_extractor.dart';
import 'package:apexo/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show showDatePicker;

/// Responsive editor for the approved patient-fields model.
///
/// The editor writes to the panel's working [patient] copy. The panel remains
/// responsible for committing that copy to the store when Save is pressed.
class PatientDetailsForm extends StatefulWidget {
  const PatientDetailsForm({
    super.key,
    required this.patient,
    this.readOnly = false,
  });

  final Patient patient;
  final bool readOnly;

  @override
  State<PatientDetailsForm> createState() => _PatientDetailsFormState();
}

class _PatientDetailsFormState extends State<PatientDetailsForm> {
  late final List<PatientContact> _contacts;

  Patient get patient => widget.patient;

  @override
  void initState() {
    super.initState();
    _contacts =
        patient.prototypeContacts.map((contact) => contact.copy()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.readOnly) ...[
          InfoBar(
            title: Text(txt('patientDetails')),
            content: Text(txt('patientFormRequiredHint')),
            severity: InfoBarSeverity.info,
          ),
          const SizedBox(height: 12),
        ],
        _buildIdentitySection(),
        const SizedBox(height: 12),
        _buildContactsSection(),
        const SizedBox(height: 12),
        _buildAddressSection(),
        const SizedBox(height: 12),
        _buildAdministrationSection(),
      ],
    );
  }

  Widget _buildIdentitySection() {
    return _FormSection(
      icon: FluentIcons.contact,
      title: txt('identityAndDemographics'),
      children: [
        _FormField(
          label: txt('registrationNumber'),
          readOnlyValue: patient.registrationNumber.isEmpty
              ? txt('assignedAfterAcceptance')
              : patient.registrationNumber,
        ),
        _FormField(
          key: WK.fieldPatientSurname,
          label: '${txt('surname')} *',
          initialValue: patient.surname,
          readOnly: widget.readOnly,
          onChanged: (value) {
            patient.surname = value;
            _syncDisplayName();
          },
        ),
        _FormField(
          key: WK.fieldPatientFirstName,
          label: '${txt('firstName')} *',
          initialValue: patient.firstName,
          readOnly: widget.readOnly,
          onChanged: (value) {
            patient.firstName = value;
            _syncDisplayName();
          },
        ),
        _FormField(
          label: txt('legacyFullName'),
          initialValue: patient.legacyFullName.isEmpty
              ? patient.title
              : patient.legacyFullName,
          readOnly: widget.readOnly,
          onChanged: (value) {
            patient.legacyFullName = value;
            _syncDisplayName();
          },
        ),
        _FormField(
          label: txt('fatherName'),
          initialValue: patient.patronymic,
          readOnly: widget.readOnly,
          onChanged: (value) => patient.patronymic = value,
        ),
        _FormField(
          label: txt('motherName'),
          initialValue: patient.motherName,
          readOnly: widget.readOnly,
          onChanged: (value) => patient.motherName = value,
        ),
        _FormField.custom(
          label: txt('birthDate'),
          child: _DateField(
            value: patient.birthDate,
            readOnly: widget.readOnly,
            onChanged: (value) {
              setState(() {
                patient.birthDate = value;
                if (value != null) {
                  patient.birth = value.year;
                  patient.approximateBirthYear = null;
                  patient.birthDatePrecision = 'exact';
                } else if (patient.approximateBirthYear == null) {
                  patient.birthDatePrecision = 'unknown';
                }
                patient.nullifyLabels();
              });
            },
          ),
        ),
        _FormField(
          key: WK.fieldPatientYOB,
          label: txt('approximateBirthYear'),
          initialValue: patient.birthDate == null
              ? patient.prototypeBirthYear?.toString() ?? ''
              : '',
          readOnly: widget.readOnly || patient.birthDate != null,
          keyboardType: TextInputType.number,
          onChanged: (value) {
            final year = int.tryParse(value.trim());
            patient.approximateBirthYear = year;
            if (year != null) {
              patient.birth = year;
              patient.birthDate = null;
              patient.birthDatePrecision = 'year_only';
            } else if (patient.birthDate == null) {
              patient.birthDatePrecision = 'unknown';
            }
            patient.nullifyLabels();
          },
        ),
        _FormField.custom(
          label: txt('gender'),
          child: widget.readOnly
              ? _ReadOnlyValue(
                  value: _translatedValue(patient.prototypeSexOrGender))
              : ComboBox<String>(
                  key: WK.fieldPatientGender,
                  isExpanded: true,
                  value: patient.prototypeSexOrGender,
                  items: [
                    ComboBoxItem(value: 'unknown', child: Text(txt('unknown'))),
                    ComboBoxItem(value: 'male', child: Text(txt('male'))),
                    ComboBoxItem(value: 'female', child: Text(txt('female'))),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => patient.setPrototypeSexOrGender(value));
                  },
                ),
        ),
        _FormField(
          label: txt('occupation'),
          initialValue: patient.occupation,
          readOnly: widget.readOnly,
          onChanged: (value) => patient.occupation = value,
        ),
        _FormField(
          label: txt('secondaryOccupation'),
          initialValue: patient.secondaryOccupationLabel,
          readOnly: widget.readOnly,
          onChanged: (value) => patient.secondaryOccupationLabel = value,
        ),
        _FormField(
          label: txt('placeOfOrigin'),
          initialValue: patient.placeOfOriginOrBirth,
          readOnly: widget.readOnly,
          onChanged: (value) => patient.placeOfOriginOrBirth = value,
        ),
        _FormField.custom(
          fullWidth: true,
          label: txt('patientTags'),
          child: widget.readOnly
              ? _ReadOnlyValue(value: patient.tags.join(', '))
              : TagInputWidget(
                  key: WK.fieldPatientTags,
                  suggestions: patients.allTags
                      .map((tag) => TagInputItem(value: tag, label: tag))
                      .toList(),
                  initialValue: patient.tags
                      .map((tag) => TagInputItem(value: tag, label: tag))
                      .toList(),
                  onChanged: (tags) {
                    patient.tags = tags
                        .map((tag) => tag.value)
                        .whereType<String>()
                        .toList();
                    patient.nullifyLabels();
                  },
                  strict: false,
                  limit: 9999,
                  placeholder: '${txt('patientTags')}...',
                ),
        ),
      ],
    );
  }

  Widget _buildContactsSection() {
    return _FormSection(
      icon: FluentIcons.phone,
      title: txt('contactDetails'),
      footer: widget.readOnly
          ? null
          : Align(
              alignment: AlignmentDirectional.centerStart,
              child: Button(
                key: WK.btnAddPatientContact,
                onPressed: _addContact,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(FluentIcons.add, size: 14),
                    const SizedBox(width: 6),
                    Text('${txt('add')} ${txt('contact')}'),
                  ],
                ),
              ),
            ),
      children: [
        if (_contacts.isEmpty)
          _FormField(
            label: txt('contact'),
            readOnlyValue: txt('notSet'),
            fullWidth: true,
          ),
        ..._contacts.asMap().entries.map((entry) {
          final index = entry.key;
          final contact = entry.value;
          return _FormField.custom(
            key: ObjectKey(contact),
            label: _contactTypeLabel(contact.type),
            fullWidth: true,
            child: _ContactEditor(
              index: index,
              contact: contact,
              readOnly: widget.readOnly,
              onChanged: () {
                setState(_syncContacts);
              },
              onPrimaryChanged: (selected) {
                setState(() {
                  if (selected) {
                    for (final item in _contacts) {
                      item.isPrimary = identical(item, contact);
                    }
                  } else {
                    contact.isPrimary = false;
                  }
                  _syncContacts();
                });
              },
              onDelete: () {
                setState(() {
                  _contacts.removeAt(index);
                  _syncContacts();
                });
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAddressSection() {
    return _FormSection(
      icon: FluentIcons.map_pin,
      title: txt('addressDetails'),
      children: [
        _FormField(
          key: WK.fieldPatientAddress,
          label: txt('address'),
          initialValue: patient.prototypeAddressLine,
          readOnly: widget.readOnly,
          fullWidth: true,
          onChanged: (value) {
            patient.addressLine = value;
            patient.address = value;
            patient.nullifyLabels();
          },
        ),
        _FormField(
          label: txt('area'),
          initialValue: patient.area,
          readOnly: widget.readOnly,
          onChanged: (value) {
            patient.area = value;
            patient.nullifyLabels();
          },
        ),
        _FormField(
          label: txt('city'),
          initialValue: patient.city,
          readOnly: widget.readOnly,
          onChanged: (value) {
            patient.city = value;
            patient.nullifyLabels();
          },
        ),
        _FormField(
          label: txt('postalCode'),
          initialValue: patient.postalCode,
          readOnly: widget.readOnly,
          keyboardType: TextInputType.streetAddress,
          onChanged: (value) {
            patient.postalCode = value;
            patient.nullifyLabels();
          },
        ),
        _FormField(
          label: txt('country'),
          initialValue: patient.countryCode,
          readOnly: widget.readOnly,
          onChanged: (value) => patient.countryCode = value,
        ),
      ],
    );
  }

  Widget _buildAdministrationSection() {
    return _FormSection(
      icon: FluentIcons.shield,
      title: txt('administrativeDetails'),
      children: [
        _FormField.custom(
          label: txt('registrationDate'),
          child: _DateField(
            value: patient.registrationDate,
            readOnly: widget.readOnly,
            onChanged: (value) =>
                setState(() => patient.registrationDate = value),
          ),
        ),
        _FormField.custom(
          label: txt('status'),
          child: widget.readOnly
              ? _ReadOnlyValue(
                  value: _translatedValue(patient.prototypeActiveStatus))
              : ComboBox<String>(
                  isExpanded: true,
                  value: patient.prototypeActiveStatus,
                  items: [
                    ComboBoxItem(value: 'active', child: Text(txt('active'))),
                    ComboBoxItem(
                        value: 'inactive', child: Text(txt('inactive'))),
                    ComboBoxItem(
                        value: 'archived', child: Text(txt('archived'))),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      patient.activeStatus = value;
                      patient.archived = value == 'archived';
                      patient.nullifyLabels();
                    });
                  },
                ),
        ),
        _FormField(
          label: 'AMKA',
          initialValue: patient.amka,
          readOnly: widget.readOnly,
          keyboardType: TextInputType.number,
          onChanged: (value) {
            patient.amka = value;
            patient.nullifyLabels();
          },
        ),
        _FormField(
          label: 'AFM',
          initialValue: patient.afm,
          readOnly: widget.readOnly,
          keyboardType: TextInputType.number,
          onChanged: (value) {
            patient.afm = value;
            patient.nullifyLabels();
          },
        ),
        _FormField(
          label: 'DOY',
          initialValue: patient.doy,
          readOnly: widget.readOnly,
          onChanged: (value) => patient.doy = value,
        ),
        _FormField(
          label: txt('identityCardNumber'),
          initialValue: patient.identityCardNumber,
          readOnly: widget.readOnly,
          onChanged: (value) => patient.identityCardNumber = value,
        ),
        _FormField(
          label: txt('identityIssueDetails'),
          initialValue: patient.identityIssueDetails,
          readOnly: widget.readOnly,
          onChanged: (value) => patient.identityIssueDetails = value,
        ),
        _FormField(
          label: txt('insurance'),
          initialValue: patient.insurance,
          readOnly: widget.readOnly,
          onChanged: (value) => patient.insurance = value,
        ),
        _FormField(
          label: txt('patientCategory'),
          initialValue: patient.patientCategory,
          readOnly: widget.readOnly,
          onChanged: (value) => patient.patientCategory = value,
        ),
        _FormField(
          label: txt('financialCategory'),
          initialValue: patient.financialCategory,
          readOnly: widget.readOnly,
          onChanged: (value) => patient.financialCategory = value,
        ),
        _FormField(
          label: txt('salutation1'),
          initialValue: patient.salutation1,
          readOnly: widget.readOnly,
          onChanged: (value) => patient.salutation1 = value,
        ),
        _FormField(
          label: txt('salutation2'),
          initialValue: patient.salutation2,
          readOnly: widget.readOnly,
          onChanged: (value) => patient.salutation2 = value,
        ),
        _FormField(
          label: txt('referralSource'),
          initialValue: patient.referralSource,
          readOnly: widget.readOnly,
          onChanged: (value) => patient.referralSource = value,
        ),
        _FormField(
          label: txt('legacyFolderNumber'),
          initialValue: patient.legacyFolderNumber,
          readOnly: widget.readOnly,
          onChanged: (value) {
            patient.legacyFolderNumber = value;
            patient.nullifyLabels();
          },
        ),
        _FormField(
          key: WK.fieldPatientNotes,
          label: txt('notes'),
          initialValue: patient.prototypeAdministrativeNotes,
          readOnly: widget.readOnly,
          fullWidth: true,
          maxLines: 4,
          onChanged: (value) {
            patient.administrativeNotes = value;
            patient.notes = value;
          },
        ),
      ],
    );
  }

  void _addContact() {
    setState(() {
      _contacts.add(PatientContact.fromJson({
        'type': PatientContactType.mobile,
        'is_primary': _contacts.isEmpty,
      }));
      _syncContacts();
    });
  }

  void _syncContacts() {
    patient.contacts = _contacts
        .where((contact) => contact.rawValue.trim().isNotEmpty)
        .map((contact) {
      contact.normalizedValue = _normalizedContactValue(contact);
      return contact.copy();
    }).toList();

    final telephoneValues = patient.contacts
        .where((contact) => PatientContactType.isTelephone(contact.type))
        .map((contact) => contact.rawValue)
        .join(' ');
    patient.phone = PhoneNumberExtractor.extract(telephoneValues)
        .map((number) => ParsedPhoneNumber(number))
        .toList();
    patient.email = patient.contacts
            .where((contact) => contact.type == PatientContactType.email)
            .map((contact) => contact.rawValue.trim())
            .firstOrNull ??
        '';
    patient.nullifyLabels();
  }

  String _normalizedContactValue(PatientContact contact) {
    final value = contact.rawValue.trim();
    if (contact.type == PatientContactType.email) return value.toLowerCase();
    if (!PatientContactType.isTelephone(contact.type)) return value;
    final hasLeadingPlus = value.startsWith('+');
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    return '${hasLeadingPlus ? '+' : ''}$digits';
  }

  void _syncDisplayName() {
    final structured = [patient.surname.trim(), patient.firstName.trim()]
        .where((part) => part.isNotEmpty)
        .join(' ');
    if (structured.isNotEmpty) {
      patient.title = structured;
    } else if (patient.legacyFullName.trim().isNotEmpty) {
      patient.title = patient.legacyFullName.trim();
    }
    patient.nullifyLabels();
  }

  String _contactTypeLabel(String type) {
    return switch (type) {
      PatientContactType.homePhone => txt('homePhone'),
      PatientContactType.workPhone => txt('workPhone'),
      PatientContactType.mobile => txt('mobilePhone'),
      PatientContactType.phone => txt('phone'),
      PatientContactType.email => txt('email'),
      _ => txt('other'),
    };
  }

  String _translatedValue(String value) {
    if (value.isEmpty || value == 'unknown') return txt('unknown');
    const translatedValues = {
      'male',
      'female',
      'active',
      'inactive',
      'archived'
    };
    return translatedValues.contains(value) ? txt(value) : value;
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.icon,
    required this.title,
    required this.children,
    this.footer,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.resources.cardBackgroundFillColorDefault,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.resources.dividerStrokeColorDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: theme.typography.subtitle),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final width =
                  constraints.hasBoundedWidth ? constraints.maxWidth : 480.0;
              final itemWidth = width < 680 ? width : (width - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: children.map((child) {
                  final fullWidth = child is _FormField && child.fullWidth;
                  return SizedBox(
                    width: fullWidth ? width : itemWidth,
                    child: child,
                  );
                }).toList(),
              );
            },
          ),
          if (footer != null) ...[
            const SizedBox(height: 12),
            footer!,
          ],
        ],
      ),
    );
  }
}

class _FormField extends StatefulWidget {
  const _FormField({
    super.key,
    required this.label,
    this.initialValue = '',
    this.readOnlyValue,
    this.readOnly = false,
    this.onChanged,
    this.keyboardType,
    this.maxLines = 1,
    this.fullWidth = false,
  }) : child = null;

  const _FormField.custom({
    super.key,
    required this.label,
    required this.child,
    this.fullWidth = false,
  })  : initialValue = '',
        readOnlyValue = null,
        readOnly = false,
        onChanged = null,
        keyboardType = null,
        maxLines = 1;

  final String label;
  final String initialValue;
  final String? readOnlyValue;
  final bool readOnly;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool fullWidth;
  final Widget? child;

  @override
  State<_FormField> createState() => _FormFieldState();
}

class _FormFieldState extends State<_FormField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _FormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        _controller.text != widget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child ??
        (widget.readOnly || widget.readOnlyValue != null
            ? _ReadOnlyValue(
                value: widget.readOnlyValue ?? widget.initialValue,
              )
            : TextBox(
                controller: _controller,
                keyboardType: widget.keyboardType,
                maxLines: widget.maxLines,
                onChanged: widget.onChanged,
              ));
    return InfoLabel(label: widget.label, child: child);
  }
}

class _ReadOnlyValue extends StatelessWidget {
  const _ReadOnlyValue({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 32),
      alignment: AlignmentDirectional.centerStart,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.resources.subtleFillColorSecondary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: SelectableText(value.trim().isEmpty ? txt('notSet') : value),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.value,
    required this.readOnly,
    required this.onChanged,
  });

  final DateTime? value;
  final bool readOnly;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (readOnly) {
      return _ReadOnlyValue(value: value == null ? '' : _formatDate(value!));
    }
    return Row(
      children: [
        Expanded(
          child: Button(
            onPressed: () => _pickDate(context),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(value == null ? txt('notSet') : _formatDate(value!)),
            ),
          ),
        ),
        if (value != null) ...[
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(FluentIcons.clear, size: 14),
            onPressed: () => onChanged(null),
          ),
        ],
      ],
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (selected != null) onChanged(selected);
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}

class _ContactEditor extends StatelessWidget {
  const _ContactEditor({
    required this.index,
    required this.contact,
    required this.readOnly,
    required this.onChanged,
    required this.onPrimaryChanged,
    required this.onDelete,
  });

  final int index;
  final PatientContact contact;
  final bool readOnly;
  final VoidCallback onChanged;
  final ValueChanged<bool> onPrimaryChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    if (readOnly) {
      final suffixes = [
        if (contact.isPrimary) txt('primaryContact'),
        if (contact.smsAllowed == true) txt('smsAllowed'),
      ];
      return _ReadOnlyValue(
        value: [
          contact.rawValue,
          if (suffixes.isNotEmpty) '(${suffixes.join(', ')})',
        ].join(' '),
      );
    }

    final types = <String>{
      PatientContactType.homePhone,
      PatientContactType.workPhone,
      PatientContactType.mobile,
      PatientContactType.phone,
      PatientContactType.email,
      PatientContactType.other,
      contact.type,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 560;
        final typePicker = ComboBox<String>(
          key: ValueKey('patient_contact_type_$index'),
          isExpanded: true,
          value: contact.type,
          items: types
              .map((type) => ComboBoxItem(
                    value: type,
                    child: Text(_contactTypeLabel(type)),
                  ))
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            contact.type = value;
            onChanged();
          },
        );
        final valueField = _FormField(
          key: ValueKey('patient_contact_value_$index'),
          label: txt('contact'),
          initialValue: contact.rawValue,
          keyboardType: contact.type == PatientContactType.email
              ? TextInputType.emailAddress
              : PatientContactType.isTelephone(contact.type)
                  ? TextInputType.phone
                  : TextInputType.text,
          onChanged: (value) {
            contact.rawValue = value;
            onChanged();
          },
        );
        final options = Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Checkbox(
              checked: contact.isPrimary,
              onChanged: (value) => onPrimaryChanged(value == true),
              content: Text(txt('primaryContact')),
            ),
            if (PatientContactType.isTelephone(contact.type))
              Checkbox(
                checked: contact.smsAllowed == true,
                onChanged: (value) {
                  contact.smsAllowed = value == true;
                  onChanged();
                },
                content: Text(txt('smsAllowed')),
              ),
            IconButton(
              key: ValueKey('delete_patient_contact_$index'),
              icon: const Icon(FluentIcons.delete, size: 15),
              onPressed: onDelete,
            ),
          ],
        );

        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: FluentTheme.of(context).resources.subtleFillColorSecondary,
            borderRadius: BorderRadius.circular(6),
          ),
          child: narrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    typePicker,
                    const SizedBox(height: 8),
                    valueField,
                    const SizedBox(height: 8),
                    options,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SizedBox(width: 190, child: typePicker),
                        const SizedBox(width: 10),
                        Expanded(child: valueField),
                      ],
                    ),
                    const SizedBox(height: 8),
                    options,
                  ],
                ),
        );
      },
    );
  }

  String _contactTypeLabel(String type) {
    return switch (type) {
      PatientContactType.homePhone => txt('homePhone'),
      PatientContactType.workPhone => txt('workPhone'),
      PatientContactType.mobile => txt('mobilePhone'),
      PatientContactType.phone => txt('phone'),
      PatientContactType.email => txt('email'),
      _ => txt('other'),
    };
  }
}
