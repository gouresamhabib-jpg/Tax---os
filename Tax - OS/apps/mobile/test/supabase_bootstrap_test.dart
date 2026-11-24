import 'package:flutter_test/flutter_test.dart';
import 'package:taxos/core/config/app_environment.dart';
import 'package:taxos/core/supabase/supabase_bootstrap.dart';

void main() {
  test(
    'Supabase remains disabled when compile-time configuration is absent',
    () async {
      expect(AppEnvironment.hasSupabaseConfig, isFalse);
      expect(await SupabaseBootstrap.initialize(), isFalse);
    },
  );
}
