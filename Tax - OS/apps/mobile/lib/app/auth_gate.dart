import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_bootstrap.dart';
import 'app_shell.dart';
import 'office_session_gate.dart';
import 'sign_in_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String _locale = 'ar';

  void _toggleLocale() {
    setState(() => _locale = _locale == 'ar' ? 'en' : 'ar');
  }

  @override
  Widget build(BuildContext context) {
    final child = !SupabaseBootstrap.isInitialized
        ? AppShell(locale: _locale, onToggleLocale: _toggleLocale)
        : _buildAuthenticatedContent();
    return Directionality(
      textDirection: _locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      child: child,
    );
  }

  Widget _buildAuthenticatedContent() {
    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? client.auth.currentSession;
        if (session == null) {
          return SignInPage(locale: _locale, onToggleLocale: _toggleLocale);
        }
        return OfficeSessionGate(
          locale: _locale,
          onToggleLocale: _toggleLocale,
        );
      },
    );
  }
}
