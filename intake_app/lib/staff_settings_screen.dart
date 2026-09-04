import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'form_configuration.dart';
import 'intake_schema.dart';
import 'intake_settings_store.dart';

Future<bool> unlockStaffSettings(
  BuildContext context,
  IntakeSettingsStore store,
) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _PasswordGateDialog(store: store),
      ) ??
      false;
}

class _PasswordGateDialog extends StatefulWidget {
  const _PasswordGateDialog({required this.store});

  final IntakeSettingsStore store;

  @override
  State<_PasswordGateDialog> createState() => _PasswordGateDialogState();
}

class _PasswordGateDialogState extends State<_PasswordGateDialog> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _hidden = true;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final firstUse = !widget.store.hasPassword;
    if (firstUse && _password.text != _confirmation.text) {
      setState(() => _error = 'The two passwords do not match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (firstUse) {
        await widget.store.setInitialPassword(_password.text);
        if (mounted) Navigator.pop(context, true);
        return;
      }
      final result = await widget.store.verifyPassword(_password.text);
      if (!mounted) return;
      if (result.success) {
        Navigator.pop(context, true);
      } else if (result.locked) {
        final seconds = result.lockedUntil!
            .difference(DateTime.now().toUtc())
            .inSeconds
            .clamp(1, 30);
        setState(
          () => _error = 'Too many attempts. Try again in $seconds seconds.',
        );
      } else {
        setState(
          () => _error =
              'Incorrect password. ${result.remainingAttempts} attempts remain.',
        );
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Settings could not be unlocked on this device.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstUse = !widget.store.hasPassword;
    return AlertDialog(
      icon: const Icon(Icons.admin_panel_settings_outlined, size: 36),
      title: Text(firstUse ? 'Protect staff settings' : 'Staff settings'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              firstUse
                  ? 'Create the local password that staff will use to change the patient form. Use at least 8 characters.'
                  : 'Enter the local staff password. Patients cannot open settings after their intake starts.',
            ),
            const SizedBox(height: 18),
            TextField(
              key: const ValueKey('settings_password'),
              controller: _password,
              obscureText: _hidden,
              autofocus: true,
              enableSuggestions: false,
              autocorrect: false,
              onSubmitted: (_) => _busy ? null : _submit(),
              decoration: InputDecoration(
                labelText: firstUse ? 'New settings password' : 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _hidden = !_hidden),
                  icon: Icon(_hidden ? Icons.visibility : Icons.visibility_off),
                ),
              ),
            ),
            if (firstUse) ...[
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('settings_password_confirmation'),
                controller: _confirmation,
                obscureText: _hidden,
                enableSuggestions: false,
                autocorrect: false,
                onSubmitted: (_) => _busy ? null : _submit(),
                decoration: const InputDecoration(
                  labelText: 'Repeat password',
                  prefixIcon: Icon(Icons.lock_reset_outlined),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(firstUse ? 'Create and open' : 'Unlock'),
        ),
      ],
    );
  }
}

class StaffSettingsScreen extends StatefulWidget {
  const StaffSettingsScreen({super.key, required this.store});

  final IntakeSettingsStore store;

  @override
  State<StaffSettingsScreen> createState() => _StaffSettingsScreenState();
}

