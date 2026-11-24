import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxos/app/taxos_app.dart';

void main() {
  testWidgets('starts in Arabic and uses right-to-left direction', (tester) async {
    await tester.pumpWidget(const TaxOSApp());

    expect(find.text('لوحة المكتب'), findsOneWidget);
    expect(find.text('بيانات تجريبية'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('لوحة المكتب'))),
      TextDirection.rtl,
    );
  });

  testWidgets('opens the clients destination', (tester) async {
    await tester.pumpWidget(const TaxOSApp());

    await tester.tap(find.byKey(const ValueKey('nav_clients')));
    await tester.pumpAndSettle();

    expect(find.text('سجل العملاء والملفات الضريبية'), findsOneWidget);
  });

  testWidgets('switches to English and left-to-right direction', (tester) async {
    await tester.pumpWidget(const TaxOSApp());

    await tester.tap(find.byKey(const ValueKey('toggle_locale')));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('Dashboard'))),
      TextDirection.ltr,
    );
  });
}
