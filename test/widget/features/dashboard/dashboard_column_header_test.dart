import 'package:apexo/features/dashboard/dashboard_column_header.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('long Greek dashboard title fits its fixed-width column',
      (tester) async {
    await tester.pumpWidget(
      FluentApp(
        home: Center(
          child: DashboardColumnHeader(
            title: 'Εργαστηριακές εργασίες (Μη παραδοθείσες)',
            icon: FluentIcons.manufacturing,
            onPressed: () {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
