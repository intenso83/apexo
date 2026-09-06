import 'package:apexo/common_widgets/button_styles.dart';
import 'package:apexo/common_widgets/dialogs/dialog_styling.dart';
import 'package:apexo/core/multi_stream_builder.dart';
import 'package:apexo/core/observable.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/appointments/calendar_widget.dart';
import 'package:apexo/features/calendar_sync/google_calendar_connection_controller.dart';
import 'package:apexo/features/calendar_sync/google_calendar_models.dart';
import 'package:apexo/features/expenses/expenses_store.dart';
import 'package:apexo/features/network_actions/network_actions_controller.dart';
import 'package:apexo/features/notes/notes_store.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/features/settings/applies_to_indicator.dart';
import 'package:apexo/features/settings/services_settings/auth_settings.dart';
import 'package:apexo/features/settings/services_settings/backups_settings.dart';
import 'package:apexo/features/settings/services_settings/file_upload_settings.dart';
import 'package:apexo/features/settings/services_settings/meta_settings.dart';
import 'package:apexo/features/settings/services_settings/s3_settings.dart';
import 'package:apexo/features/settings/services_settings/smtp_settings.dart';
import 'package:apexo/services/login.dart';
import 'package:apexo/services/network.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:table_calendar/table_calendar.dart';
import 'settings_model.dart';
import 'settings_stores.dart';
import 'theme_presets.dart';

enum InputType { text, multiline, dropDown, none }

final languagePickersOptions = locale.list
    .map((e) => ComboBoxItem(
        value: locale.list.indexOf(e).toString(), child: Txt(e.$name)))
    .toList();

const supportedCurrencyCodes = <String>[
  'EUR',
  'USD',
  'GBP',
  'CHF',
  'CAD',
  'AUD',
  'JPY',
  'IQD',
  'AED',
  'SAR',
  'TRY',
];

final currencyPickerOptions = supportedCurrencyCodes
    .map((code) => ComboBoxItem(value: code, child: Text(code)))
    .toList();

class ThemePresetOption extends StatelessWidget {
  final ApexoThemePreset preset;

