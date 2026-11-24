import 'package:material_ui/material_ui.dart';
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
    expect(find.textContaining('المحاسب المسؤول عن العميل: أحمد حسن'), findsOneWidget);
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
  testWidgets('creates a client in the local demo registry', (tester) async {
    await tester.pumpWidget(const TaxOSApp());

    await tester.tap(find.byKey(const ValueKey('nav_clients')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add_client')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'شركة الاختبار');
    await tester.tap(find.byKey(const ValueKey('save_client')));
    await tester.pumpAndSettle();

    expect(find.text('شركة الاختبار'), findsOneWidget);
  });

  testWidgets('opens the office tasks destination', (tester) async {
    await tester.pumpWidget(const TaxOSApp());

    await tester.tap(find.byKey(const ValueKey('nav_tasksPageTitle')));
    await tester.pumpAndSettle();

    expect(find.text('توزيع ومتابعة مهام الفريق لكل عميل'), findsOneWidget);
  });

  testWidgets('creates a task with an assignee and optional reviewer', (tester) async {
    await tester.pumpWidget(const TaxOSApp());

    await tester.tap(find.byKey(const ValueKey('nav_tasksPageTitle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add_work_item')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('task_title')), 'مراجعة ملف العميل');
    await tester.tap(find.byKey(const ValueKey('task_reviewer')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مريم علي').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save_work_item')));
    await tester.pumpAndSettle();

    expect(find.text('مراجعة ملف العميل'), findsOneWidget);
    expect(find.textContaining('أحمد حسن'), findsWidgets);
    expect(find.textContaining('المراجع: مريم علي'), findsOneWidget);
  });
}
