import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/features/patients/open_patient_panel.dart';
import 'package:apexo/common_widgets/tag_input.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';

class PatientPicker extends StatelessWidget {
  final void Function(String? id) onChanged;
  final String? value;
  final bool enabled;
  const PatientPicker({
    super.key,
    required this.onChanged,
    required this.value,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TagInputWidget(
      key: WK.fieldPatient,
      onItemTap: (tag) {
        Patient? tapped = patients.get(tag.value ?? "");
        openPatient(tapped);
      },
      suggestions: patients.present.values.map((patient) {
        final displayName = patient.prototypeDisplayName.trim().isEmpty
            ? patient.title
            : patient.prototypeDisplayName;
        return TagInputItem(
          value: patient.id,
          label: displayName,
          searchText: patient.appointmentSearchText,
        );
      }).toList(),
      onChanged: (s) {
        if (s.isEmpty) return onChanged(null);
        onChanged(s.first.value ?? "");
      },
      enabled: enabled,
      initialValue: value != null
          ? [
              TagInputItem(
                value: value!,
                label: patients.get(value!)?.prototypeDisplayName ??
                    patients.get(value!)?.title ??
                    txt("notSet"),
              )
            ]
          : [],
      strict: true,
      limit: 1,
      placeholder: txt("selectPatient"),
    );
  }
}
