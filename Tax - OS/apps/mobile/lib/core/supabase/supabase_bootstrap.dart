import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_environment.dart';

class SupabaseBootstrap {
  const SupabaseBootstrap._();

  static Future<bool> initialize() async {
    if (!AppEnvironment.hasSupabaseConfig) return false;

    await Supabase.initialize(
      url: AppEnvironment.supabaseUrl,
      publishableKey: AppEnvironment.supabasePublishableKey,
      allowInsecureHttp: kDebugMode,
    );
    return true;
  }
}
