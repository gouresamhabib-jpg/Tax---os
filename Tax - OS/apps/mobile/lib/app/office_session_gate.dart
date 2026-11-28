import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_environment.dart';
import '../features/workspace/supabase_workspace_page.dart';

class OfficeSessionGate extends StatefulWidget {
  const OfficeSessionGate({
    required this.locale,
    required this.onToggleLocale,
    super.key,
  });

  final String locale;
  final VoidCallback onToggleLocale;

  @override
  State<OfficeSessionGate> createState() => _OfficeSessionGateState();
}

class _OfficeSessionGateState extends State<OfficeSessionGate> {
  late Future<Map<String, dynamic>?> _membershipFuture;

  bool get _isArabic => widget.locale == 'ar';

  String tr(String ar, String en) => _isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _membershipFuture = _loadMembership();
  }

  Future<Map<String, dynamic>?> _loadMembership() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    final rows = await Supabase.instance.client
        .schema(AppEnvironment.supabaseSchema)
        .from('firm_memberships')
        .select('id, firm_id, role, firms(name)')
        .eq('user_id', user.id)
        .eq('status', 'active')
        .limit(1);

    if (rows.isEmpty) return null;
    final row = Map<String, dynamic>.from(rows.first);
    final firm = row['firms'] is Map
        ? Map<String, dynamic>.from(row['firms'] as Map)
        : <String, dynamic>{};
    return {
      'membership_id': row['id'] as String,
      'firm_id': row['firm_id'] as String,
      'role': row['role'] as String,
      'firm_name':
          (firm['name'] as String?) ?? tr('مكتب المحاسبة', 'Accounting office'),
    };
  }

  void _reload() {
    setState(() => _membershipFuture = _loadMembership());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _membershipFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return _LoadErrorPage(
            locale: widget.locale,
            error: snapshot.error.toString(),
            onRetry: _reload,
            onSignOut: () => Supabase.instance.client.auth.signOut(),
          );
        }
        final membership = snapshot.data;
        if (membership == null) {
          return _CreateOfficePage(
            locale: widget.locale,
            onToggleLocale: widget.onToggleLocale,
            onCreated: _reload,
          );
        }
        return SupabaseWorkspacePage(
          locale: widget.locale,
          onToggleLocale: widget.onToggleLocale,
          membershipId: membership['membership_id'] as String,
          firmId: membership['firm_id'] as String,
          firmName: membership['firm_name'] as String,
          role: membership['role'] as String,
        );
      },
    );
  }
}

class _CreateOfficePage extends StatefulWidget {
  const _CreateOfficePage({
    required this.locale,
    required this.onToggleLocale,
    required this.onCreated,
  });

  final String locale;
  final VoidCallback onToggleLocale;
  final VoidCallback onCreated;

  @override
  State<_CreateOfficePage> createState() => _CreateOfficePageState();
}

class _CreateOfficePageState extends State<_CreateOfficePage> {
  final _nameController = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _isArabic => widget.locale == 'ar';
  String tr(String ar, String en) => _isArabic ? ar : en;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createOffice() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(
        () => _error = tr('اكتب اسم المكتب أولاً.', 'Enter your office name.'),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = Supabase.instance.client.auth.currentUser!;
      await Supabase.instance.client
          .schema(AppEnvironment.supabaseSchema)
          .from('firms')
          .insert({'name': name, 'created_by': user.id});
      widget.onCreated();
    } on PostgrestException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(
        () => _error = tr(
          'تعذر إنشاء المكتب. حاول مرة أخرى.',
          'Could not create the office. Please try again.',
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TaxOS'),
        actions: [
          IconButton(
            tooltip: tr('تغيير اللغة', 'Change language'),
            onPressed: widget.onToggleLocale,
            icon: const Icon(Icons.language),
          ),
          TextButton(
            onPressed: () => Supabase.instance.client.auth.signOut(),
            child: Text(tr('تسجيل الخروج', 'Sign out')),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.business_outlined,
                      size: 48,
                      color: Color(0xFF176B67),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tr('أنشئ مساحة مكتبك', 'Create your office workspace'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr(
                        'سيتم إنشاء المكتب وربط حسابك به كمالك بشكل آمن.',
                        'Your office will be created and your account will become its owner.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: _nameController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: tr('اسم المكتب', 'Office name'),
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _busy ? null : _createOffice(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _busy ? null : _createOffice,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(tr('إنشاء المكتب', 'Create office')),
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

class _LoadErrorPage extends StatelessWidget {
  const _LoadErrorPage({
    required this.locale,
    required this.error,
    required this.onRetry,
    required this.onSignOut,
  });

  final String locale;
  final String error;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final isArabic = locale == 'ar';
    return Scaffold(
      appBar: AppBar(title: const Text('TaxOS')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 44),
                const SizedBox(height: 14),
                Text(
                  isArabic
                      ? 'تعذر تحميل مساحة المكتب'
                      : 'Could not load the office workspace',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                SelectableText(error, textAlign: TextAlign.center),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: onRetry,
                  child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
                ),
                TextButton(
                  onPressed: onSignOut,
                  child: Text(isArabic ? 'تسجيل الخروج' : 'Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
