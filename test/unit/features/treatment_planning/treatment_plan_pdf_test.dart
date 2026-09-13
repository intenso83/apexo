import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/treatment_planning/treatment_plan_model.dart';
import 'package:apexo/features/treatment_planning/treatment_plan_pdf.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('creates a branded A4 treatment-plan PDF', () async {
    final plan = TreatmentPlan.fromJson({
      'patientID': 'patient1234567',
      'title': 'Alternative A',
      'language': 'el',
      'consentTextEl': 'Έχω ενημερωθεί για το σχέδιο θεραπείας.',
      'wholeDiscountPercent': 10,
      'items': [
        {
          'procedureID': 'procedure123456',
          'procedureNameElSnapshot': 'Στεφάνη ζιρκονίας',
          'procedureNameEnSnapshot': 'Zirconia crown',
          'procedureNameDeSnapshot': 'Zirkonkrone',
          'unitPrice': 500,
          'quantity': 1,
          'discountAmount': 20,
          'handlingMode': 'wholeTooth',
          'toothFdi': 16,
          'surfaces': ['wholeTooth'],
        },
      ],
    });
    final logo =
        (await rootBundle.load('assets/images/treatment_plan_logo.gif'))
            .buffer
            .asUint8List();
    final bytes = await buildTreatmentPlanPdf(
      plan: plan,
      patient: Patient.fromJson({'title': 'Δοκιμαστικός Ασθενής'}),
      branding: TreatmentPlanBrandingSnapshot(
        brandEl: 'Οδοντιατρείο Ευριπίδη Δημητρακόπουλου',
        brandEn: 'E. Dimitrakopoulos Dental Practice',
        brandDe: 'Zahnarztpraxis E. Dimitrakopoulos',
        logoBytes: logo,
      ),
      currencyCode: 'EUR',
    );

    expect(bytes.length, greaterThan(5000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('renders a priced custom treatment with a multiline description',
      () async {
    final plan = TreatmentPlan.fromJson({
      'patientID': 'patient1234567',
      'title': 'Custom treatment',
      'language': 'el',
      'items': [
        {
          'isCustom': true,
          'procedureNameElSnapshot': 'Εξατομικευμένη θεραπεία',
          'notes': 'Αναλυτική περιγραφή εργασίας\nΜε δεύτερη γραμμή',
          'handlingMode': 'patientLevel',
          'unitPrice': 75,
          'quantity': 2,
        },
      ],
    });
    final logo =
        (await rootBundle.load('assets/images/treatment_plan_logo.gif'))
            .buffer
            .asUint8List();
    final branding = TreatmentPlanBrandingSnapshot(
      brandEl: 'Ιατρείο',
      brandEn: 'Practice',
      brandDe: 'Praxis',
      logoBytes: logo,
    );
    final patient = Patient.fromJson({'title': 'Δοκιμαστικός Ασθενής'});

    final withDescription = await buildTreatmentPlanPdf(
      plan: plan,
      patient: patient,
      branding: branding,
      currencyCode: 'EUR',
    );
    plan.items.single.notes = '';
    final withoutDescription = await buildTreatmentPlanPdf(
      plan: plan,
      patient: patient,
      branding: branding,
      currencyCode: 'EUR',
    );

    expect(String.fromCharCodes(withDescription.take(4)), '%PDF');
    expect(withDescription.length, greaterThan(withoutDescription.length));
  });
}
