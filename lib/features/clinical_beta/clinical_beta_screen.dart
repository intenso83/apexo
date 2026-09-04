import 'package:apexo/app/routes.dart';
import 'package:apexo/features/patients/open_patient_panel.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:fluent_ui/fluent_ui.dart';

/// A small, Demo-only landing page that makes the clinical beta discoverable.
///
/// Apexo keeps its original appointment tooth wheel for quick historic notes.
/// The richer odontogram, periodontal chart, and treatment planner are patient
/// workspaces, so a colleague evaluating the beta should be taken there first.
class ClinicalBetaScreen extends StatelessWidget {
  const ClinicalBetaScreen({super.key});

  static const odontogramTabIndex = 3;
  static const periodontalTabIndex = 4;
  static const treatmentPlanningTabIndex = 9;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: patients.observableMap.stream,
      builder: (context, _) {
        final visiblePatients = patients.present.values;
        final Patient? patient =
            visiblePatients.isEmpty ? null : visiblePatients.first;
        return ListView(
          key: const ValueKey('clinical-beta-home'),
          padding: const EdgeInsets.all(24),
          children: [
            _Hero(patient: patient),
            const SizedBox(height: 22),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _FeatureCard(
                  key: const ValueKey('clinical-beta-odontogram'),
                  icon: FluentIcons.teeth,
                  color: Colors.blue,
                  title: txt('odontogramFoundation'),
                  description: txt('odontogramFoundationDescription'),
                  enabled: patient != null,
                  onOpen: () => openPatient(patient, odontogramTabIndex),
                ),
                _FeatureCard(
                  key: const ValueKey('clinical-beta-periodontal'),
                  icon: FluentIcons.health,
                  color: Colors.teal,
                  title: txt('periodontalChart'),
                  description: txt('periodontalChartHistoryDescription'),
                  enabled: patient != null,
                  onOpen: () => openPatient(patient, periodontalTabIndex),
                ),
                _FeatureCard(
                  key: const ValueKey('clinical-beta-treatment-planning'),
                  icon: FluentIcons.medical,
                  color: Colors.purple,
                  title: txt('treatmentPlanning'),
                  description: txt('clinicalBetaTreatmentPlanningDescription'),
                  enabled: patient != null,
                  onOpen: () => openPatient(patient, treatmentPlanningTabIndex),
                ),
                _FeatureCard(
                  key: const ValueKey('clinical-beta-catalogue'),
                  icon: FluentIcons.product_catalog,
                  color: Colors.orange,
                  title: txt('therapyCatalogue'),
                  description: txt('therapyCatalogueDescription'),
                  onOpen: () => routes.navigate('therapyCatalogue'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.patient});

  final Patient? patient;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.accentColor.darkest,
            theme.accentColor.normal,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 74,
            height: 74,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Image.asset('assets/images/logo.png'),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txt('clinicalBeta'),
                  style: theme.typography.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  txt('clinicalBetaWelcome'),
                  style: theme.typography.body?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  txt('clinicalBetaLegacyChartHint'),
                  style: theme.typography.caption?.copyWith(
                    color: Colors.white.withValues(alpha: 0.84),
                  ),
                ),
                if (patient != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    '${txt('demoMode')}: ${patient!.title}',
                    style: theme.typography.bodyStrong?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.onOpen,
    this.enabled = true,
  });

  final IconData icon;
  final AccentColor color;
  final String title;
  final String description;
  final VoidCallback onOpen;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Container(
      width: 340,
      constraints: const BoxConstraints(minHeight: 190),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.resources.cardBackgroundFillColorDefault,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(title, style: theme.typography.subtitle),
          const SizedBox(height: 7),
          Text(
            description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.caption,
          ),
          const SizedBox(height: 16),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(
              onPressed: enabled ? onOpen : null,
              child: Text(txt('open')),
            ),
          ),
        ],
      ),
    );
  }
}
