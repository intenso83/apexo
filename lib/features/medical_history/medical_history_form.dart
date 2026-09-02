import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';

import 'medical_history_model.dart';
import 'medical_history_questionnaire.dart';
import 'medical_history_store.dart';

class PatientMedicalHistory extends StatefulWidget {
  const PatientMedicalHistory({
    super.key,
    required this.patientID,
    this.revisions,
    this.onRevisionSaved,
  });

  final String patientID;
  final List<MedicalHistoryRevision>? revisions;
  final ValueChanged<MedicalHistoryRevision>? onRevisionSaved;

  @override
  State<PatientMedicalHistory> createState() => _PatientMedicalHistoryState();
}

class _PatientMedicalHistoryState extends State<PatientMedicalHistory> {
  MedicalHistoryRevision? _draft;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: widget.revisions == null
          ? medicalHistoryRevisions.observableMap.stream
          : null,
      builder: (context, snapshot) {
        final revisions = widget.revisions ??
            medicalHistoryRevisions.forPatient(widget.patientID);
        if (_draft != null) {
          return MedicalHistoryForm(
            revision: _draft!,
            onCancel: () => setState(() => _draft = null),
            onSave: _saveDraft,
          );
        }
        return _RevisionList(
          revisions: revisions,
          onCreate: () => _startDraft(revisions),
        );
      },
    );
  }

  void _startDraft(List<MedicalHistoryRevision> revisions) {
    final languageCode =
        {'en', 'el', 'de'}.contains(locale.s.$code) ? locale.s.$code : 'en';
    final draft = revisions.isEmpty
        ? MedicalHistoryRevision.fromJson({
            'patient_id': widget.patientID,
            'language_code': languageCode,
            'source': MedicalHistorySource.staffManual,
            'status': MedicalHistoryStatus.draft,
          })
        : revisions.first.copyAsNextRevision(languageCode: languageCode);
    setState(() => _draft = draft);
  }

  void _saveDraft() {
    final revision = _draft!;
    revision.status = MedicalHistoryStatus.pendingReview;
    revision.submittedAt = DateTime.now().toUtc();
    revision.title = 'Medical history revision ${revision.revisionNumber}';
    if (widget.onRevisionSaved != null) {
      widget.onRevisionSaved!(revision);
    } else {
      medicalHistoryRevisions.addRevision(revision);
    }
    setState(() => _draft = null);
  }
}

class MedicalHistoryForm extends StatefulWidget {
  const MedicalHistoryForm({
    super.key,
    required this.revision,
    required this.onSave,
    required this.onCancel,
  });

  final MedicalHistoryRevision revision;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  State<MedicalHistoryForm> createState() => _MedicalHistoryFormState();
}

class _MedicalHistoryFormState extends State<MedicalHistoryForm> {
  MedicalHistoryRevision get revision => widget.revision;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoBar(
          severity: InfoBarSeverity.info,
          title: Text(txt('newMedicalHistoryRevision')),
          content: Text(txt('medicalHistoryDescription')),
        ),
        const SizedBox(height: 12),
        InfoLabel(
          label: txt('language'),
          child: ComboBox<String>(
            isExpanded: true,
            value: revision.languageCode,
            items: const [
              ComboBoxItem(value: 'el', child: Text('Ελληνικά')),
              ComboBoxItem(value: 'en', child: Text('English')),
              ComboBoxItem(value: 'de', child: Text('Deutsch')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => revision.languageCode = value);
            },
          ),
        ),
        const SizedBox(height: 12),
        _ContextFields(revision: revision),
        const SizedBox(height: 16),
        ...PracticeMedicalHistoryQuestionnaire.sections.map(
          (section) => _QuestionSection(
            section: section,
            revision: revision,
            onChanged: () => setState(() {}),
          ),
        ),
        _ConfirmationFields(
          revision: revision,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            Button(
              onPressed: widget.onCancel,
              child: Text(txt('cancelRevision')),
            ),
            FilledButton(
              key: WK.btnSaveMedicalHistory,
              onPressed: widget.onSave,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(FluentIcons.save, size: 15),
                  const SizedBox(width: 6),
                  Text(txt('saveRevision')),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ContextFields extends StatelessWidget {
  const _ContextFields({required this.revision});

  final MedicalHistoryRevision revision;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 680;
        final fields = [
          _MedicalTextField(
            label: txt('reasonForVisit'),
            initialValue: revision.reasonForVisit,
            onChanged: (value) => revision.reasonForVisit = value,
          ),
          _MedicalTextField(
            label: txt('presentCondition'),
            initialValue: revision.presentCondition,
            onChanged: (value) => revision.presentCondition = value,
          ),
          _MedicalTextField(
            label: txt('treatingPhysician'),
            initialValue: revision.treatingPhysician,
            onChanged: (value) => revision.treatingPhysician = value,
          ),
          _MedicalTextField(
            label: txt('diseasesSurgeries'),
            initialValue: revision.diseasesSurgeries,
            maxLines: 3,
            onChanged: (value) => revision.diseasesSurgeries = value,
          ),
          _MedicalTextField(
            label: txt('generalMedicalNotes'),
            initialValue: revision.generalNotes,
            maxLines: 3,
            onChanged: (value) => revision.generalNotes = value,
          ),
        ];
        if (!twoColumns) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _spaced(fields),
          );
        }
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: fields
              .map((field) => SizedBox(
                    width: (constraints.maxWidth - 12) / 2,
                    child: field,
                  ))
              .toList(),
        );
      },
    );
  }

  static List<Widget> _spaced(List<Widget> widgets) {
    return [
      for (var index = 0; index < widgets.length; index++) ...[
        widgets[index],
        if (index != widgets.length - 1) const SizedBox(height: 10),
      ],
    ];
  }
}

