import 'package:flutter/widgets.dart';

import 'app/taxos_app.dart';
import 'core/supabase/supabase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseBootstrap.initialize();
  runApp(const TaxOSApp());
}
