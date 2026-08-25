import 'package:apexo/features/patients/patient_contact.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/settings/settings_stores.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:fluent_ui/fluent_ui.dart';

class PatientFieldsPrototype extends StatelessWidget {
  const PatientFieldsPrototype({super.key, required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoBar(
            title: Text(txt('patientFieldsPrototype')),
            content: Text(txt('patientFieldsPrototypeDescription')),
            severity: InfoBarSeverity.info,
          ),
          const SizedBox(height: 12),
          _section(
            context,
            txt('identityAndDemographics'),
            [
              _FieldValue(
                txt('registrationNumber'),
                patient.registrationNumber.isEmpty
                    ? txt('assignedAfterAcceptance')
                    : patient.registrationNumber,
              ),
              _FieldValue(txt('surname'), patient.surname),
              _FieldValue(txt('firstName'), patient.firstName),
              _FieldValue(
                txt('legacyFullName'),
                patient.legacyFullName.isEmpty
                    ? patient.title
                    : patient.legacyFullName,
              ),
              _FieldValue(txt('fatherName'), patient.patronymic),
              _FieldValue(txt('motherName'), patient.motherName),
              _FieldValue(
                txt('birthDate'),
                patient.birthDate == null
                    ? ''
                    : DF.allNumbers(patient.birthDate!),
              ),
              _FieldValue(
                txt('approximateBirthYear'),
                patient.birthDate == null
                    ? patient.prototypeBirthYear?.toString() ?? ''
                    : '',
              ),
              _FieldValue(
                txt('gender'),
                _translatedValue(patient.prototypeSexOrGender),
              ),
              _FieldValue(txt('occupation'), patient.occupation),
              _FieldValue(
                txt('secondaryOccupation'),
                patient.secondaryOccupationLabel,
              ),
              _FieldValue(
                txt('placeOfOrigin'),
                patient.placeOfOriginOrBirth,
              ),
              _FieldValue(
                txt('registrationDate'),
                patient.registrationDate == null
                    ? ''
                    : DF.allNumbers(patient.registrationDate!),
              ),
              _FieldValue(
                txt('status'),
                _translatedValue(patient.prototypeActiveStatus),
              ),
            ],
          ),
          _section(
            context,
            txt('contactDetails'),
            _contactFields(patient.prototypeContacts),
          ),
          _section(
            context,
            txt('addressDetails'),
            [
              _FieldValue(txt('address'), patient.prototypeAddressLine),
              _FieldValue(txt('area'), patient.area),
              _FieldValue(txt('city'), patient.city),
              _FieldValue(txt('postalCode'), patient.postalCode),
              _FieldValue(txt('country'), patient.countryCode),
            ],
          ),
          _section(
            context,
            txt('administrativeDetails'),
            [
              _FieldValue('AMKA', patient.amka),
              _FieldValue('AFM', patient.afm),
              _FieldValue('DOY', patient.doy),
              _FieldValue(
                txt('identityCardNumber'),
                patient.identityCardNumber,
              ),
              _FieldValue(
                txt('identityIssueDetails'),
                patient.identityIssueDetails,
              ),
              _FieldValue(txt('insurance'), patient.insurance),
              _FieldValue(txt('patientCategory'), patient.patientCategory),
              _FieldValue(
                txt('financialCategory'),
                patient.financialCategory,
              ),
              _FieldValue(txt('salutation1'), patient.salutation1),
              _FieldValue(txt('salutation2'), patient.salutation2),
              _FieldValue(txt('referralSource'), patient.referralSource),
              _FieldValue(
                txt('legacyFolderNumber'),
                patient.legacyFolderNumber,
              ),
              _FieldValue(
                txt('notes'),
                patient.prototypeAdministrativeNotes,
              ),
            ],
          ),
          if (patient.legacyCustomFields.isNotEmpty)
            _section(
              context,
              txt('legacyFields'),
              patient.legacyCustomFields.entries
                  .map((entry) => _FieldValue(entry.key, entry.value))
                  .toList(),
            ),
        ],
      ),
    );
  }

  List<_FieldValue> _contactFields(List<PatientContact> contacts) {
    if (contacts.isEmpty) return [_FieldValue(txt('contact'), '')];
    return contacts.map((contact) {
      final suffixes = [
        if (contact.isPrimary) txt('primaryContact'),
        if (contact.smsAllowed == true) txt('smsAllowed'),
        if (contact.label.isNotEmpty) contact.label,
      ];
      final label = [
        _contactTypeLabel(contact.type),
        if (suffixes.isNotEmpty) '(${suffixes.join(', ')})',
      ].join(' ');
      return _FieldValue(label, contact.rawValue);
    }).toList();
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
    const translatedValues = {'male', 'female', 'active', 'archived'};
    return translatedValues.contains(value) ? txt(value) : value;
  }

  Widget _section(
    BuildContext context,
    String title,
    List<_FieldValue> fields,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FluentTheme.of(context).cardColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: FluentTheme.of(context).typography.subtitle,
          ),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, constraints) {
            final availableWidth =
                constraints.hasBoundedWidth ? constraints.maxWidth : 480.0;
            final itemWidth = availableWidth < 520
                ? availableWidth
                : (availableWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 10,
              children: fields
                  .map((field) => SizedBox(
                        width: itemWidth,
                        child: _ReadOnlyField(field: field),
                      ))
                  .toList(),
            );
          }),
        ],
      ),
    );
  }
}

class _FieldValue {
  const _FieldValue(this.label, this.value);

  final String label;
  final String value;
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.field});

  final _FieldValue field;

  @override
  Widget build(BuildContext context) {
    final value = field.value.trim().isEmpty ? txt('notSet') : field.value;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: FluentTheme.of(context).resources.subtleFillColorSecondary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            field.label,
            style: FluentTheme.of(context)
                .typography
                .caption
                ?.copyWith(color: Colors.grey[120]),
          ),
          const SizedBox(height: 3),
          SelectableText(value),
        ],
      ),
    );
  }
}