class _QuestionSection extends StatelessWidget {
  const _QuestionSection({
    required this.section,
    required this.revision,
    required this.onChanged,
  });

  final MedicalHistorySection section;
  final MedicalHistoryRevision revision;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.resources.cardStrokeColorDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            section.label(revision.languageCode),
            style: theme.typography.subtitle,
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < section.questions.length; index++) ...[
            _QuestionEditor(
              question: section.questions[index],
              revision: revision,
              onChanged: onChanged,
            ),
            if (index != section.questions.length - 1) const Divider(size: 18),
          ],
        ],
      ),
    );
  }
}

class _QuestionEditor extends StatelessWidget {
  const _QuestionEditor({
    required this.question,
    required this.revision,
    required this.onChanged,
  });

  final MedicalHistoryQuestion question;
  final MedicalHistoryRevision revision;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final answer = revision.answers[question.id] ?? MedicalHistoryAnswer();
    final positive = answer.value == MedicalHistoryAnswerValue.yes;
    final label = [
      if (question.paperNumber != null) '${question.paperNumber}.',
      question.label(revision.languageCode),
    ].join(' ');
    return Padding(
      padding: EdgeInsetsDirectional.only(start: question.indented ? 16 : 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 600;
          final prompt = Text(
            label,
            style: TextStyle(
              fontWeight:
                  question.indented ? FontWeight.normal : FontWeight.w600,
              color: positive ? Colors.orange.dark : null,
            ),
          );
          final selector = _AnswerSelector(
            questionID: question.id,
            value: answer.value,
            onChanged: (value) {
              revision.answerFor(question.id).value = value;
              onChanged();
            },
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (narrow) ...[
                prompt,
                const SizedBox(height: 8),
                selector,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: prompt),
                    const SizedBox(width: 12),
                    selector,
                  ],
                ),
              if (answer.imported) ...[
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Icon(FluentIcons.warning, size: 13),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '${txt('importedNeedsReview')}: '
                        '${answer.sourceField} = ${answer.rawValue}',
                        style: FluentTheme.of(context).typography.caption,
                      ),
                    ),
                  ],
                ),
              ],
              if (positive || answer.notes.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                _MedicalTextField(
                  key: ValueKey('medical_notes_${question.id}'),
                  label: txt('additionalDetails'),
                  initialValue: answer.notes,
                  maxLines: 3,
                  onChanged: (value) {
                    revision.answerFor(question.id).notes = value;
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AnswerSelector extends StatelessWidget {
  const _AnswerSelector({
    required this.questionID,
    required this.value,
    required this.onChanged,
  });

  final String questionID;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = <String, String>{
      MedicalHistoryAnswerValue.yes: txt('answerYes'),
      MedicalHistoryAnswerValue.no: txt('answerNo'),
      MedicalHistoryAnswerValue.unknown: txt('unknown'),
      MedicalHistoryAnswerValue.notApplicable: txt('medicalNotApplicable'),
    };
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: options.entries
          .map(
            (entry) => ToggleButton(
              key: ValueKey('medical_${questionID}_${entry.key}'),
              checked: value == entry.key,
              onChanged: (_) => onChanged(entry.key),
              child: Text(entry.value, style: const TextStyle(fontSize: 12)),
            ),
          )
          .toList(),
    );
  }
}

class _ConfirmationFields extends StatelessWidget {
  const _ConfirmationFields({
    required this.revision,
    required this.onChanged,
  });

  final MedicalHistoryRevision revision;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final paperSignaturePresent = revision.signature['present'] == true &&
        revision.signature['capture_method'] == 'paper';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LabeledCheckbox(
          checked: revision.patientConfirmed,
          label: txt('patientConfirmed'),
          onChanged: (value) {
            revision.patientConfirmed = value;
            onChanged();
          },
        ),
        const SizedBox(height: 10),
        _LabeledCheckbox(
          checked: paperSignaturePresent,
          label: txt('paperSignaturePresent'),
          onChanged: (value) {
            revision.signature = value
                ? {
                    'present': true,
                    'capture_method': 'paper',
                    'recorded_at': DateTime.now().toUtc().toIso8601String(),
                  }
                : {};
            onChanged();
          },
        ),
      ],
    );
  }
}

