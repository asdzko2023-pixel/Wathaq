import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/wathaq_components.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _continueWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final launched = await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'com.wathaq.app://auth/callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        setState(() => _error = 'تعذر فتح صفحة Google. حاول مرة أخرى.');
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر بدء تسجيل الدخول. تحقق من اتصالك وحاول مجدداً.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wt;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/brand/logo-horizontal-transparent.png',
                  width: 220,
                  height: 100,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Text(
                    'وثاق',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: t.primary),
                  ),
                ),
                const SizedBox(height: 28),
                Text('مرحباً بك في وثاق', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'اجمع نقاطك واكتشف مكافآت متاجرك المفضلة',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: t.textMuted),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _continueWithGoogle,
                    icon: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.g_mobiledata_rounded, size: 28),
                    label: Text(_loading ? 'جارٍ الاتصال...' : 'المتابعة باستخدام Google'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: t.error)),
                ],
                const SizedBox(height: 18),
                Text(
                  'بتسجيل الدخول، يمكنك الوصول إلى رصيدك ومكافآتك بأمان.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SetupRequiredScreen extends StatelessWidget {
  const SetupRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Tajawal'),
        home: const Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.settings_suggest_outlined, size: 52),
                    SizedBox(height: 18),
                    Text('يلزم إعداد اتصال وثاق', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    Text(
                      'أضف SUPABASE_URL وSUPABASE_ANON_KEY عند بناء التطبيق باستخدام --dart-define. لم يتم تضمين أي مفاتيح سرية داخل التطبيق.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
