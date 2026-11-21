import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/app_config.dart';
import 'core/theme/wathaq_theme.dart';
import 'features/auth/presentation/sign_in_screen.dart';
import 'features/home/presentation/home_screen.dart';

class WathaqApp extends StatelessWidget {
  const WathaqApp({super.key, this.startupError});

  final String? startupError;

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isSupabaseConfigured) return const SetupRequiredScreen();
    if (startupError != null) return StartupFailureScreen(message: startupError!);
    final client = Supabase.instance.client;
    return MaterialApp(
      title: 'وثاق WATHAQ',
      debugShowCheckedModeBanner: false,
      theme: WathaqTheme.light(),
      darkTheme: WathaqTheme.dark(),
      themeMode: ThemeMode.system,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: StreamBuilder<AuthState>(
        stream: client.auth.onAuthStateChange,
        initialData: AuthState(AuthChangeEvent.initialSession, client.auth.currentSession),
        builder: (context, snapshot) => (snapshot.data?.session ?? client.auth.currentSession) == null
            ? const SignInScreen()
            : const HomeScreen(),
      ),
    );
  }
}


class StartupFailureScreen extends StatelessWidget {
  const StartupFailureScreen({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: WathaqTheme.light(),
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 52),
                const SizedBox(height: 18),
                const Text('تعذر تشغيل الاتصال', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                const Text('أغلق التطبيق وافتحه بعد التأكد من إعدادات الاتصال.', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
