import 'dart:convert';
import 'dart:typed_data';

import 'package:apexo/features/settings/settings_model.dart';
import 'package:apexo/features/settings/settings_stores.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:fluent_ui/fluent_ui.dart';

Future<void> showTreatmentPlanBrandingSettings(BuildContext context) async {
  final brandEl =
      TextEditingController(text: globalSettings.treatmentPlanBrandEl);
  final brandEn =
      TextEditingController(text: globalSettings.treatmentPlanBrandEn);
  final brandDe =
      TextEditingController(text: globalSettings.treatmentPlanBrandDe);
  final consentEl =
      TextEditingController(text: globalSettings.treatmentPlanConsentEl);
  final consentEn =
      TextEditingController(text: globalSettings.treatmentPlanConsentEn);
  final consentDe =
      TextEditingController(text: globalSettings.treatmentPlanConsentDe);
  Uint8List? selectedLogo;
  var selectedLogoName = globalSettings.treatmentPlanLogoName;

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => ContentDialog(
          title: const Text('Ρυθμίσεις σχεδίου θεραπείας'),
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const InfoBar(
                  title: Text('Επωνυμία και λογότυπο'),
                  content: Text(
                    'Οι ρυθμίσεις χρησιμοποιούνται στα ελληνικά, αγγλικά και γερμανικά PDF.',
                  ),
                ),
                const SizedBox(height: 14),
                _field('Επωνυμία - Ελληνικά', brandEl),
                _field('Brand name - English', brandEn),
                _field('Praxisname - Deutsch', brandDe),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 74,
                      height: 74,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.withAlpha(80)),
                      ),
                      child: selectedLogo != null
                          ? Image.memory(selectedLogo!, fit: BoxFit.contain)
                          : globalSettings.treatmentPlanLogoBase64.isNotEmpty
                              ? Image.memory(
                                  base64Decode(
                                    globalSettings.treatmentPlanLogoBase64,
                                  ),
                                  fit: BoxFit.contain,
                                )
                              : Image.asset(
                                  'assets/images/treatment_plan_logo.gif',
                                  fit: BoxFit.contain,
                                ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedLogoName,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              Button(
                                child: const Text('Επιλογή λογοτύπου'),
                                onPressed: () async {
                                  final result =
                                      await file_picker.FilePicker.pickFiles(
                                    type: file_picker.FileType.image,
                                    withData: true,
                                  );
                                  final file =
                                      result == null || result.files.isEmpty
                                          ? null
                                          : result.files.first;
                                  if (file?.bytes == null) return;
                                  setDialogState(() {
                                    selectedLogo = file!.bytes;
                                    selectedLogoName = file.name;
                                  });
                                },
                              ),
                              Button(
                                child: const Text('Επαναφορά αρχικού'),
                                onPressed: () => setDialogState(() {
                                  selectedLogo = Uint8List(0);
                                  selectedLogoName = 'treatment_plan_logo.gif';
                                }),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  'Προεπιλεγμένο σύντομο κείμενο συναίνεσης',
                  style: FluentTheme.of(context).typography.subtitle,
                ),
                const SizedBox(height: 10),
                _field('Ελληνικά', consentEl, multiline: true),
                _field('English', consentEn, multiline: true),
                _field('Deutsch', consentDe, multiline: true),
              ],
            ),
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Ακύρωση'),
            ),
            FilledButton(
              onPressed: () {
                final values = <String, String>{
                  'txplan_brand_el': brandEl.text.trim(),
                  'txplan_brand_en': brandEn.text.trim(),
                  'txplan_brand_de': brandDe.text.trim(),
                  'txplan_cnsnt_el': consentEl.text.trim(),
                  'txplan_cnsnt_en': consentEn.text.trim(),
                  'txplan_cnsnt_de': consentDe.text.trim(),
                  'txplan_logo_nm_': selectedLogoName,
                };
                if (selectedLogo != null) {
                  values['txplan_logo_b64'] =
                      selectedLogo!.isEmpty ? '' : base64Encode(selectedLogo!);
                }
                for (final entry in values.entries) {
                  globalSettings.set(Setting.fromJson({
                    'id': entry.key,
                    'value': entry.value,
                  }));
                }
                Navigator.pop(dialogContext);
              },
              child: const Text('Αποθήκευση'),
            ),
          ],
        ),
      ),
    );
  } finally {
    brandEl.dispose();
    brandEn.dispose();
    brandDe.dispose();
    consentEl.dispose();
    consentEn.dispose();
    consentDe.dispose();
  }
}

Widget _field(
  String label,
  TextEditingController controller, {
  bool multiline = false,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: InfoLabel(
      label: label,
      child: TextBox(
        controller: controller,
        minLines: multiline ? 2 : 1,
        maxLines: multiline ? 4 : 1,
      ),
    ),
  );
}
