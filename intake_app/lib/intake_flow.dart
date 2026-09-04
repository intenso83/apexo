import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'date_input_field.dart';
import 'form_configuration.dart';
import 'intake_pdf_generator.dart';
import 'intake_schema.dart';
import 'intake_settings_store.dart';
import 'signature_pad.dart';
import 'staff_settings_screen.dart';
import 'submission_client.dart';

enum _ShellStage { preparation, intake, complete }

const _fieldKeys = <String>[
  'family_name',
  'given_name',
  'father_name',
  'date_of_birth',
  'occupation',
  'phone',
  'mobile',
  'email',
  'address',
  'postal_code',
  'city',
  'amka',
  'afm',
  'doy',
  'insurance',
  'country_of_origin',
  'signed_name',
];

class IntakeShell extends StatefulWidget {
  const IntakeShell({super.key, this.settingsStore});

  final IntakeSettingsStore? settingsStore;

  @override
  State<IntakeShell> createState() => _IntakeShellState();
}

class _IntakeShellState extends State<IntakeShell> {
  final _client = const IntakeSubmissionClient();
  late final IntakeSettingsStore _settingsStore =
      widget.settingsStore ?? IntakeSettingsStore();
  final _signatureController = SignatureController();
  final _sessionController = TextEditingController();
  final _scrollController = ScrollController();
  late final Map<String, TextEditingController> _fields = {
    for (final key in _fieldKeys) key: TextEditingController(),
  };

  _ShellStage _stage = _ShellStage.preparation;
  IntakeDraft _draft = IntakeDraft();
  String _sessionId = '';
  int _page = 0;
  String? _pageError;
  String? _submitError;
  bool _submitting = false;
  bool _testCompletion = false;
  bool _settingsReady = false;
  IntakeFormConfiguration _configuration = IntakeFormConfiguration.defaults();

