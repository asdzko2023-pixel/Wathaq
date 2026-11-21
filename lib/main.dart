import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? startupError;
  if (AppConfig.isSupabaseConfigured) {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('WATHAQ startup initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      startupError = 'تعذر تهيئة الاتصال الآمن. تحقق من إعدادات Supabase واتصال الإنترنت ثم أعد المحاولة.';
    }
  }

  runApp(
    ProviderScope(
      child: WathaqApp(startupError: startupError),
    ),
  );
}