class _StaffSettingsScreenState extends State<StaffSettingsScreen> {
  late IntakeFormConfiguration _configuration;
  String? _selectedPageId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _configuration = widget.store.configuration.copy();
    _selectedPageId = _configuration.orderedPages.firstOrNull?.id;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.store.saveConfiguration(_configuration);
      if (!mounted) return;
      Navigator.pop(context, widget.store.configuration.copy());
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The form settings could not be saved.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Patient form settings'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.palette_outlined), text: 'Branding'),
              Tab(icon: Icon(Icons.view_carousel_outlined), text: 'Pages'),
              Tab(icon: Icon(Icons.checklist_outlined), text: 'Entries'),
              Tab(icon: Icon(Icons.security_outlined), text: 'Security'),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                key: const ValueKey('save_settings'),
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Save'),
              ),
            ),
          ],
        ),
        body: TabBarView(
          children: [_brandingTab(), _pagesTab(), _itemsTab(), _securityTab()],
        ),
      ),
    );
  }

  Widget _brandingTab() {
    final customPath = _configuration.customLogoPath.trim();
    Widget fallback() => Image.asset(
      'assets/practice_logo.gif',
      width: 130,
      height: 130,
      fit: BoxFit.contain,
    );
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _SettingsExplanation(
          icon: Icons.storefront_outlined,
          text:
              'Choose the logo and practice name shown above every patient page.',
        ),
        Center(
          child: customPath.isEmpty
              ? fallback()
              : Image.file(
                  File(customPath),
                  width: 130,
                  height: 130,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => fallback(),
                ),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              key: const ValueKey('choose_practice_logo'),
              onPressed: _chooseLogo,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose logo'),
            ),
            OutlinedButton.icon(
              onPressed: customPath.isEmpty
                  ? null
                  : () => setState(() => _configuration.customLogoPath = ''),
              icon: const Icon(Icons.restore_outlined),
              label: const Text('Use original logo'),
            ),
          ],
        ),
        const SizedBox(height: 26),
        for (final entry in const [
          ('el', 'Practice name — Greek'),
          ('en', 'Practice name — English'),
          ('de', 'Practice name — German'),
        ]) ...[
          TextFormField(
            key: ValueKey('practice_name_${entry.$1}'),
            initialValue: _configuration.practiceNames[entry.$1],
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: entry.$2),
            onChanged: (value) =>
                _configuration.practiceNames[entry.$1] = value,
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Future<void> _chooseLogo() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (picked == null) return;
      final storedPath = await widget.store.importCustomLogo(picked.path);
      if (!mounted) return;
      setState(() => _configuration.customLogoPath = storedPath);
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The selected logo could not be opened.')),
      );
    }
  }

  Widget _pagesTab() {
    final pages = _configuration.orderedPages;
    return Column(
      children: [
        _SettingsExplanation(
          icon: Icons.drag_indicator,
          text:
              'Drag pages into the patient order. Rename them in Greek, English and German, or add your own. Welcome and final review remain fixed.',
          action: TextButton.icon(
            key: const ValueKey('add_page'),
            onPressed: _addPage,
            icon: const Icon(Icons.add),
            label: const Text('Add page'),
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: pages.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final moved = pages.removeAt(oldIndex);
                pages.insert(newIndex, moved);
                for (var index = 0; index < pages.length; index++) {
                  pages[index].order = index;
                }
              });
            },
            itemBuilder: (context, index) {
              final page = pages[index];
              final canDisable = _configuration.canDisablePage(page);
              final itemCount = _configuration.itemsForPage(page.id).length;
              return Card(
                key: ValueKey('page_${page.id}'),
                child: ListTile(
                  leading: ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.drag_indicator),
                    ),
                  ),
                  title: Text(
                    '${page.title('el')}  /  ${page.title('en')}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '$itemCount visible entries${page.protected ? ' · required page' : ''}',
                  ),
                  onTap: () => _editPage(page),
                  trailing: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (page.custom)
                        IconButton(
                          tooltip: 'Delete empty custom page',
                          onPressed: () => _deletePage(page),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      IconButton(
                        tooltip: 'Rename page',
                        onPressed: () => _editPage(page),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      Switch(
                        value: page.enabled,
                        onChanged: canDisable
                            ? (value) => setState(() => page.enabled = value)
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _itemsTab() {
    final pages = _configuration.orderedPages;
    if (pages.isEmpty) return const SizedBox.shrink();
    if (_selectedPageId == null ||
        !pages.any((page) => page.id == _selectedPageId)) {
      _selectedPageId = pages.first.id;
    }
    final selectedPage = _configuration.pageById(_selectedPageId!)!;
    final items = _configuration.itemsForPage(
      selectedPage.id,
      includeDisabled: true,
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
          child: DropdownButtonFormField<String>(
            key: ValueKey('selected_$_selectedPageId'),
            initialValue: _selectedPageId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Page to edit',
              prefixIcon: Icon(Icons.view_carousel_outlined),
            ),
            items: pages
                .map(
                  (page) => DropdownMenuItem(
                    value: page.id,
                    child: Text(
                      page.title('en'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _selectedPageId = value),
          ),
        ),
        const _SettingsExplanation(
          icon: Icons.touch_app_outlined,
          text:
              'Drag entries to reorder them. Use the page selector on an entry to move it. Optional entries can be switched off.',
        ),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('This page has no entries yet.'))
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
                  itemCount: items.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final moved = items.removeAt(oldIndex);
                      items.insert(newIndex, moved);
                      for (var index = 0; index < items.length; index++) {
                        items[index].order = index;
                      }
                    });
                  },
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final locked = !_configuration.canDisableItem(item);
                    return Card(
                      key: ValueKey('item_${item.kind}_${item.id}'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.drag_indicator),
                            ),
                          ),
                          title: Text(
                            _itemLabel(item),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: DropdownButton<String>(
                              value: item.pageId,
                              isDense: true,
                              isExpanded: true,
                              underline: const SizedBox.shrink(),
                              items: pages
                                  .map(
                                    (page) => DropdownMenuItem(
                                      value: page.id,
                                      child: Text(
                                        'Page: ${page.title('en')}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (pageId) {
                                if (pageId == null || pageId == item.pageId) {
                                  return;
                                }
                                setState(() {
                                  item.pageId = pageId;
                                  item.order = _configuration
                                      .itemsForPage(
                                        pageId,
                                        includeDisabled: true,
                                      )
                                      .length;
                                  _configuration.normalize();
                                });
                              },
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (locked)
                                const Tooltip(
                                  message: 'Required — cannot be switched off',
                                  child: Icon(Icons.lock_outline),
                                ),
                              Switch(
                                value: item.enabled,
                                onChanged: locked
                                    ? null
                                    : (value) {
                                        setState(() {
                                          item.enabled = value;
                                          _configuration.normalize();
                                        });
                                      },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _securityTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Card(
          child: ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('Local staff password'),
            subtitle: Text(
              'The password itself is never stored. Settings lock after five incorrect attempts. There is no patient-accessible recovery route.',
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _changePassword,
          icon: const Icon(Icons.password_outlined),
          label: const Text('Change settings password'),
        ),
        const SizedBox(height: 28),
        OutlinedButton.icon(
          onPressed: _resetConfiguration,
          icon: const Icon(Icons.restart_alt),
          label: const Text('Restore the original page layout'),
        ),
        const SizedBox(height: 10),
        const Text(
          'If the password is forgotten, Android app data must be cleared. That also restores the original form layout.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _itemLabel(IntakeItemConfiguration item) {
    if (item.isField) {
      final definition = intakeFieldsById[item.id];
      if (definition == null) return item.id;
      return '${definition.label('el')}  /  ${definition.label('en')}'
          '${item.mandatory ? '  *' : ''}';
    }
    final question = intakeQuestions
        .where((candidate) => candidate.id == item.id)
        .firstOrNull;
    if (question == null) return item.id;
    return '${question.label('el')}  /  ${question.label('en')}';
  }

  Future<void> _editPage(IntakePageConfiguration page) async {
    final result = await _showPageEditor(page);
    if (result == null || !mounted) return;
    setState(() {
      page.titles = result.$1;
      page.subtitles = result.$2;
    });
  }

  Future<void> _addPage() async {
    final result = await _showPageEditor(null);
    if (result == null || !mounted) return;
    final page = IntakePageConfiguration(
      id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
      titles: result.$1,
      subtitles: result.$2,
      order: _configuration.pages.length,
      custom: true,
    );
    setState(() {
      _configuration.pages.add(page);
      _selectedPageId = page.id;
    });
  }

  Future<(Labels, Labels)?> _showPageEditor(
    IntakePageConfiguration? page,
  ) async {
    final titleControllers = {
      for (final language in const ['el', 'en', 'de'])
        language: TextEditingController(text: page?.titles[language] ?? ''),
    };
    final subtitleControllers = {
      for (final language in const ['el', 'en', 'de'])
        language: TextEditingController(text: page?.subtitles[language] ?? ''),
    };
    final result = await showDialog<(Labels, Labels)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(page == null ? 'Add page' : 'Rename page'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in const [
                  ('el', 'Greek'),
                  ('en', 'English'),
                  ('de', 'German'),
                ]) ...[
                  TextField(
                    controller: titleControllers[entry.$1],
                    decoration: InputDecoration(
                      labelText: '${entry.$2} page title',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: subtitleControllers[entry.$1],
                    minLines: 1,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: '${entry.$2} instruction (optional)',
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final english = titleControllers['en']!.text.trim();
              if (english.isEmpty) return;
              Navigator.pop(dialogContext, (
                {
                  for (final entry in titleControllers.entries)
                    entry.key: entry.value.text.trim().isEmpty
                        ? english
                        : entry.value.text.trim(),
                },
                {
                  for (final entry in subtitleControllers.entries)
                    entry.key: entry.value.text.trim(),
                },
              ));
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    for (final controller in [
      ...titleControllers.values,
      ...subtitleControllers.values,
    ]) {
      controller.dispose();
    }
    return result;
  }

  Future<void> _deletePage(IntakePageConfiguration page) async {
    if (_configuration
        .itemsForPage(page.id, includeDisabled: true)
        .isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Move every entry off this page before deleting it.'),
        ),
      );
      return;
    }
    setState(() {
      _configuration.pages.remove(page);
      _selectedPageId = _configuration.orderedPages.firstOrNull?.id;
      _configuration.normalize();
    });
  }

  Future<void> _changePassword() async {
    final password = TextEditingController();
    final confirmation = TextEditingController();
    String? error;
    final changed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Change settings password'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New password'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmation,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Repeat password',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (password.text != confirmation.text) {
                  setDialogState(() => error = 'The passwords do not match.');
                  return;
                }
                try {
                  await widget.store.changePassword(password.text);
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } on FormatException catch (exception) {
                  setDialogState(() => error = exception.message);
                } catch (_) {
                  setDialogState(
                    () => error = 'The new password could not be saved.',
                  );
                }
              },
              child: const Text('Change'),
            ),
          ],
        ),
      ),
    );
    password.dispose();
    confirmation.dispose();
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings password changed.')),
      );
    }
  }

  Future<void> _resetConfiguration() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore original layout?'),
        content: const Text(
          'Your page order, page names and entry choices will be replaced by the original form layout.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _configuration = IntakeFormConfiguration.defaults();
      _selectedPageId = _configuration.orderedPages.first.id;
    });
  }
}

class _SettingsExplanation extends StatelessWidget {
  const _SettingsExplanation({
    required this.icon,
    required this.text,
    this.action,
  });

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
          ?action,
        ],
      ),
    );
  }
}
