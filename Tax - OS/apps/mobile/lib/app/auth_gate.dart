import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_bootstrap.dart';
import 'app_shell.dart';
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
    if (!SupabaseBootstrap.isInitialized) {
      return AppShell(locale: _locale, onToggleLocale: _toggleLocale);
    }

    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? client.auth.currentSession;
        if (session == null) {
          return SignInPage(
            locale: _locale,
            onToggleLocale: _toggleLocale,
          );
        }
        return _OfficeSetupPendingPage(
          locale: _locale,
          email: session.user.email ?? '',
          onSignOut: () => client.auth.signOut(),
        );
      },
    );
  }
}

class _OfficeSetupPendingPage extends StatelessWidget {
  const _OfficeSetupPendingPage({
    required this.locale,
    required this.email,
    required this.onSignOut,
  });

  final String locale;
  final String email;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final isArabic = locale == 'ar';
    final text = isArabic
        ? (
            'تم تسجيل الدخول بنجاح',
            'حسابك جاهز، لكن لم يتم ربطه بمكتب بعد.',
            'سيتم تفعيل مساحة المكتب بعد اعتماد إعدادات العضوية وقاعدة البيانات.',
            'تسجيل الخروج',
          )
        : (
            'Signed in successfully',
            'Your account is not linked to an office yet.',
            'The office workspace will become available after membership and database setup are approved.',
            'Sign out',
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('TaxOS'),
        actions: [
          TextButton(
            onPressed: onSignOut,
            child: Text(text.$4),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      size: 48,
                      color: Color(0xFF176B67),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      text.$1,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(email, textAlign: TextAlign.center),
                    const SizedBox(height: 18),
                    Text(text.$2, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(
                      text.$3,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
