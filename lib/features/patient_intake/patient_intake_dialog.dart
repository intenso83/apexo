import 'package:apexo/common_widgets/patient_picker.dart';
import 'package:apexo/features/medical_history/medical_history_questionnaire.dart';
import 'package:apexo/features/medical_history/medical_history_store.dart';
import 'package:apexo/features/patient_intake/patient_intake_mapper.dart';
import 'package:apexo/features/patient_intake/patient_intake_service.dart';
import 'package:apexo/features/patient_intake/patient_intake_submission.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

Future<void> showPatientIntakeDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PatientIntakeDialog(),
  );
}

class PatientIntakeDialog extends StatefulWidget {
  const PatientIntakeDialog({super.key});

  @override
  State<PatientIntakeDialog> createState() => _PatientIntakeDialogState();
}

class _PatientIntakeDialogState extends State<PatientIntakeDialog> {
  final _service = const PatientIntakeService();
  List<PatientIntakeSubmission> _pending = const [];
  PatientIntakeSession? _session;
  bool _loading = true;
  bool _creatingSession = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.pendingSubmissions();
      if (!mounted) return;
      setState(() => _pending = result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createSession() async {
    setState(() {
      _creatingSession = true;
      _error = null;
    });
    try {
      final session =
          await _service.createSession(deviceLabel: 'practice tablet');
      await Clipboard.setData(ClipboardData(text: session.id));
      if (!mounted) return;
      setState(() => _session = session);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _creatingSession = false);
    }
  }