class _RevisionList extends StatelessWidget {
  const _RevisionList({required this.revisions, required this.onCreate});

  final List<MedicalHistoryRevision> revisions;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoBar(
          severity: InfoBarSeverity.info,
          title: Text(txt('medicalHistory')),
          content: Text(txt('medicalHistoryDescription')),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton(
            key: WK.btnNewMedicalHistory,
            onPressed: onCreate,
            child: Text(txt('newMedicalHistoryRevision')),
          ),
        ),
        const SizedBox(height: 12),
        if (revisions.isEmpty)
          InfoBar(title: Text(txt('noMedicalHistory')))
        else
          ...revisions.map((revision) => _RevisionCard(revision: revision)),
      ],
    );
  }
}

class _LabeledCheckbox extends StatelessWidget {
  const _LabeledCheckbox({
    required this.checked,
    required this.label,
    required this.onChanged,
  });

  final bool checked;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          checked: checked,
          onChanged: (value) => onChanged(value == true),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
      ],
    );
  }
}

class _RevisionCard extends StatelessWidget {
  const _RevisionCard({required this.revision});

  final MedicalHistoryRevision revision;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final positives = revision.positiveQuestionIDs;
    final imported = revision.isImported;
    final accent =
        imported || revision.requiresReview ? Colors.orange : Colors.teal;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(7),
        border: BorderDirectional(start: BorderSide(color: accent, width: 5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${txt('revision')} ${revision.revisionNumber}',
                style: theme.typography.bodyStrong,
              ),
              _Pill(label: _sourceLabel(revision.source), color: accent),
              _Pill(label: _statusLabel(revision.status), color: accent),
              _Pill(
                  label:
                      _formatDate(revision.submittedAt ?? revision.createdAt)),
            ],
          ),
          if (imported) ...[
            const SizedBox(height: 8),
            Text(txt('legacyImportedText'), style: theme.typography.caption),
          ],
          const SizedBox(height: 9),
          Text(
            positives.isEmpty
                ? txt('noPositiveAnswers')
                : '${txt('positiveAnswers')}: ${positives.map(_questionLabel).join(', ')}',
          ),
          if (revision.reasonForVisit.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text('${txt('reasonForVisit')}: ${revision.reasonForVisit}'),
          ],
          if (revision.presentCondition.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text('${txt('presentCondition')}: ${revision.presentCondition}'),
          ],
          if (revision.legacyMedicinesText.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              '${PracticeMedicalHistoryQuestionnaire.questionsByID['other_medications']!.label(revision.languageCode)}: '
              '${revision.legacyMedicinesText}',
            ),
          ],
        ],
      ),
    );
  }

  String _questionLabel(String id) =>
      PracticeMedicalHistoryQuestionnaire.questionsByID[id]
          ?.label(revision.languageCode) ??
      id;

  static String _sourceLabel(String source) => switch (source) {
        MedicalHistorySource.dentalWin => txt('dentalWinImport'),
        MedicalHistorySource.tablet => txt('tabletEntry'),
        MedicalHistorySource.ocr => txt('ocrImport'),
        _ => txt('staffManual'),
      };

  static String _statusLabel(String status) => switch (status) {
        MedicalHistoryStatus.confirmed => txt('confirmed'),
        MedicalHistoryStatus.superseded => txt('superseded'),
        _ => txt('pendingReview'),
      };

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? FluentTheme.of(context).accentColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: foreground, fontSize: 12)),
    );
  }
}

class _MedicalTextField extends StatefulWidget {
  const _MedicalTextField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.maxLines = 1,
  });

  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  State<_MedicalTextField> createState() => _MedicalTextFieldState();
}

class _MedicalTextFieldState extends State<_MedicalTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InfoLabel(
      label: widget.label,
      child: TextBox(
        controller: _controller,
        maxLines: widget.maxLines,
        onChanged: widget.onChanged,
      ),
    );
  }
}
