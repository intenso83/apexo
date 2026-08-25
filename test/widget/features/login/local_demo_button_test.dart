import 'package:apexo/features/login/login_controller.dart';
import 'package:apexo/features/login/login_screen.dart';
import 'package:apexo/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  testWidgets('login screen offers a clearly labelled local demo',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1080, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    loginCtrl
      ..loadingIndicator('')
      ..loadingPatientSide(false)
      ..loginError('')
      ..selectedTab(0);
    await tester.pump(const Duration(milliseconds: 350));

    await pumpApexoApp(tester, const LoginScreen());

    expect(find.byKey(WK.btnDemo), findsOneWidget);
    expect(find.text('Demo'), findsAtLeastNWidgets(1));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Tooltip &&
            (widget.message ?? '').contains('fake patient data'),
      ),
      findsOneWidget,
    );
  });
}
