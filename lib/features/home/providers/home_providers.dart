import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/home_repository.dart';

final homeRepositoryProvider = Provider<HomeRepository>(
  (ref) => HomeRepository(Supabase.instance.client),
);

final homeDashboardProvider = FutureProvider.autoDispose<HomeDashboard>(
  (ref) => ref.watch(homeRepositoryProvider).load(),
);