  const ThemePresetOption({
    super.key,
    required this.preset,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = FluentTheme.of(context).inactiveColor.withAlpha(45);
    return Row(
      key: Key('theme_preset_option_${preset.name}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          key: Key('theme_preset_swatches_${preset.name}'),
          mainAxisSize: MainAxisSize.min,
          children: preset.previewColors
              .map(
                (color) => Container(
                  width: 15,
                  height: 15,
                  decoration: BoxDecoration(
                    color: color,
                    border: Border.all(color: borderColor),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(width: 9),
        Txt(txt(preset.labelKey)),
      ],
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final googleCalendarAccountId = login.currentAccountID.isNotEmpty
        ? login.currentAccountID
        : login.email;
    GoogleCalendarUserSettings googleCalendarUserSettings() =>
        localSettings.googleCalendarForUser(googleCalendarAccountId);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: ListView(
        children: [
          _SettingsGroup(
            key: const Key('clinic_settings_group'),
            title: txt('clinicSettingsGroup'),
            description: txt('clinicSettingsGroup_desc'),
            icon: FluentIcons.medical,
            children: login.isAdmin
                ? [
                    SettingsItem(
                      title: txt("currency"),
                      identifier: "currency",
                      description: txt("currency_desc"),
                      icon: FluentIcons.all_currency,
                      inputType: InputType.dropDown,
                      scope: Scope.app,
                      options: currencyPickerOptions,
                      initValue: globalSettings.get("currency_______").value,
                      apply: (newVal) => globalSettings.set(Setting.fromJson(
                          {"id": "currency_______", "value": newVal})),
                    ),
                    SettingsItem(
                      title: txt("countryCode"),
                      identifier: "ISO_country____",
                      description: txt("countryCode_desc"),
                      icon: FluentIcons.globe,
                      inputType: InputType.text,
                      scope: Scope.app,
                      initValue: globalSettings.get("ISO_country____").value,
                      apply: (newVal) => globalSettings.set(Setting.fromJson(
                          {"id": "ISO_country____", "value": newVal})),
                    ),
                    SettingsItem(
                      title: txt("prescriptionFooter"),
                      identifier: "prescriptionFot",
                      description: txt("prescriptionFooter_desc"),
                      icon: FluentIcons.footer,
                      inputType: InputType.text,
                      scope: Scope.app,
                      initValue: globalSettings.get("prescriptionFot").value,
                      apply: (newVal) => globalSettings.set(Setting.fromJson(
                          {"id": "prescriptionFot", "value": newVal})),
                    ),
                    SettingsItem(
                      title: txt("phone"),
                      identifier: "phone",
                      description: txt("phone_desc"),
                      icon: WindowsIcons.phone,
                      inputType: InputType.multiline,
                      scope: Scope.app,
                      initValue: globalSettings.get("phone__________").value,
                      apply: (newVal) => globalSettings.set(Setting.fromJson(
                          {"id": "phone__________", "value": newVal})),
                    ),
                  ]
                : [
                    InfoBar(
                      title: Text(txt('managedByAdministrator')),
                      severity: InfoBarSeverity.info,
                    ),
                  ],
          ),
          SettingsItem(
            title: txt("language"),
            identifier: "language",
            description: txt("language_desc"),
            icon: WindowsIcons.locale_language,
            inputType: InputType.dropDown,
            scope: Scope.device,
            options: languagePickersOptions,
            initValue: localSettings.selectedLocale.toString(),
            apply: (newVal) {
              localSettings.selectedLocale = int.parse(newVal);
              localSettings.notifyAndPersist();
              networkActions.resync();
            },
          ),
          _SettingsGroup(
            key: const Key('appearance_settings_group'),
            title: txt('appearanceSettingsGroup'),
            description: txt('appearanceSettingsGroup_desc'),
            icon: FluentIcons.color,
            children: [
              SettingsItem(
                title: txt('themePreset'),
                identifier: 'themePreset',
                description: txt('themePreset_desc'),
                icon: FluentIcons.color_solid,
                inputType: InputType.dropDown,
                scope: Scope.device,
                options: ApexoThemePreset.values
                    .map(
                      (preset) => ComboBoxItem(
                        value: preset.name,
                        child: ThemePresetOption(preset: preset),
                      ),
                    )
                    .toList(),
                initValue: localSettings.themePreset.name,
                apply: (newVal) {
                  localSettings.themePreset = themePresetFromId(newVal);
                  localSettings.notifyAndPersist();
                },
              ),
            ],
          ),
          _SettingsGroup(
            key: const Key('calendar_settings_group'),
            title: txt('calendarSettingsGroup'),
            description: txt('calendarSettingsGroup_desc'),
            icon: FluentIcons.calendar,
            children: [
              if (login.isAdmin)
                SettingsItem(
                  title: txt("startingDayOfWeek"),
                  identifier: "startingDayOfWeek",
                  description: txt("startingDayOfWeek_desc"),
                  icon: FluentIcons.hazy_day,
                  inputType: InputType.dropDown,
                  scope: Scope.app,
                  options: StartingDayOfWeek.values
                      .map((e) =>
                          ComboBoxItem(value: e.name, child: Txt(txt(e.name))))
                      .toList(),
                  initValue: globalSettings.get("start_day_of_wk").value,
                  apply: (newVal) => globalSettings.set(Setting.fromJson(
                      {"id": "start_day_of_wk", "value": newVal})),
                ),
              SettingsItem(
                title: txt("dateFormat"),
                identifier: "dateFormat",
                description: txt("dateFormat_desc"),
                icon: WindowsIcons.date_time,
                inputType: InputType.dropDown,
                scope: Scope.device,
                options: [
                  ComboBoxItem(
                    value: "MM/dd/yyyy",
                    child: Txt(txt("month/day/year")),
                  ),
                  ComboBoxItem(
                    value: "dd/MM/yyyy",
                    child: Txt(txt("day/month/year")),
                  ),
                ],
                initValue: localSettings.dateFormat,
                apply: (newVal) {
                  localSettings.dateFormat = newVal;
                  localSettings.notifyAndPersist();
                },
              ),
              SettingsItem(
                title: txt("calendarView"),
                identifier: "calendarView",
                description: txt("calendarView_desc"),
                icon: WindowsIcons.calendar_day,
                inputType: InputType.dropDown,
                scope: Scope.device,
                options: EventsViewMode.values
                    .map((e) => ComboBoxItem(
                        value: e.index.toString(), child: Txt(txt(e.name))))
                    .toList(),
                initValue:
                    localSettings.calendarEventsViewMode.index.toString(),
                apply: (newVal) {
                  localSettings.calendarEventsViewMode =
                      EventsViewMode.values[int.tryParse(newVal) ?? 0];
                  localSettings.notifyAndPersist();
                },
              ),
              if (login.isAdmin)
                SettingsItem(
                  title: txt("googleCalendarAvailable"),
                  identifier: "gcal_enabled___",
                  description: txt("googleCalendarAvailable_desc"),
                  icon: FluentIcons.calendar,
                  inputType: InputType.dropDown,
                  scope: Scope.app,
                  options: [
                    ComboBoxItem(value: "1", child: Txt(txt("on"))),
                    ComboBoxItem(value: "0", child: Txt(txt("off"))),
                  ],
                  initValue:
                      globalSettings.googleCalendarSyncEnabled ? "1" : "0",
                  apply: (newVal) => globalSettings.set(Setting.fromJson(
                    {"id": "gcal_enabled___", "value": newVal},
                  )),
                ),
              if (login.isAdmin)
                SettingsItem(
                  title: txt("googleCalendarClientId"),
                  identifier: "gcal_client_id_",
                  description: txt("googleCalendarClientId_desc"),
                  icon: FluentIcons.calendar,
                  inputType: InputType.text,
                  scope: Scope.app,
                  initValue: globalSettings.googleCalendarClientId,
                  apply: (newVal) => globalSettings.set(Setting.fromJson(
                      {"id": "gcal_client_id_", "value": newVal.trim()})),
                  footer: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: InfoBar(
                      severity: InfoBarSeverity.info,
                      title: Txt(txt("googleCalendarFoundationStatus")),
                      content: Txt(txt("googleCalendarPrivacyNotice")),
                    ),
                  ),
                ),
              SettingsItem(
                key: ValueKey("gcal_account_$googleCalendarAccountId"),
                title: txt("googleCalendarAccount"),
                identifier: "gcal_account_$googleCalendarAccountId",
                description: txt("googleCalendarAccount_desc"),
                icon: FluentIcons.contact,
                inputType: InputType.none,
                scope: Scope.device,
                initValue: "",
                apply: (_) {},
                footer: GoogleCalendarConnectionPanel(
                  accountId: googleCalendarAccountId,
                ),
              ),
              SettingsItem(
                key: ValueKey("gcal_user_enabled_$googleCalendarAccountId"),
                title: txt("googleCalendarUserEnabled"),
                identifier: "gcal_user_enabled_$googleCalendarAccountId",
                description: txt("googleCalendarUserEnabled_desc"),
                icon: FluentIcons.sync_status,
                inputType: InputType.dropDown,
                scope: Scope.device,
                options: [
                  ComboBoxItem(value: "1", child: Txt(txt("on"))),
                  ComboBoxItem(value: "0", child: Txt(txt("off"))),
                ],
                initValue: googleCalendarUserSettings().syncEnabled ? "1" : "0",
                apply: (newVal) => localSettings.setGoogleCalendarForUser(
                  googleCalendarAccountId,
                  googleCalendarUserSettings()
                      .copyWith(syncEnabled: newVal == "1"),
                ),
              ),
              SettingsItem(
                key: ValueKey("gcal_auto_sync_$googleCalendarAccountId"),
                title: txt("googleCalendarAutoSync"),
                identifier: "gcal_auto_sync_$googleCalendarAccountId",
                description: txt("googleCalendarAutoSync_desc"),
                icon: FluentIcons.timer,
                inputType: InputType.dropDown,
                scope: Scope.device,
                options: [
                  ComboBoxItem(
                    value: "0",
                    child: Txt(txt("googleCalendarAutoSyncOff")),
                  ),
                  ComboBoxItem(
                    value: "5",
                    child: Txt(txt("googleCalendarAutoSync5")),
                  ),
                  ComboBoxItem(
                    value: "15",
                    child: Txt(txt("googleCalendarAutoSync15")),
                  ),
                  ComboBoxItem(
                    value: "30",
                    child: Txt(txt("googleCalendarAutoSync30")),
                  ),
                ],
                initValue: googleCalendarUserSettings()
                    .autoSyncDelaySeconds
                    .toString(),
                apply: (newVal) => localSettings.setGoogleCalendarForUser(
                  googleCalendarAccountId,
                  googleCalendarUserSettings().copyWith(
                    autoSyncDelaySeconds: int.tryParse(newVal) ?? 5,
                  ),
                ),
              ),
              SettingsItem(
                key: ValueKey("gcal_calendar_$googleCalendarAccountId"),
                title: txt("googleCalendarId"),
                identifier: "gcal_calendar_$googleCalendarAccountId",
                description: txt("googleCalendarId_desc"),
                icon: FluentIcons.calendar,
                inputType: InputType.text,
                scope: Scope.device,
                initValue: googleCalendarUserSettings().calendarId,
                apply: (newVal) => localSettings.setGoogleCalendarForUser(
                  googleCalendarAccountId,
                  googleCalendarUserSettings().copyWith(
                    calendarId:
                        newVal.trim().isEmpty ? "primary" : newVal.trim(),
                  ),
                ),
              ),
              SettingsItem(
                key: ValueKey("gcal_direction_$googleCalendarAccountId"),
                title: txt("googleCalendarDirection"),
                identifier: "gcal_direction_$googleCalendarAccountId",
                description: txt("googleCalendarDirection_desc"),
                icon: FluentIcons.sync,
                inputType: InputType.dropDown,
                scope: Scope.device,
                options: [
                  ComboBoxItem(
                    value: "twoWay",
                    child: Txt(txt("googleCalendarTwoWay")),
                  ),
                  ComboBoxItem(
                    value: "apexoToGoogle",
                    child: Txt(txt("googleCalendarOneWay")),
                  ),
                ],
                initValue: googleCalendarUserSettings().direction.name,
                apply: (newVal) => localSettings.setGoogleCalendarForUser(
                  googleCalendarAccountId,
                  googleCalendarUserSettings().copyWith(
                    direction: GoogleCalendarSyncDirection.parse(newVal),
                  ),
                ),
              ),
              SettingsItem(
                key: ValueKey("gcal_busy_blocks_$googleCalendarAccountId"),
                title: txt("googleCalendarBusyBlocks"),
                identifier: "gcal_busy_blocks_$googleCalendarAccountId",
                description: txt("googleCalendarBusyBlocks_desc"),
                icon: FluentIcons.calendar_week,
                inputType: InputType.dropDown,
                scope: Scope.device,
                options: [
                  ComboBoxItem(value: "1", child: Txt(txt("on"))),
                  ComboBoxItem(value: "0", child: Txt(txt("off"))),
                ],
                initValue: googleCalendarUserSettings().showGoogleBusyBlocks
                    ? "1"
                    : "0",
                apply: (newVal) => localSettings.setGoogleCalendarForUser(
                  googleCalendarAccountId,
                  googleCalendarUserSettings().copyWith(
                    showGoogleBusyBlocks: newVal == "1",
                  ),
                ),
              ),
              SettingsItem(
                key: ValueKey("gcal_scope_$googleCalendarAccountId"),
                title: txt("googleCalendarAppointmentScope"),
                identifier: "gcal_scope_$googleCalendarAccountId",
                description: txt("googleCalendarAppointmentScope_desc"),
                icon: FluentIcons.people,
                inputType: InputType.dropDown,
                scope: Scope.device,
                options: [
                  ComboBoxItem(
                    value: "automatic",
                    child: Txt(txt("googleCalendarScopeAutomatic")),
                  ),
                  ComboBoxItem(
                    value: "assignedToMe",
                    child: Txt(txt("googleCalendarScopeAssigned")),
                  ),
                  ComboBoxItem(
                    value: "allAppointments",
                    child: Txt(txt("googleCalendarScopeAll")),
                  ),
                ],
                initValue: googleCalendarUserSettings().appointmentScope.name,
                apply: (newVal) => localSettings.setGoogleCalendarForUser(
                  googleCalendarAccountId,
                  googleCalendarUserSettings().copyWith(
                    appointmentScope:
                        GoogleCalendarAppointmentScope.parse(newVal),
                  ),
                ),
              ),
              SettingsItem(
                key: ValueKey("gcal_title_$googleCalendarAccountId"),
                title: txt("googleCalendarTitleMode"),
                identifier: "gcal_title_$googleCalendarAccountId",
                description: txt("googleCalendarTitleMode_desc"),
                icon: FluentIcons.protection_center_logo32,
                inputType: InputType.dropDown,
                scope: Scope.device,
                options: [
                  ComboBoxItem(
                    value: "generic",
                    child: Txt(txt("googleCalendarGenericTitle")),
                  ),
                  ComboBoxItem(
                    value: "patientName",
                    child: Txt(txt("googleCalendarPatientTitle")),
                  ),
                ],
                initValue: googleCalendarUserSettings().titleMode.name,
                apply: (newVal) => localSettings.setGoogleCalendarForUser(
                  googleCalendarAccountId,
                  googleCalendarUserSettings().copyWith(
                    titleMode: GoogleCalendarTitleMode.parse(newVal),
                  ),
                ),
              ),
              SettingsItem(
                key: ValueKey("gcal_contact_phone_$googleCalendarAccountId"),
                title: txt("googleCalendarIncludePhone"),
                identifier: "gcal_contact_phone_$googleCalendarAccountId",
                description: txt("googleCalendarContactPrivacy_desc"),
                icon: FluentIcons.phone,
                inputType: InputType.dropDown,
                scope: Scope.device,
                options: [
                  ComboBoxItem(value: "1", child: Txt(txt("on"))),
                  ComboBoxItem(value: "0", child: Txt(txt("off"))),
                ],
                initValue:
                    googleCalendarUserSettings().includePhone ? "1" : "0",
                apply: (newVal) => localSettings.setGoogleCalendarForUser(
                  googleCalendarAccountId,
                  googleCalendarUserSettings().copyWith(
                    includePhone: newVal == "1",
                  ),
                ),
              ),
              SettingsItem(
                key: ValueKey("gcal_contact_mobile_$googleCalendarAccountId"),
                title: txt("googleCalendarIncludeMobile"),
                identifier: "gcal_contact_mobile_$googleCalendarAccountId",
                description: txt("googleCalendarContactPrivacy_desc"),
                icon: FluentIcons.cell_phone,
                inputType: InputType.dropDown,
                scope: Scope.device,
                options: [
                  ComboBoxItem(value: "1", child: Txt(txt("on"))),
                  ComboBoxItem(value: "0", child: Txt(txt("off"))),
                ],
                initValue:
                    googleCalendarUserSettings().includeMobile ? "1" : "0",
                apply: (newVal) => localSettings.setGoogleCalendarForUser(
                  googleCalendarAccountId,
                  googleCalendarUserSettings().copyWith(
                    includeMobile: newVal == "1",
                  ),
                ),
              ),
              SettingsItem(
                key: ValueKey("gcal_contact_email_$googleCalendarAccountId"),
                title: txt("googleCalendarIncludeEmail"),
                identifier: "gcal_contact_email_$googleCalendarAccountId",
                description: txt("googleCalendarContactPrivacy_desc"),
                icon: FluentIcons.mail,
                inputType: InputType.dropDown,
                scope: Scope.device,
                options: [
                  ComboBoxItem(value: "1", child: Txt(txt("on"))),
                  ComboBoxItem(value: "0", child: Txt(txt("off"))),
                ],
                initValue:
                    googleCalendarUserSettings().includeEmail ? "1" : "0",
                apply: (newVal) => localSettings.setGoogleCalendarForUser(
                  googleCalendarAccountId,
                  googleCalendarUserSettings().copyWith(
                    includeEmail: newVal == "1",
                  ),
                ),
              ),
              SettingsItem(
                key: ValueKey("gcal_contact_address_$googleCalendarAccountId"),
                title: txt("googleCalendarIncludeAddress"),
                identifier: "gcal_contact_address_$googleCalendarAccountId",
                description: txt("googleCalendarContactPrivacy_desc"),
                icon: FluentIcons.map_pin,
                inputType: InputType.dropDown,
                scope: Scope.device,
                options: [
                  ComboBoxItem(value: "1", child: Txt(txt("on"))),
                  ComboBoxItem(value: "0", child: Txt(txt("off"))),
                ],
                initValue:
                    googleCalendarUserSettings().includeAddress ? "1" : "0",
                apply: (newVal) => localSettings.setGoogleCalendarForUser(
                  googleCalendarAccountId,
                  googleCalendarUserSettings().copyWith(
                    includeAddress: newVal == "1",
                  ),
                ),
              ),
              SettingsItem(
                title: txt("calendarSystem"),
                identifier: "calendarSystem",
                description: txt("calendarSystem_desc"),
                icon: WindowsIcons.calendar,
                inputType: InputType.dropDown,
                scope: Scope.device,
                options: [
                  ComboBoxItem(
                    value: "gregorian",
                    child: Txt(txt("gregorian")),
                  ),
                  ComboBoxItem(
                    value: "persian",
                    child: Txt(txt("persian")),
                  ),
                ],
                initValue: localSettings.calendarSystem,
                apply: (newVal) {
                  localSettings.calendarSystem = newVal;
                  localSettings.notifyAndPersist();
                },
              ),
            ],
          ),
          SettingsItem(
            title: txt("dentalNotation"),
            identifier: "dentalNotation",
            description: txt("dentalNotation_desc"),
            icon: FluentIcons.teeth,
            inputType: InputType.dropDown,
            scope: Scope.device,
            options: [
              ComboBoxItem(
                value: "p",
                child: Txt(txt("palmer")),
              ),
              ComboBoxItem(
                value: "u",
                child: Txt(txt("universal")),
              ),
              ComboBoxItem(
                value: "i",
                child: Txt(txt("iso")),
              ),
            ],
            initValue: localSettings.dentalNotation,
            apply: (newVal) {
              localSettings.dentalNotation = newVal;
              localSettings.notifyAndPersist();
            },
          ),
          if (login.isAdmin)
            SettingsItem(
              title: txt("ai_services"),
              identifier: "ai_services_ena",
              description: txt("ai_services_desc"),
              icon: FluentIcons.lightbulb,
              inputType: InputType.dropDown,
              scope: Scope.app,
              options: [
                ComboBoxItem(value: "1", child: Txt(txt("on"))),
                ComboBoxItem(value: "0", child: Txt(txt("off"))),
              ],
              footer: InfoBar(title: Txt(txt("no_training_privacy_info"))),
              initValue: globalSettings.get("ai_services_ena").value,
              apply: (newVal) => globalSettings.set(
                  Setting.fromJson({"id": "ai_services_ena", "value": newVal})),
            ),
          if (globalSettings.get("ai_services_ena").value == "1")
            SettingsItem(
              title: txt("audioTranscriptionLocale"),
              identifier: "audioTranscriptionLocale",
              description: txt("audioTranscriptionLocale_desc"),
              icon: WindowsIcons.microphone,
              inputType: InputType.dropDown,
              scope: Scope.device,
              options: [
                ComboBoxItem(value: "", child: Txt(txt("sameAsAppLanguage"))),
                ...languagePickersOptions
              ],
              initValue: localSettings.transcriptionLocaleNonFinal,
              apply: (newVal) {
                localSettings.transcriptionLocaleNonFinal = newVal;
                localSettings.notifyAndPersist();
              },
            ),
          if (network.isOnline())
            SettingsItem(
              title: txt("cacheReset"),
              identifier: "cacheReset",
              description: txt("cacheReset_desc"),
              icon: FluentIcons.offline_storage,
              inputType: InputType.none,
              scope: Scope.device,
              initValue: "",
              apply: (_) {},
              footer: FilledButton(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(FluentIcons.offline_storage),
                      const SizedBox(width: 10),
                      Txt(txt("cacheReset"))
                    ],
                  ),
                  onPressed: () async {
                    showDialog(
                        context: context,
                        barrierDismissible: false,
                        dismissWithEsc: false,
                        builder: (context) {
                          return ContentDialog(
                            title: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [Txt(txt("cacheReset"))]),
                            content: StreamBuilder(
                                stream: cacheResetState.stream,
                                builder: (context, _) {
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    spacing: 10,
                                    children: [
                                      if (!cacheResetState()
                                          .startsWith("Error"))
                                        const Center(child: ProgressRing()),
                                      Center(child: Txt(cacheResetState())),
                                      if (cacheResetState().startsWith("Error"))
                                        FilledButton(
                                            child: Txt(txt("close")),
                                            onPressed: () =>
                                                Navigator.pop(context)),
                                    ],
                                  );
                                }),
                            style: dialogStyling(context, false, true),
                          );
                        });

                    try {
                      cacheResetState(txt("initialSynchronization"));
                      await networkActions.resync();
                      cacheResetState(txt("clearingLocalData"));
                      await patients.local!.clear();
                      await appointments.local!.clear();
                      await expenses.local!.clear();
                      await notes.local!.clear();
                      await globalSettings.local!.clear();
                      cacheResetState(txt("synchronizing"));
                      await networkActions.resync();
                    } catch (e, s) {
                      cacheResetState("Error: $e\n$s");
                      return;
                    }
                    if (context.mounted) Navigator.of(context).pop();
                  }),
            ),
          _SettingsGroup(
            key: const Key('administration_settings_group'),
            title: txt('administrationSettingsGroup'),
            description: txt('administrationSettingsGroup_desc'),
            icon: FluentIcons.admin,
            children: login.isAdmin && network.isOnline()
                ? const [
                    MetaSettings(),
                    AuthSettings(),
                    FileUploadSettings(),
                    S3Settings(),
                    SmtpSettings(),
                    BackupsSettings(),
                  ]
                : [
                    InfoBar(
                      title: Text(txt('managedByAdministrator')),
                      severity: InfoBarSeverity.info,
                    ),
                  ],
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final List<Widget> children;

  const _SettingsGroup({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Expander(
        leading: Icon(icon),
        header: Txt(title),
        content: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                child: Txt(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class GoogleCalendarConnectionPanel extends StatelessWidget {
  final String accountId;

  const GoogleCalendarConnectionPanel({
    super.key,
    required this.accountId,
  });

  @override
  Widget build(BuildContext context) {
    return MStreamBuilder(
      streams: [
        googleCalendarConnectionController.state.stream,
        localSettings.stream,
        globalSettings.observableMap.stream,
        appointments.observableMap.stream,
      ],
      builder: (context, _) {
        final saved = localSettings.googleCalendarForUser(accountId);
        final runtime = googleCalendarConnectionController.state();
        final isCurrentRuntime = runtime.accountId == accountId;
        final active =
            googleCalendarConnectionController.hasActiveSession(accountId);
        final busy = isCurrentRuntime && runtime.isBusy;
        final configured = globalSettings.googleCalendarSyncEnabled &&
            globalSettings.googleCalendarClientId.trim().isNotEmpty;
        final syncsAll =
            googleCalendarConnectionController.syncsAllAppointments(accountId);
        final eligibleCount =
            googleCalendarConnectionController.syncAppointmentCount(accountId);
        final message = isCurrentRuntime && runtime.message.isNotEmpty
            ? runtime.message
            : saved.isConnected
                ? (active
                    ? txt("googleCalendarSessionActive")
                    : txt("googleCalendarReconnectRequired"))
                : txt("googleCalendarConnectReady");
        final isError = isCurrentRuntime &&
            runtime.phase == GoogleCalendarConnectionPhase.error;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoBar(
              severity: isError
                  ? InfoBarSeverity.error
                  : active
                      ? InfoBarSeverity.success
                      : InfoBarSeverity.info,
              title: Txt(
                saved.isConnected
                    ? saved.googleAccountEmail
                    : txt("googleCalendarNotConnected"),
              ),
              content: Txt(message),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  key: const Key("google_calendar_connect_button"),
                  onPressed: busy || !configured
                      ? null
                      : () => googleCalendarConnectionController.connect(
                            accountId: accountId,
                            clientId: globalSettings.googleCalendarClientId,
                          ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (busy &&
                          runtime.phase ==
                              GoogleCalendarConnectionPhase.authorizing)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: ProgressRing(strokeWidth: 2),
                        )
                      else
                        const Icon(FluentIcons.plug_connected),
                      const SizedBox(width: 7),
                      Txt(saved.isConnected
                          ? txt("googleCalendarReconnect")
                          : txt("googleCalendarConnect")),
                    ],
                  ),
                ),
                FilledButton(
                  key: const Key("google_calendar_sync_button"),
                  onPressed: busy || !configured || !saved.syncEnabled
                      ? null
                      : () => googleCalendarConnectionController.syncNow(
                            accountId: accountId,
                            clientId: globalSettings.googleCalendarClientId,
                          ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (busy &&
                          runtime.phase ==
                              GoogleCalendarConnectionPhase.syncing)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: ProgressRing(strokeWidth: 2),
                        )
                      else
                        const Icon(FluentIcons.sync),
                      const SizedBox(width: 7),
                      Txt(txt("googleCalendarSyncNow")),
                    ],
                  ),
                ),
                if (saved.isConnected)
                  Button(
                    key: const Key("google_calendar_disconnect_button"),
                    onPressed: busy
                        ? null
                        : () => googleCalendarConnectionController
                            .disconnect(accountId),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(FluentIcons.plug_disconnected),
                        const SizedBox(width: 7),
                        Txt(txt("googleCalendarDisconnect")),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Txt(
              txt(syncsAll
                      ? "googleCalendarAllAppointments"
                      : "googleCalendarAssignedOnly")
                  .replaceAll("{count}", eligibleCount.toString()),
              style: const TextStyle(fontSize: 12),
            ),
            if (saved.lastSuccessfulSync != null) ...[
              const SizedBox(height: 4),
              Txt(
                "${txt("googleCalendarLastSync")}: "
                "${saved.lastSuccessfulSync!.toLocal()}",
                style: const TextStyle(fontSize: 12),
              ),
            ],
            if (!configured) ...[
              const SizedBox(height: 8),
              InfoBar(
                severity: InfoBarSeverity.warning,
                title: Txt(txt("googleCalendarSetupRequired")),
                content: Txt(txt("googleCalendarSetupRequired_desc")),
              ),
            ],
          ],
        );
      },
    );
  }
}

class SettingsItem extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final InputType inputType;
  final String identifier;
  final Scope scope;
  final List<ComboBoxItem<String>> options;
  final Widget? footer;
  final String initValue;
  final Function(String newVal) apply;
  final bool initiallyExpanded;

  const SettingsItem({
    super.key,
    required this.identifier,
    required this.title,
    required this.description,
    required this.icon,
    required this.inputType,
    required this.scope,
    required this.initValue,
    required this.apply,
    this.initiallyExpanded = false,
    this.options = const [],
    this.footer,
  });

  @override
  State<StatefulWidget> createState() => SettingsItemState();
}

class SettingsItemState extends State<SettingsItem> {
  final TextEditingController _controller = TextEditingController();
  String value = "";

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initValue;
    value = widget.initValue;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Expander(
        leading: Icon(widget.icon),
        header: Txt(widget.title),
        content: SizedBox(
          width: 400,
          child: MStreamBuilder(
              streams: [
                globalSettings.observableMap.stream,
                localSettings.stream
              ],
              builder: (context, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.inputType == InputType.text ||
                        widget.inputType == InputType.multiline)
                      CupertinoTextField(
                        key: Key("${widget.identifier}_text_field"),
                        controller: _controller,
                        onChanged: (value) {
                          final currentPosition = _controller.selection;
                          setState(() => _controller.text = value);
                          _controller.selection = currentPosition;
                        },
                        maxLines:
                            widget.inputType == InputType.multiline ? 1 : null,
                        placeholder: txt(widget.title),
                      )
                    else if (widget.inputType == InputType.dropDown)
                      ComboBox<String>(
                        key: Key("${widget.identifier}_combo"),
                        items: widget.options,
                        onChanged: (value) => setState(() =>
                            value != null ? _controller.text = value : null),
                        value: _controller.text,
                      ),
                    const SizedBox(height: 5),
                    Txt(widget.description,
                        style: const TextStyle(
                            fontSize: 12, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 10),
                    if (_controller.text != value) buildSaveCancelButtons(),
                    if (widget.footer != null) widget.footer!,
                  ],
                );
              }),
        ),
        initiallyExpanded: widget.initiallyExpanded,
        trailing: AppliesToIndicator(scope: widget.scope),
      ),
    );
  }

  Row buildSaveCancelButtons() {
    return Row(
      children: [
        FilledButton(
          onPressed: () {
            setState(() {
              widget.apply(_controller.text);
              value = _controller.text;
            });
          },
          child: Row(children: [
            const Icon(WindowsIcons.save),
            const SizedBox(width: 10),
            Txt(txt("save")),
          ]),
        ),
        const SizedBox(width: 10),
        FilledButton(
          style: greyButtonStyle,
          onPressed: () {
            setState(() {
              _controller.text = widget.initValue;
            });
          },
          child: Row(children: [
            const Icon(WindowsIcons.cancel),
            const SizedBox(width: 10),
            Txt(txt("cancel")),
          ]),
        ),
      ],
    );
  }
}

final cacheResetState = ObservableState("");