  Future<void> _review(PatientIntakeSubmission submission) async {
    final imported = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ImportSubmissionDialog(
        submission: submission,
        service: _service,
      ),
    );
    if (imported == true) await _reload();
  }

  Future<void> _reject(PatientIntakeSubmission submission) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: const Text('Reject intake submission?'),
        content: Text(
          '${submission.displayName}\n\nThis removes it from the pending review list. It does not change any Apexo patient.',
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.reject(submission.id);
      await _reload();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('Patient intake / Φόρμες ασθενών'),
      constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
      content: SizedBox(
        width: 920,
        height: 650,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                FilledButton(
                  onPressed: _creatingSession ? null : _createSession,
                  child: Text(
                    _creatingSession ? 'Creating…' : 'Prepare tablet session',
                  ),
                ),
                const SizedBox(width: 10),
                Button(
                  onPressed: _loading ? null : _reload,
                  child: const Text('Refresh submissions'),
                ),
                const Spacer(),
                Text('${_pending.length} pending'),
              ],
            ),
            if (_session != null) ...[
              const SizedBox(height: 12),
              InfoBar(
                severity: InfoBarSeverity.success,
                title: const Text('One-time session copied'),
                content: SelectableText(
                  '${_session!.id}\nEnter this in the patient app. It expires in 30 minutes and can submit once.',
                ),
                action: Button(
                  onPressed: () => Clipboard.setData(
                    ClipboardData(text: _session!.id),
                  ),
                  child: const Text('Copy'),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              InfoBar(
                severity: InfoBarSeverity.error,
                title: const Text('Patient intake service error'),
                content: Text(_error!),
              ),
            ],
            const SizedBox(height: 14),
            Expanded(
              child: _loading
                  ? const Center(child: ProgressRing())
                  : _pending.isEmpty
                      ? const Center(
                          child: Text(
                            'No patient forms are waiting for review.',
                            style: TextStyle(fontSize: 18),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _pending.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final submission = _pending[index];
                            final matches = PatientIntakeMapper.likelyMatches(
                              submission,
                              patients.present.values,
                            );
                            return Card(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  const Icon(FluentIcons.contact, size: 28),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          submission.displayName,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          'Born ${submission.dateOfBirth} · ${submission.positiveAnswerCount} “yes” answers',
                                        ),
                                        if (matches.isNotEmpty)
                                          Text(
                                            'Possible existing patient: ${matches.first.prototypeDisplayName}',
                                            style: const TextStyle(
                                              color: Color(0xFF9A6700),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Button(
                                    onPressed: () => _reject(submission),
                                    child: const Text('Reject'),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton(
                                    onPressed: () => _review(submission),
                                    child: const Text('Review / import'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 10),
            const Text(
              'The tablet never receives this Apexo login or any patient list. Only this authenticated staff screen can review and import submissions.',
              style: TextStyle(color: Color(0xFF5C6670)),
            ),
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _ImportSubmissionDialog extends StatefulWidget {
  const _ImportSubmissionDialog({
    required this.submission,
    required this.service,
  });

  final PatientIntakeSubmission submission;
  final PatientIntakeService service;

  @override
  State<_ImportSubmissionDialog> createState() =>
      _ImportSubmissionDialogState();
}

class _ImportSubmissionDialogState extends State<_ImportSubmissionDialog> {
  late final List<Patient> _matches = PatientIntakeMapper.likelyMatches(
    widget.submission,
    patients.present.values,
  );
  bool _createNew = true;
  String? _selectedPatientId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final alreadyCreated = patients.present.values.where(
      (patient) =>
          patient.legacyCustomFields['intake_submission_id'] ==
          widget.submission.id,
    );
    if (alreadyCreated.isNotEmpty) {
      _createNew = false;
      _selectedPatientId = alreadyCreated.first.id;
    } else if (_matches.isNotEmpty) {
      _createNew = false;
    }
  }

  Future<void> _import() async {
    if (!_createNew && _selectedPatientId == null) {
      setState(() => _error =
          'Select the existing patient, or choose “Create new patient”.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      late Patient patient;
      if (_createNew) {
        patient = PatientIntakeMapper.newPatient(widget.submission);
      } else {
        patient = patients.get(_selectedPatientId!)!;
        PatientIntakeMapper.mergeMissingPersonalData(
          patient,
          widget.submission,
        );
      }
      patients.set(patient);

      final alreadyImported = medicalHistoryRevisions.present.values.any(
        (revision) =>
            revision.provenance['intake_submission_id'] == widget.submission.id,
      );
      if (!alreadyImported) {
        medicalHistoryRevisions.addRevision(
          PatientIntakeMapper.medicalHistory(widget.submission, patient.id),
        );
      }

      await patients.synchronize();
      await medicalHistoryRevisions.synchronize();
      if (!await patients.inSync() || !await medicalHistoryRevisions.inSync()) {
        throw StateError(
          'Apexo has not finished saving the patient and medical history. Retry while online.',
        );
      }
      await widget.service.markImported(
        submissionId: widget.submission.id,
        patientId: patient.id,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final personal = widget.submission.personal;
    final answers = Map<String, dynamic>.from(
      widget.submission.medicalHistory['answers'] as Map? ?? const {},
    );
    final positiveLabels = answers.entries.where((entry) {
      final answer = Map<String, dynamic>.from(entry.value as Map? ?? const {});
      return answer['value'] == 'yes';
    }).map((entry) {
      final question =
          PracticeMedicalHistoryQuestionnaire.questionsByID[entry.key];
      final answer = Map<String, dynamic>.from(entry.value as Map? ?? const {});
      final notes = answer['notes']?.toString().trim() ?? '';
      return '${question?.label(widget.submission.packet['language_code']?.toString()) ?? entry.key}'
          '${notes.isEmpty ? '' : ': $notes'}';
    }).toList();

    return ContentDialog(
      title: Text('Review ${widget.submission.displayName}'),
      constraints: const BoxConstraints(maxWidth: 900, maxHeight: 780),
      content: SizedBox(
        width: 840,
        height: 650,
        child: ListView(
          children: [
            Wrap(
              spacing: 22,
              runSpacing: 10,
              children: personal.entries
                  .where((entry) => entry.value.toString().trim().isNotEmpty)
                  .map((entry) => SizedBox(
                        width: 250,
                        child: Text('${entry.key}: ${entry.value}'),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 18),
            Text(
              'Medical answers marked “yes” (${positiveLabels.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (positiveLabels.isEmpty)
              const Text('None')
            else
              ...positiveLabels.map((label) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text('• $label'),
                  )),
            const SizedBox(height: 20),
            ToggleSwitch(
              checked: _createNew,
              onChanged: (value) => setState(() {
                _createNew = value;
                _error = null;
              }),
              content: const Text('Create new patient'),
            ),
            if (!_createNew) ...[
              const SizedBox(height: 12),
              if (_matches.isNotEmpty)
                InfoBar(
                  severity: InfoBarSeverity.warning,
                  title: const Text('Possible matches'),
                  content: Text(
                    _matches
                        .map((patient) => patient.prototypeDisplayName)
                        .join(', '),
                  ),
                ),
              const SizedBox(height: 12),
              PatientPicker(
                value: _selectedPatientId,
                onChanged: (id) => setState(() {
                  _selectedPatientId = id;
                  _error = null;
                }),
              ),
              const SizedBox(height: 8),
              const Text(
                'Only empty personal fields will be filled. Existing Apexo values are never overwritten. A new medical-history revision will be added.',
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              InfoBar(
                severity: InfoBarSeverity.error,
                title: const Text('Import not completed'),
                content: Text(_error!),
              ),
            ],
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _import,
          child: Text(_saving ? 'Saving…' : 'Import into Apexo'),
        ),
      ],
    );
  }
}
