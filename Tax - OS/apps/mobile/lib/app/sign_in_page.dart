import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({
    required this.locale,
    required this.onToggleLocale,
    super.key,
  });

  final String locale;
  final VoidCallback onToggleLocale;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isBusy = false;
  String? _errorMessage;

  bool get _isArabic => widget.locale == 'ar';

  String tr(String ar, String en) => _isArabic ? ar : en;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on AuthException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = tr(
            'تعذر تسجيل الدخول. حاول مرة أخرى.',
            'Unable to sign in. Please try again.',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (!email.contains('@') || password.length < 8) {
      setState(() {
        _errorMessage = tr(
          'أدخل بريدًا صحيحًا وكلمة مرور لا تقل عن 8 أحرف.',
          'Enter a valid email and a password with at least 8 characters.',
        );
      });
      return;
    }

    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('إنشاء حساب جديد', 'Create an account')),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: tr('الاسم بالكامل', 'Full name'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(tr('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, nameController.text.trim()),
            child: Text(tr('متابعة', 'Continue')),
          ),
        ],
      ),
    );
    nameController.dispose();
    if (name == null || name.trim().isEmpty || !mounted) return;

    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name.trim()},
      );
      if (!mounted) return;
      if (response.session == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'تم إنشاء الحساب. افتح رسالة البريد لتأكيد الحساب ثم سجل الدخول.',
                'Account created. Confirm your email, then sign in.',
              ),
            ),
          ),
        );
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = tr('تعذر إنشاء الحساب. حاول مرة أخرى.', 'Could not create the account. Please try again.');
        });
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _errorMessage = tr(
          'اكتب بريدك الإلكتروني أولاً لإرسال رابط إعادة التعيين.',
          'Enter your email first to receive a password reset link.',
        );
      });
      return;
    }
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'إذا كان البريد مسجلاً، ستصلك رسالة لإعادة تعيين كلمة المرور.',
              'If the email is registered, you will receive a password reset message.',
            ),
          ),
        ),
      );
    } on AuthException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = tr(
            'تعذر إرسال رابط إعادة التعيين.',
            'Could not send the password reset link.',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TaxOS'),
        actions: [
          IconButton(
            key: const ValueKey('auth_toggle_locale'),
            tooltip: tr('تغيير اللغة', 'Change language'),
            onPressed: widget.onToggleLocale,
            icon: const Icon(Icons.language),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        size: 42,
                        color: Color(0xFF176B67),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        tr('تسجيل الدخول إلى المكتب', 'Sign in to your office'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr(
                          'استخدم بيانات الدخول التي وفرها لك مسؤول المكتب.',
                          'Use the sign-in details provided by your office administrator.',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        key: const ValueKey('auth_email'),
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username],
                        decoration: InputDecoration(
                          labelText: tr('البريد الإلكتروني', 'Email'),
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          if (value == null || !value.contains('@')) {
                            return tr(
                              'أدخل بريدًا إلكترونيًا صحيحًا.',
                              'Enter a valid email address.',
                            );
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const ValueKey('auth_password'),
                        controller: _passwordController,
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: tr('كلمة المرور', 'Password'),
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.key_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return tr(
                              'أدخل كلمة المرور.',
                              'Enter your password.',
                            );
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) {
                          if (!_isBusy) _signIn();
                        },
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      FilledButton(
                        key: const ValueKey('auth_sign_in'),
                        onPressed: _isBusy ? null : _signIn,
                        child: _isBusy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(tr('تسجيل الدخول', 'Sign in')),
                      ),
                      TextButton(
                        key: const ValueKey('auth_reset_password'),
                        onPressed: _isBusy ? null : _sendPasswordReset,
                        child: Text(
                          tr('نسيت كلمة المرور؟', 'Forgot password?'),
                        ),
                      ),
                      TextButton(
                        key: const ValueKey('auth_create_account'),
                        onPressed: _isBusy ? null : _signUp,
                        child: Text(tr('إنشاء حساب جديد', 'Create a new account')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
