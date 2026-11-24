import 'package:flutter_test/flutter_test.dart';
import 'package:taxos/app/auth_gate.dart';
import 'package:taxos/core/supabase/supabase_bootstrap.dart';

void main() {
  testWidgets('uses the demo workspace when Supabase is not initialized', (
    tester,
  ) async {
    expect(SupabaseBootstrap.isInitialized, isFalse);

    await tester.pumpWidget(const MaterialApp(home: AuthGate()));

    expect(find.text('لوحة المكتب'), findsOneWidget);
    expect(find.text('بيانات تجريبية'), findsOneWidget);
  });
}
