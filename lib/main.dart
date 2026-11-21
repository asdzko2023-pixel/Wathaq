import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';

bool _isWathaqAuthCallback(Uri uri) {
  if (uri.scheme != 'com.wathaq.app' ||
      uri.host != 'auth' ||
      uri.path != '/callback') {
    return false;
  }

  final fragment = Uri.splitQueryString(uri.fragment);
  return uri.queryParameters.containsKey('code') ||
      uri.queryParameters.containsKey('error') ||
      uri.queryParameters.containsKey('error_code') ||
      uri.queryParameters.containsKey('error_description') ||
      fragment.containsKey('access_token') ||
      fragment.containsKey('error_description');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? startupError;
  if (AppConfig.isSupabaseConfigured) {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabaseAnonKey,
        authOptions: FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          detectSessionInUriPredicate: _isWathaqAuthCallback,
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
