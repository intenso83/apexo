import 'package:apexo/core/multi_stream_builder.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/calendar_sync/google_calendar_connection_controller.dart';
import 'package:apexo/features/settings/settings_stores.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/services/login.dart';
import 'package:fluent_ui/fluent_ui.dart';

class CalendarGoogleSyncButton extends StatelessWidget {
  const CalendarGoogleSyncButton({super.key});

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
        final accountId = login.currentAccountID;
        final saved = localSettings.googleCalendarForUser(accountId);
        final runtime = googleCalendarConnectionController.state();
        final busy = runtime.accountId == accountId && runtime.isBusy;
        final configured = globalSettings.googleCalendarSyncEnabled &&
            globalSettings.googleCalendarClientId.trim().isNotEmpty;
        final syncsAll =
            googleCalendarConnectionController.syncsAllAppointments(accountId);
        final eligibleCount =
            googleCalendarConnectionController.syncAppointmentCount(accountId);
        final unassignedCount = appointments.present.values
            .where((appointment) => appointment.operatorsIDs.isEmpty)
            .length;
        final warning = !syncsAll && eligibleCount == 0 && unassignedCount > 0
            ? txt('googleCalendarUnassignedWarning')
                .replaceAll('{count}', unassignedCount.toString())
            : '';
        final tooltip = !configured
            ? txt('googleCalendarSetupRequired_desc')
            : !saved.syncEnabled
                ? txt('googleCalendarUserEnabled_desc')
                : warning.isNotEmpty
                    ? warning
                    : txt(syncsAll
                            ? 'googleCalendarAllAppointments'
                            : 'googleCalendarAssignedOnly')
                        .replaceAll('{count}', eligibleCount.toString());

        return Tooltip(
          message: tooltip,
          child: FilledButton(
            key: const Key('calendar_google_sync_button'),
            onPressed: busy || !configured || !saved.syncEnabled
                ? null
                : () => _sync(
                      context,
                      accountId: accountId,
                      eligibleCount: eligibleCount,
                      warning: warning,
                    ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: ProgressRing(strokeWidth: 2),
                  )
                else
                  const Icon(FluentIcons.sync, size: 14),
                const SizedBox(width: 7),
                Txt(txt('googleCalendarSyncNow')),
                const SizedBox(width: 7),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: warning.isEmpty
                        ? Colors.white.withValues(alpha: 0.22)
                        : Colors.orange.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    eligibleCount.toString(),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _sync(
    BuildContext context, {
    required String accountId,
    required int eligibleCount,
    required String warning,
  }) async {
    await googleCalendarConnectionController.syncNow(
      accountId: accountId,
      clientId: globalSettings.googleCalendarClientId,
    );
    if (!context.mounted) return;

    final runtime = googleCalendarConnectionController.state();
    final isError = runtime.phase == GoogleCalendarConnectionPhase.error;
    final content = [
      if (runtime.message.isNotEmpty) runtime.message,
      if (warning.isNotEmpty) warning,
    ].join('\n');
    displayInfoBar(
      context,
      builder: (_, close) => InfoBar(
        title: Txt(
          isError
              ? txt('error')
              : '${txt('googleCalendarSyncNow')} ($eligibleCount)',
        ),
        content: Text(content),
        severity: isError
            ? InfoBarSeverity.error
            : warning.isNotEmpty
                ? InfoBarSeverity.warning
                : InfoBarSeverity.success,
        onClose: close,
      ),
    );
  }
}