  int get _pageCount => _configuration.visiblePages.length + 2;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _settingsStore.load();
    if (!mounted) return;
    setState(() {
      _configuration = _settingsStore.configuration.copy();
      _settingsReady = true;
    });
  }

  @override
  void dispose() {
    _sessionController.dispose();
    _scrollController.dispose();
    _signatureController.dispose();
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _startIntake() {
    final session = _sessionController.text.trim();
    if (_client.isConfigured && session.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter the one-time intake session first.'),
        ),
      );
      return;
    }
    for (final controller in _fields.values) {
      controller.clear();
    }
    _signatureController.clear();
    setState(() {
      _draft = IntakeDraft();
      _sessionId = session;
      _page = 0;
      _pageError = null;
      _submitError = null;
      _stage = _ShellStage.intake;
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _returnToPreparation() {
    setState(() {
      _draft = IntakeDraft();
      _sessionId = '';
      _sessionController.clear();
      _stage = _ShellStage.preparation;
      _page = 0;
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _copyFieldsToDraft() {
    for (final definition in intakeFieldDefinitions) {
      _draft.personal[definition.id] = _fields[definition.id]!.text;
    }
    _draft.signedName = _fields['signed_name']!.text;
    _draft.signatureStrokes = _signatureController.toJson();
    _draft.configurationRevision = _configuration.revision;
    final visiblePageIds = _configuration.visiblePages
        .map((page) => page.id)
        .toSet();
    _draft.visibleItemIds = _configuration.items
        .where((item) => item.enabled && visiblePageIds.contains(item.pageId))
        .map((item) => '${item.kind}:${item.id}')
        .toList(growable: false);
  }

  bool _validatePage() {
    String? error;
    if (_page == 0 && !_draft.privacyAccepted) {
      error = t(_draft.language, 'privacy_required');
    } else if (_page > 0 && _page < _pageCount - 1) {
      final page = _configuration.visiblePages[_page - 1];
      final items = _configuration.itemsForPage(page.id);
      if (items.any(
        (item) => item.mandatory && _fields[item.id]!.text.trim().isEmpty,
      )) {
        error = t(_draft.language, 'identity_required');
      }
      if (error == null &&
          items.any((item) => item.id == 'date_of_birth') &&
          !isValidIntakeDate(_fields['date_of_birth']!.text.trim())) {
        error = t(_draft.language, 'date_invalid');
      }
      final contactPages = _configuration.visiblePages
          .where(
            (candidate) => _configuration
                .itemsForPage(candidate.id)
                .any((item) => item.isContactMethod),
          )
          .toList();
      if (error == null &&
          contactPages.isNotEmpty &&
          contactPages.last.id == page.id &&
          contactFieldIds.every(
            (id) =>
                !(_configuration.itemById(id)?.enabled ?? false) ||
                _fields[id]!.text.trim().isEmpty,
          )) {
        error = t(_draft.language, 'contact_required');
      }
      if (error == null &&
          items
              .where((item) => item.isQuestion)
              .any((item) => _draft.answers[item.id]!.value.isEmpty)) {
        error = t(_draft.language, 'answers_required');
      }
      if (error == null &&
          items
              .where((item) => item.isQuestion)
              .any(
                (item) =>
                    !hasValidRequiredDetails(item.id, _draft.answers[item.id]!),
              )) {
        error = t(_draft.language, 'details_required');
      }
    } else if (_page == _pageCount - 1) {
      if (!_draft.confirmed ||
          _fields['signed_name']!.text.trim().isEmpty ||
          _signatureController.isEmpty) {
        error = t(_draft.language, 'signature_required');
      }
    }
    setState(() => _pageError = error);
    return error == null;
  }

  void _next() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_validatePage()) return;
    _copyFieldsToDraft();
    if (_page == _pageCount - 1) {
      _submit();
      return;
    }
    final enteringReview = _page == _pageCount - 2;
    setState(() {
      _page += 1;
      _pageError = null;
      if (enteringReview && _fields['signed_name']!.text.trim().isEmpty) {
        _fields['signed_name']!.text =
            '${_fields['given_name']!.text} ${_fields['family_name']!.text}'
                .trim();
      }
    });
    _scrollToTop();
  }

  void _back() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_page == 0) return;
    _copyFieldsToDraft();
    setState(() {
      _page -= 1;
      _pageError = null;
    });
    _scrollToTop();
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  Future<void> _submit() async {
    _copyFieldsToDraft();
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    final isTest = !_client.isConfigured;
    try {
      final packet = _draft.toJson();
      final pdfBytes = await const IntakePdfGenerator().generate(
        draft: _draft,
        configuration: _configuration,
      );
      if (isTest) {
        await Future<void>.delayed(const Duration(milliseconds: 700));
      } else {
        await _client.submit(
          sessionId: _sessionId,
          packet: packet,
          pdfBytes: pdfBytes,
        );
      }
      if (!mounted) return;
      for (final controller in _fields.values) {
        controller.clear();
      }
      _signatureController.clear();
      setState(() {
        _draft = IntakeDraft();
        _sessionId = '';
        _testCompletion = isTest;
        _stage = _ShellStage.complete;
        _submitting = false;
      });
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } on IntakeSubmissionException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitError = error.message;
        _submitting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitError = t(_draft.language, 'submit_failed');
        _submitting = false;
      });
    }
  }

  Future<void> _openSettings() async {
    if (!_settingsReady) return;
    final unlocked = await unlockStaffSettings(context, _settingsStore);
    if (!unlocked || !mounted) return;
    final result = await Navigator.of(context).push<IntakeFormConfiguration>(
      MaterialPageRoute(
        builder: (_) => StaffSettingsScreen(store: _settingsStore),
      ),
    );
    if (result != null && mounted) {
      setState(() => _configuration = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: switch (_stage) {
        _ShellStage.preparation => _buildPreparation(),
        _ShellStage.intake => _buildIntake(),
        _ShellStage.complete => _buildComplete(),
      },
    );
  }

  Widget _buildPreparation() {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 500 || size.height < 900;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(compact ? 14 : 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Card(
                elevation: 0,
                color: Colors.white,
                child: Padding(
                  padding: EdgeInsets.all(compact ? 20 : 32),
                  child: Column(
                    children: [
                      PracticeHeader(
                        compact: compact,
                        configuration: _configuration,
                        language: _draft.language,
                      ),
                      SizedBox(height: compact ? 14 : 28),
                      const Divider(),
                      SizedBox(height: compact ? 14 : 24),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Staff preparation',
                          style: TextStyle(
                            fontSize: compact ? 24 : 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _client.isConfigured
                              ? 'Enter the one-time session supplied by Apexo, then hand the tablet to the patient.'
                              : 'Testing build: submissions are disabled and no patient data will be saved.',
                          style: const TextStyle(fontSize: 17, height: 1.4),
                        ),
                      ),
                      SizedBox(height: compact ? 14 : 22),
                      if (_client.isConfigured)
                        TextField(
                          controller: _sessionController,
                          autocorrect: false,
                          enableSuggestions: false,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'One-time intake session',
                            prefixIcon: Icon(Icons.key_outlined),
                          ),
                        )
                      else
                        const _SecurityNotice(),
                      SizedBox(height: compact ? 18 : 28),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              key: const ValueKey('staff_settings_button'),
                              onPressed: _settingsReady ? _openSettings : null,
                              icon: const Icon(
                                Icons.admin_panel_settings_outlined,
                              ),
                              label: Text(
                                _settingsReady
                                    ? 'Form settings'
                                    : 'Loading settings…',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              onPressed: _startIntake,
                              icon: const Icon(Icons.tablet_android),
                              label: Text(
                                _client.isConfigured
                                    ? 'Start patient intake'
                                    : 'Test the form',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntake() {
    final language = _draft.language;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
              child: Column(
                children: [
                  PracticeHeader(
                    compact: true,
                    configuration: _configuration,
                    language: language,
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (_page + 1) / _pageCount,
                      minHeight: 10,
                      backgroundColor: const Color(0xFFDDE3E8),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${t(language, 'step')} ${_page + 1} / $_pageCount',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 120),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: _pageBody(_page),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: SafeArea(
          top: false,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
            child: Row(
              children: [
                if (_page > 0)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _submitting ? null : _back,
                      icon: const Icon(Icons.arrow_back),
                      label: Text(t(language, 'back')),
                    ),
                  ),
                if (_page > 0) const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    key: const ValueKey('next_button'),
                    onPressed: _submitting ? null : _next,
                    icon: _submitting
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : Icon(
                            _page == _pageCount - 1
                                ? Icons.lock_outline
                                : Icons.arrow_forward,
                          ),
                    label: Text(
                      _submitting
                          ? t(language, 'submitting')
                          : t(
                              language,
                              _page == _pageCount - 1 ? 'submit' : 'next',
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageBody(int page) {
    final children = <Widget>[];
    if (page == 0) {
      children.addAll(_welcomePage());
    } else if (page == _pageCount - 1) {
      children.addAll(_reviewPage());
    } else {
      children.addAll(_configuredPage(_configuration.visiblePages[page - 1]));
    }
    if (_pageError != null) {
      children.addAll([
        const SizedBox(height: 18),
        _MessageBox(message: _pageError!, error: true),
      ]);
    }
    if (_submitError != null) {
      children.addAll([
        const SizedBox(height: 18),
        _MessageBox(message: _submitError!, error: true),
      ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  List<Widget> _welcomePage() {
    final language = _draft.language;
    return [
      _PageTitle(
        title: t(language, 'welcome_title'),
        subtitle: t(language, 'welcome_body'),
      ),
      const SizedBox(height: 22),
      Text(
        t(language, 'choose_language'),
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _LanguageButton(
            label: 'Ελληνικά',
            selected: language == 'el',
            onTap: () => setState(() => _draft.language = 'el'),
          ),
          _LanguageButton(
            label: 'English',
            selected: language == 'en',
            onTap: () => setState(() => _draft.language = 'en'),
          ),
          _LanguageButton(
            label: 'Deutsch',
            selected: language == 'de',
            onTap: () => setState(() => _draft.language = 'de'),
          ),
        ],
      ),
      const SizedBox(height: 28),
      Text(
        t(language, 'gdpr_title'),
        style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      _MessageBox(message: _gdprNotice(language)),
      const SizedBox(height: 16),
      _LargeCheckbox(
        value: _draft.privacyAccepted,
        label: t(language, 'privacy_accept'),
        onChanged: (value) => setState(() => _draft.privacyAccepted = value),
      ),
    ];
  }

  String _gdprNotice(String language) {
    final name = _configuration.practiceName(language);
    return switch (language) {
      'el' =>
        'Υπεύθυνος επεξεργασίας είναι το $name. Συλλέγουμε τα στοιχεία '
            'ταυτοποίησης, επικοινωνίας και υγείας αυτής της φόρμας αποκλειστικά '
            'για οδοντιατρική διάγνωση και θεραπεία, τήρηση του ιατρικού αρχείου '
            'και συμμόρφωση με τις νόμιμες υποχρεώσεις του ιατρείου. Η επεξεργασία '
            'δεδομένων υγείας είναι αναγκαία για την παροχή υγειονομικής περίθαλψης '
            '(άρθρο 9 παρ. 2η ΓΚΠΔ) και γίνεται υπό επαγγελματικό απόρρητο. Πρόσβαση '
            'έχουν μόνο εξουσιοδοτημένα μέλη του ιατρείου και δεσμευμένοι εκτελούντες '
            'την επεξεργασία. Τα δεδομένα τηρούνται για όσο απαιτεί η θεραπεία και '
            'η ισχύουσα νομοθεσία. Μπορείτε να ζητήσετε ενημέρωση, πρόσβαση, διόρθωση '
            'ή περιορισμό και, όπου εφαρμόζεται, διαγραφή ή φορητότητα, επικοινωνώντας '
            'με το ιατρείο. Έχετε επίσης δικαίωμα καταγγελίας στην Αρχή Προστασίας '
            'Δεδομένων Προσωπικού Χαρακτήρα (dpa.gr).',
      'de' =>
        'Verantwortlicher ist $name. Wir erheben die Identitäts-, Kontakt- und '
            'Gesundheitsdaten dieses Formulars ausschließlich für zahnärztliche '
            'Diagnose und Behandlung, die Patientenakte und gesetzliche Pflichten. '
            'Die Verarbeitung von Gesundheitsdaten ist für die Gesundheitsversorgung '
            'erforderlich (Art. 9 Abs. 2 Buchst. h DSGVO) und unterliegt der '
            'beruflichen Schweigepflicht. Zugriff haben nur befugte Praxismitarbeiter '
            'und vertraglich gebundene Auftragsverarbeiter. Die Daten werden so lange '
            'gespeichert, wie Behandlung und geltendes Recht es verlangen. Sie können '
            'bei der Praxis Auskunft, Zugang, Berichtigung oder Einschränkung sowie, '
            'soweit anwendbar, Löschung oder Übertragbarkeit verlangen. Sie können '
            'außerdem Beschwerde bei der zuständigen Datenschutzaufsicht einlegen.',
      _ =>
        'The data controller is $name. We collect the identity, contact, and health '
            'information in this form solely for dental diagnosis and treatment, '
            'maintenance of the clinical record, and the practice’s legal obligations. '
            'Health-data processing is necessary for healthcare provision '
            '(GDPR Article 9(2)(h)) and is subject to professional confidentiality. '
            'Access is limited to authorised practice staff and bound service providers. '
            'Data is retained for as long as treatment and applicable law require. '
            'You may ask the practice for information, access, correction, or restriction '
            'and, where applicable, deletion or portability. You may also complain to '
            'the competent data-protection authority.',
    };
  }

  List<Widget> _configuredPage(IntakePageConfiguration page) {
    final language = _draft.language;
    final widgets = <Widget>[
      _PageTitle(
        title: page.title(language),
        subtitle: page.subtitle(language),
      ),
      const SizedBox(height: 20),
    ];
    String? lastGroup;
    for (final item in _configuration.itemsForPage(page.id)) {
      if (item.isField) {
        final definition = intakeFieldsById[item.id];
        if (definition == null) continue;
        widgets.add(_fieldFromDefinition(definition, language));
        widgets.add(const SizedBox(height: 14));
        lastGroup = null;
        continue;
      }
      final question = intakeQuestions
          .where((candidate) => candidate.id == item.id)
          .firstOrNull;
      if (question == null) continue;
      if (question.group != lastGroup) {
        if (lastGroup != null) widgets.add(const SizedBox(height: 18));
        widgets.add(
          Text(
            localized(questionnaireGroups[question.group]!, language),
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
          ),
        );
        widgets.add(const SizedBox(height: 10));
        lastGroup = question.group;
      }
      widgets.add(
        _QuestionCard(
          question: question,
          answer: _draft.answers[question.id]!,
          language: language,
          onChanged: () => setState(() => _pageError = null),
        ),
      );
      widgets.add(const SizedBox(height: 12));
    }
    return widgets;
  }

  Widget _fieldFromDefinition(
    IntakeFieldDefinition definition,
    String language,
  ) {
    if (definition.input == 'date') {
      return DateInputField(
        key: ValueKey('field_${definition.id}'),
        controller: _fields[definition.id]!,
        label: definition.label(language),
        onChanged: () {
          if (_pageError != null) setState(() => _pageError = null);
        },
      );
    }
    final keyboardType = switch (definition.input) {
      'phone' => TextInputType.phone,
      'email' => TextInputType.emailAddress,
      'number' => TextInputType.number,
      _ => null,
    };
    return _field(
      definition.id,
      definition.label(language),
      required: definition.mandatory,
      wide: definition.wide,
      lines: definition.lines,
      keyboardType: keyboardType,
    );
  }

  List<Widget> _reviewPage() {
    final language = _draft.language;
    final visiblePageIds = _configuration.visiblePages
        .map((page) => page.id)
        .toSet();
    final visibleQuestionIds = _configuration.items
        .where(
          (item) =>
              item.enabled &&
              item.isQuestion &&
              visiblePageIds.contains(item.pageId),
        )
        .map((item) => item.id)
        .toSet();
    final yesQuestions = intakeQuestions
        .where(
          (question) =>
              visibleQuestionIds.contains(question.id) &&
              _draft.answers[question.id]!.value == 'yes',
        )
        .toList();
    return [
      _PageTitle(
        title: t(language, 'review_title'),
        subtitle: t(language, 'review_hint'),
      ),
      const SizedBox(height: 18),
      _ReviewCard(
        title: t(language, 'patient'),
        lines: [
          '${_fields['given_name']!.text} ${_fields['family_name']!.text}'
              .trim(),
          '${t(language, 'date_of_birth')}: ${_fields['date_of_birth']!.text}',
          [
            _fields['mobile']!.text,
            _fields['phone']!.text,
            _fields['email']!.text,
          ].where((value) => value.trim().isNotEmpty).join(' · '),
        ],
      ),
      const SizedBox(height: 14),
      _ReviewCard(
        title: t(language, 'yes_answers'),
        lines: yesQuestions.isEmpty
            ? [t(language, 'none')]
            : yesQuestions.map((q) => q.label(language)).toList(),
      ),
      const SizedBox(height: 18),
      _MessageBox(message: t(language, 'confirmation_text')),
      const SizedBox(height: 14),
      _LargeCheckbox(
        value: _draft.confirmed,
        label: t(language, 'confirm_checkbox'),
        onChanged: (value) => setState(() => _draft.confirmed = value),
      ),
      const SizedBox(height: 18),
      _field(
        'signed_name',
        t(language, 'signed_name'),
        required: true,
        wide: true,
      ),
      const SizedBox(height: 18),
      SignaturePad(
        controller: _signatureController,
        label: t(language, 'draw_signature'),
        clearLabel: t(language, 'clear_signature'),
        onChanged: () {
          if (_pageError != null) setState(() => _pageError = null);
        },
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          const Icon(Icons.lock_outline, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text(t(language, 'secure_submit_hint'))),
        ],
      ),
    ];
  }

  Widget _field(
    String key,
    String label, {
    bool required = false,
    bool wide = false,
    int lines = 1,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return SizedBox(
      width: wide ? double.infinity : 430,
      child: TextField(
        key: ValueKey('field_$key'),
        controller: _fields[key],
        keyboardType:
            keyboardType ??
            (lines > 1 ? TextInputType.multiline : TextInputType.text),
        minLines: lines,
        maxLines: lines,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          hintText: hint,
          alignLabelWithHint: lines > 1,
        ),
        onChanged: (_) => setState(() => _pageError = null),
      ),
    );
  }

  Widget _buildComplete() {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Card(
                elevation: 0,
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(34),
                  child: Column(
                    children: [
                      GestureDetector(
                        onLongPress: _returnToPreparation,
                        child: PracticeHeader(
                          compact: false,
                          configuration: _configuration,
                          language: _draft.language,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Icon(
                        _testCompletion
                            ? Icons.science_outlined
                            : Icons.check_circle,
                        size: 88,
                        color: _testCompletion
                            ? Colors.orange.shade700
                            : const Color(0xFF17845B),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _testCompletion ? 'Test completed' : 'Thank you',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _testCompletion
                            ? 'The signed PDF was generated and checked in memory. This testing build did not save or send the PDF or answers.'
                            : 'Your form has been sent to the practice. Your answers have been cleared from this tablet.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 19, height: 1.45),
                      ),
                      const SizedBox(height: 26),
                      const _MessageBox(
                        message:
                            'Please return the tablet to a member of staff.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PracticeHeader extends StatelessWidget {
  const PracticeHeader({
    super.key,
    required this.compact,
    required this.configuration,
    required this.language,
  });

  final bool compact;
  final IntakeFormConfiguration configuration;
  final String language;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PracticeLogo(configuration: configuration, compact: compact),
        const SizedBox(width: 16),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                configuration.practiceName(language),
                style: TextStyle(
                  fontSize: compact ? 16 : 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                t(language, 'practice_type'),
                style: TextStyle(fontSize: compact ? 14 : 17),
              ),
              if (!compact)
                const Text(
                  'Χρυσοστόμου Σμύρνης 11 · Θεσσαλονίκη · 2310 260814',
                  style: TextStyle(fontSize: 14),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PracticeLogo extends StatelessWidget {
  const _PracticeLogo({required this.configuration, required this.compact});

  final IntakeFormConfiguration configuration;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 62.0 : 94.0;
    final fallback = Image.asset(
      'assets/practice_logo.gif',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
    final path = configuration.customLogoPath.trim();
    if (path.isEmpty) return fallback;
    return Image.file(
      File(path),
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

class _SecurityNotice extends StatelessWidget {
  const _SecurityNotice();

  @override
  Widget build(BuildContext context) {
    return const _MessageBox(
      message:
          'No Apexo login is included in this app. It cannot search, open, edit, or export patient records.',
    );
  }
}

class _PageTitle extends StatelessWidget {
  const _PageTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 18,
            height: 1.45,
            color: Color(0xFF4C5B69),
          ),
        ),
      ],
    );
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      height: 62,
      child: selected
          ? FilledButton(onPressed: onTap, child: Text(label))
          : OutlinedButton(onPressed: onTap, child: Text(label)),
    );
  }
}

class _LargeCheckbox extends StatelessWidget {
  const _LargeCheckbox({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: value
                ? Theme.of(context).colorScheme.secondary
                : const Color(0xFFB9C2CC),
            width: value ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 38,
              child: Checkbox(
                value: value,
                onChanged: (next) => onChanged(next ?? false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionChoice {
  const _QuestionChoice(
    this.id,
    this.label,
    this.value, [
    this.selections = const [],
  ]);

  final String id;
  final String label;
  final String value;
  final List<String> selections;
}

class _QuestionCard extends StatefulWidget {
  const _QuestionCard({
    required this.question,
    required this.answer,
    required this.language,
    required this.onChanged,
  });

  final IntakeQuestion question;
  final IntakeAnswer answer;
  final String language;
  final VoidCallback onChanged;

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  late final TextEditingController _notes = TextEditingController(
    text: widget.answer.notes,
  );

  @override
  void didUpdateWidget(covariant _QuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question.id != widget.question.id &&
        _notes.text != widget.answer.notes) {
      _notes.text = widget.answer.notes;
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    final choices = _choices(language);
    final detailsRequired = requiresQuestionDetails(
      widget.question.id,
      widget.answer,
    );
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: widget.answer.value.isEmpty
              ? const Color(0xFFD1D8DE)
              : const Color(0xFF9EB1B5),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.question.label(language),
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: choices.map((choice) {
                final selected =
                    widget.answer.value == choice.value &&
                    widget.answer.selections.length ==
                        choice.selections.length &&
                    choice.selections.every(widget.answer.selections.contains);
                return SizedBox(
                  height: 54,
                  child: selected
                      ? FilledButton(
                          key: ValueKey(
                            'answer_${widget.question.id}_${choice.id}',
                          ),
                          onPressed: () {},
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(118, 54),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                          ),
                          child: Text(choice.label),
                        )
                      : OutlinedButton(
                          key: ValueKey(
                            'answer_${widget.question.id}_${choice.id}',
                          ),
                          onPressed: () {
                            setState(() {
                              widget.answer.value = choice.value;
                              widget.answer.selections = choice.selections
                                  .toList();
                              if (choice.value != 'yes') {
                                widget.answer.notes = '';
                                _notes.clear();
                              }
                            });
                            widget.onChanged();
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(118, 54),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                          ),
                          child: Text(choice.label),
                        ),
                );
              }).toList(),
            ),
            if (widget.answer.value == 'yes' ||
                widget.answer.notes.isNotEmpty) ...[
              const SizedBox(height: 14),
              TextField(
                key: ValueKey('details_${widget.question.id}'),
                controller: _notes,
                keyboardType: widget.question.id == 'smoking'
                    ? TextInputType.number
                    : TextInputType.text,
                inputFormatters: widget.question.id == 'smoking'
                    ? [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ]
                    : null,
                minLines: widget.question.id == 'smoking' ? 1 : 2,
                maxLines: widget.question.id == 'smoking' ? 1 : 3,
                decoration: InputDecoration(
                  labelText: _detailsLabel(language, detailsRequired),
                ),
                onChanged: (value) {
                  widget.answer.notes = value;
                  widget.onChanged();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<_QuestionChoice> _choices(String language) {
    if (widget.question.id == 'liver_kidney_disease') {
      return [
        _QuestionChoice('no', t(language, 'no'), 'no'),
        _QuestionChoice('kidney', t(language, 'kidney'), 'yes', const [
          'kidney',
        ]),
        _QuestionChoice('liver', t(language, 'liver'), 'yes', const ['liver']),
        _QuestionChoice('both', t(language, 'kidney_and_liver'), 'yes', const [
          'kidney',
          'liver',
        ]),
        _QuestionChoice('unknown', t(language, 'unknown'), 'unknown'),
      ];
    }
    if (widget.question.id == 'blood_pressure_disorder') {
      return [
        _QuestionChoice('no', t(language, 'no'), 'no'),
        _QuestionChoice(
          'high',
          t(language, 'high_blood_pressure'),
          'yes',
          const ['high'],
        ),
        _QuestionChoice('low', t(language, 'low_blood_pressure'), 'yes', const [
          'low',
        ]),
        _QuestionChoice('unknown', t(language, 'unknown'), 'unknown'),
      ];
    }
    return [
      _QuestionChoice('no', t(language, 'no'), 'no'),
      _QuestionChoice('yes', t(language, 'yes'), 'yes'),
      _QuestionChoice('unknown', t(language, 'unknown'), 'unknown'),
    ];
  }

  String _detailsLabel(String language, bool required) {
    final key = switch (widget.question.id) {
      'antibiotic_allergy' => 'antibiotic_allergy_details',
      'liver_kidney_disease' => 'kidney_liver_details',
      'smoking' => 'cigarettes_per_day',
      _ => 'details_optional',
    };
    final label = t(language, key);
    return required ? '$label *' : label;
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC7D0D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 9),
          ...lines
              .where((line) => line.trim().isNotEmpty)
              .map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    line,
                    style: const TextStyle(fontSize: 17, height: 1.35),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.message, this.error = false});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error ? const Color(0xFF8A2633) : const Color(0xFF1E6070);
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(error ? Icons.error_outline : Icons.info_outline, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 17,
                height: 1.4,
                color: color,
                fontWeight: error ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _ui = <String, Map<String, String>>{
  'el': {
    'practice_type': 'Οδοντιατρείο',
    'step': 'Βήμα',
    'back': 'Πίσω',
    'next': 'Επόμενο',
    'submit': 'Ασφαλής αποστολή',
    'submitting': 'Αποστολή…',
    'welcome_title': 'Ιατρικό ιστορικό ασθενούς',
    'welcome_body':
        'Παρακαλούμε συμπληρώστε τη φόρμα με ακρίβεια. Μπορείτε να προχωρήσετε με τον δικό σας ρυθμό.',
    'choose_language': 'Επιλέξτε γλώσσα',
    'privacy_text':
        'Οι πληροφορίες χρησιμοποιούνται αποκλειστικά για την οδοντιατρική σας φροντίδα και αποστέλλονται στο ιατρείο μόνο όταν πατήσετε «Ασφαλής αποστολή».',
    'gdpr_title': 'Ενημέρωση προστασίας προσωπικών δεδομένων (ΓΚΠΔ)',
    'privacy_accept':
        'Έχω διαβάσει και κατανοήσει την παραπάνω ενημέρωση και επιθυμώ να υποβάλω τη φόρμα στο οδοντιατρείο.',
    'privacy_required':
        'Παρακαλούμε αποδεχθείτε την ενημέρωση για να συνεχίσετε.',
    'identity_title': 'Προσωπικά στοιχεία',
    'required_hint': 'Τα πεδία με αστερίσκο (*) είναι υποχρεωτικά.',
    'family_name': 'Επώνυμο',
    'given_name': 'Όνομα',
    'father_name': 'Πατρώνυμο',
    'date_of_birth': 'Ημερομηνία γέννησης',
    'date_invalid': 'Συμπληρώστε έγκυρη ημερομηνία σε μορφή ΗΗ/ΜΜ/ΕΕΕΕ.',
    'occupation': 'Επάγγελμα',
    'country_of_origin': 'Χώρα καταγωγής',
    'identity_required': 'Συμπληρώστε επώνυμο, όνομα και ημερομηνία γέννησης.',
    'contact_title': 'Επικοινωνία και διεύθυνση',
    'contact_hint': 'Χρειαζόμαστε τουλάχιστον έναν τρόπο επικοινωνίας.',
    'mobile': 'Κινητό',
    'phone': 'Τηλέφωνο',
    'email': 'Email',
    'address': 'Διεύθυνση',
    'postal_code': 'Τ.Κ.',
    'city': 'Πόλη',
    'amka': 'ΑΜΚΑ',
    'afm': 'ΑΦΜ',
    'doy': 'ΔΟΥ',
    'insurance': 'Ασφάλιση',
    'contact_required': 'Συμπληρώστε κινητό, τηλέφωνο ή email.',
    'conditions_title': 'Αλλεργίες και παθήσεις',
    'heart_title': 'Καρδιαγγειακό ιστορικό',
    'care_title': 'Αγωγή και τρόπος ζωής',
    'answer_every':
        'Επιλέξτε μία απάντηση για κάθε ερώτηση. Αν δεν γνωρίζετε, επιλέξτε «Δεν γνωρίζω».',
    'answers_required':
        'Παρακαλούμε απαντήστε σε όλες τις ερωτήσεις αυτής της σελίδας.',
    'details_required':
        'Συμπληρώστε τις υποχρεωτικές λεπτομέρειες για τις θετικές απαντήσεις.',
    'yes': 'Ναι',
    'no': 'Όχι',
    'unknown': 'Δεν γνωρίζω',
    'kidney': 'Νεφρά',
    'liver': 'Ήπαρ',
    'kidney_and_liver': 'Νεφρά και ήπαρ',
    'high_blood_pressure': 'Υψηλή',
    'low_blood_pressure': 'Χαμηλή',
    'details_optional': 'Λεπτομέρειες (προαιρετικά)',
    'antibiotic_allergy_details': 'Ποιο αντιβιοτικό και ποια αντίδραση;',
    'kidney_liver_details': 'Περιγράψτε την πάθηση',
    'cigarettes_per_day': 'Τσιγάρα ανά ημέρα',
    'review_title': 'Έλεγχος και υπογραφή',
    'review_hint': 'Ελέγξτε τη σύνοψη πριν από την ασφαλή αποστολή.',
    'patient': 'Ασθενής',
    'yes_answers': 'Απαντήσεις «Ναι»',
    'none': 'Καμία',
    'confirmation_text':
        'Δηλώνω ότι οι παραπάνω πληροφορίες είναι ακριβείς σύμφωνα με όσα γνωρίζω και θα ενημερώσω το ιατρείο για οποιαδήποτε αλλαγή.',
    'confirm_checkbox': 'Επιβεβαιώνω ότι έλεγξα τις απαντήσεις μου.',
    'signed_name': 'Ονοματεπώνυμο ως υπογραφή',
    'draw_signature': 'Υπογράψτε μέσα στο πλαίσιο με το δάχτυλο ή τη γραφίδα',
    'clear_signature': 'Καθαρισμός',
    'signature_required':
        'Επιβεβαιώστε τις απαντήσεις, γράψτε το ονοματεπώνυμό σας και υπογράψτε στο πλαίσιο.',
    'secure_submit_hint':
        'Μετά την επιτυχή αποστολή, οι απαντήσεις διαγράφονται από τη φόρμα του tablet.',
    'submit_failed':
        'Η φόρμα δεν μπόρεσε να αποσταλεί. Παρακαλούμε καλέστε μέλος του προσωπικού.',
  },
  'en': {
    'practice_type': 'Dental practice',
    'step': 'Step',
    'back': 'Back',
    'next': 'Next',
    'submit': 'Submit securely',
    'submitting': 'Submitting…',
    'welcome_title': 'Patient medical history',
    'welcome_body':
        'Please complete the form accurately. Take as much time as you need.',
    'choose_language': 'Choose your language',
    'privacy_text':
        'This information is used only for your dental care and is sent to the practice only when you press “Submit securely”.',
    'gdpr_title': 'Personal data notice (GDPR)',
    'privacy_accept':
        'I have read and understood the notice above and wish to submit this form to the dental practice.',
    'privacy_required': 'Please accept the notice to continue.',
    'identity_title': 'Personal details',
    'required_hint': 'Fields marked with an asterisk (*) are required.',
    'family_name': 'Family name',
    'given_name': 'First name',
    'father_name': 'Father’s name',
    'date_of_birth': 'Date of birth',
    'date_invalid': 'Enter a valid date in DD/MM/YYYY format.',
    'occupation': 'Occupation',
    'country_of_origin': 'Country of origin',
    'identity_required': 'Enter family name, first name, and date of birth.',
    'contact_title': 'Contact and address',
    'contact_hint': 'Please provide at least one way for us to contact you.',
    'mobile': 'Mobile',
    'phone': 'Telephone',
    'email': 'Email',
    'address': 'Address',
    'postal_code': 'Postal code',
    'city': 'City',
    'amka': 'AMKA',
    'afm': 'Tax number',
    'doy': 'Tax office',
    'insurance': 'Insurance',
    'contact_required': 'Enter a mobile, telephone, or email address.',
    'conditions_title': 'Allergies and conditions',
    'heart_title': 'Cardiovascular history',
    'care_title': 'Medication and lifestyle',
    'answer_every':
        'Choose one answer for every question. If you are unsure, choose “I don’t know”.',
    'answers_required': 'Please answer every question on this page.',
    'details_required':
        'Complete the required details for the positive answers.',
    'yes': 'Yes',
    'no': 'No',
    'unknown': 'I don’t know',
    'kidney': 'Kidney',
    'liver': 'Liver',
    'kidney_and_liver': 'Kidney and liver',
    'high_blood_pressure': 'High',
    'low_blood_pressure': 'Low',
    'details_optional': 'Details (optional)',
    'antibiotic_allergy_details': 'Which antibiotic and what reaction?',
    'kidney_liver_details': 'Describe the condition',
    'cigarettes_per_day': 'Cigarettes per day',
    'review_title': 'Review and sign',
    'review_hint': 'Review the summary before submitting securely.',
    'patient': 'Patient',
    'yes_answers': '“Yes” answers',
    'none': 'None',
    'confirmation_text':
        'I declare that this information is accurate to the best of my knowledge and I will notify the practice of any changes.',
    'confirm_checkbox': 'I confirm that I reviewed my answers.',
    'signed_name': 'Full name as signature',
    'draw_signature': 'Sign inside the box with your finger or stylus',
    'clear_signature': 'Clear',
    'signature_required':
        'Confirm your answers, enter your full name, and sign in the box.',
    'secure_submit_hint':
        'After successful submission, the answers are cleared from the tablet form.',
    'submit_failed':
        'The form could not be submitted. Please call a member of staff.',
  },
  'de': {
    'practice_type': 'Zahnarztpraxis',
    'step': 'Schritt',
    'back': 'Zurück',
    'next': 'Weiter',
    'submit': 'Sicher senden',
    'submitting': 'Wird gesendet…',
    'welcome_title': 'Medizinische Anamnese',
    'welcome_body':
        'Bitte füllen Sie das Formular sorgfältig aus. Nehmen Sie sich die Zeit, die Sie brauchen.',
    'choose_language': 'Sprache wählen',
    'privacy_text':
        'Diese Angaben werden nur für Ihre zahnärztliche Behandlung verwendet und erst beim Tippen auf „Sicher senden“ an die Praxis übermittelt.',
    'gdpr_title': 'Datenschutzhinweis (DSGVO)',
    'privacy_accept':
        'Ich habe den obigen Hinweis gelesen und verstanden und möchte dieses Formular an die Zahnarztpraxis übermitteln.',
    'privacy_required': 'Bitte stimmen Sie dem Hinweis zu, um fortzufahren.',
    'identity_title': 'Persönliche Angaben',
    'required_hint': 'Mit Sternchen (*) markierte Felder sind Pflichtfelder.',
    'family_name': 'Nachname',
    'given_name': 'Vorname',
    'father_name': 'Name des Vaters',
    'date_of_birth': 'Geburtsdatum',
    'date_invalid': 'Geben Sie ein gültiges Datum im Format TT/MM/JJJJ ein.',
    'occupation': 'Beruf',
    'country_of_origin': 'Herkunftsland',
    'identity_required': 'Bitte Nachname, Vorname und Geburtsdatum eingeben.',
    'contact_title': 'Kontakt und Anschrift',
    'contact_hint': 'Bitte geben Sie mindestens eine Kontaktmöglichkeit an.',
    'mobile': 'Mobiltelefon',
    'phone': 'Telefon',
    'email': 'E-Mail',
    'address': 'Anschrift',
    'postal_code': 'Postleitzahl',
    'city': 'Ort',
    'amka': 'AMKA',
    'afm': 'Steuernummer',
    'doy': 'Finanzamt',
    'insurance': 'Versicherung',
    'contact_required': 'Bitte Mobiltelefon, Telefon oder E-Mail angeben.',
    'conditions_title': 'Allergien und Erkrankungen',
    'heart_title': 'Herz-Kreislauf-Anamnese',
    'care_title': 'Medikamente und Lebensweise',
    'answer_every':
        'Wählen Sie für jede Frage eine Antwort. Wenn Sie unsicher sind, wählen Sie „Ich weiß es nicht“.',
    'answers_required': 'Bitte beantworten Sie jede Frage auf dieser Seite.',
    'details_required':
        'Bitte ergänzen Sie die erforderlichen Angaben zu den positiven Antworten.',
    'yes': 'Ja',
    'no': 'Nein',
    'unknown': 'Ich weiß es nicht',
    'kidney': 'Niere',
    'liver': 'Leber',
    'kidney_and_liver': 'Niere und Leber',
    'high_blood_pressure': 'Hoch',
    'low_blood_pressure': 'Niedrig',
    'details_optional': 'Einzelheiten (optional)',
    'antibiotic_allergy_details': 'Welches Antibiotikum und welche Reaktion?',
    'kidney_liver_details': 'Beschreiben Sie die Erkrankung',
    'cigarettes_per_day': 'Zigaretten pro Tag',
    'review_title': 'Prüfen und unterschreiben',
    'review_hint': 'Prüfen Sie die Zusammenfassung vor dem sicheren Senden.',
    'patient': 'Patient/in',
    'yes_answers': 'Antworten „Ja“',
    'none': 'Keine',
    'confirmation_text':
        'Ich erkläre, dass diese Angaben nach bestem Wissen richtig sind, und informiere die Praxis über Änderungen.',
    'confirm_checkbox': 'Ich bestätige, dass ich meine Antworten geprüft habe.',
    'signed_name': 'Vollständiger Name als Unterschrift',
    'draw_signature': 'Unterschreiben Sie im Feld mit Finger oder Stift',
    'clear_signature': 'Löschen',
    'signature_required':
        'Bestätigen Sie die Antworten, geben Sie Ihren Namen ein und unterschreiben Sie im Feld.',
    'secure_submit_hint':
        'Nach erfolgreicher Übermittlung werden die Antworten aus dem Tablet-Formular gelöscht.',
    'submit_failed':
        'Das Formular konnte nicht gesendet werden. Bitte rufen Sie ein Praxismitglied.',
  },
};

String t(String language, String key) =>
    _ui[language]?[key] ?? _ui['en']![key] ?? key;
