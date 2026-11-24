import 'package:material_ui/material_ui.dart';

import 'auth_gate.dart';

class TaxOSApp extends StatefulWidget {
  const TaxOSApp({super.key});

  @override
  State<TaxOSApp> createState() => _TaxOSAppState();
}

class _TaxOSAppState extends State<TaxOSApp> {
  String _locale = 'ar';

  void _toggleLocale() {
    setState(() => _locale = _locale == 'ar' ? 'en' : 'ar');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaxOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF176B67),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F8F8),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF6F8F8),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFE6ECEB)),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}
