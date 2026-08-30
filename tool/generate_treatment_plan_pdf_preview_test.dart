import 'dart:io';
import 'dart:typed_data';

import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/treatment_planning/treatment_plan_model.dart';
import 'package:apexo/features/treatment_planning/treatment_plan_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('generate visually inspectable treatment-plan sample', () async {
    final plan = TreatmentPlan.fromJson({
      'patientID': 'preview-patient',
      'title': 'Εναλλακτική Α',
      'language': 'el',
      'consentStatus': 'verbalAgreement',
      'consentTextEl':
          'Έχω ενημερωθεί για το προτεινόμενο σχέδιο θεραπείας, τις εναλλακτικές λύσεις και την οικονομική εκτίμηση.',
      'wholeDiscountPercent': 5,
      'wholeDiscountAmount': 40,
      'items': [
        {
          'procedureID': 'preview-root-canal',
          'procedureNameElSnapshot': 'Ενδοδοντική θεραπεία γομφίου',
          'procedureNameEnSnapshot': 'Molar root canal treatment',
          'procedureNameDeSnapshot': 'Wurzelkanalbehandlung eines Molaren',
          'unitPrice': 280,
          'quantity': 1,
          'handlingMode': 'wholeTooth',
          'toothFdi': 16,
          'surfaces': ['wholeTooth'],
        },
        {
          'procedureID': 'preview-crown',
          'procedureNameElSnapshot': 'Στεφάνη ζιρκονίας',
          'procedureNameEnSnapshot': 'Zirconia crown',
          'procedureNameDeSnapshot': 'Zirkonkrone',
          'unitPrice': 520,
          'quantity': 1,
          'discountPercent': 10,
          'handlingMode': 'wholeTooth',
          'toothFdi': 16,
          'surfaces': ['wholeTooth'],
        },
        {
          'procedureID': 'preview-cleaning',
          'procedureNameElSnapshot': 'Καθαρισμός και στίλβωση',
          'procedureNameEnSnapshot': 'Scaling and polishing',
          'procedureNameDeSnapshot': 'Zahnreinigung und Politur',
          'unitPrice': 80,
          'quantity': 1,
          'discountAmount': 10,
          'handlingMode': 'patientLevel',
        },
      ],
    });
    final patient = Patient.fromJson({
      'id': 'preview-patient',
      'title': 'Δοκιμαστικός Ασθενής',
    });
    final regular = await File('assets/fonts/DejaVuSans.ttf').readAsBytes();
    final bold = regular;
    final logo =
        await File('assets/images/treatment_plan_logo.gif').readAsBytes();
    final pdf = await buildTreatmentPlanPdf(
      plan: plan,
      patient: patient,
      branding: TreatmentPlanBrandingSnapshot(
        brandEl: 'Οδοντιατρείο Ευριπίδη Δημητρακόπουλου',
        brandEn: 'E. Dimitrakopoulos Dental Practice',
        brandDe: 'Zahnarztpraxis E. Dimitrakopoulos',
        logoBytes: Uint8List.fromList(logo),
      ),
      currencyCode: 'EUR',
      regularFontData: ByteData.sublistView(Uint8List.fromList(regular)),
      boldFontData: ByteData.sublistView(Uint8List.fromList(bold)),
    );
    final output = File('output/pdf/treatment_plan_sample_el.pdf');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(pdf, flush: true);
    stdout.writeln(output.absolute.path);
    expect(await output.exists(), isTrue);
    expect(await output.length(), greaterThan(1000));
  });
}
