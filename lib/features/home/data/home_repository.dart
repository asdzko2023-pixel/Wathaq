import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActivityEntry {
  const ActivityEntry({
    required this.title,
    required this.subtitle,
    required this.createdAt,
    required this.pointsDelta,
    required this.kind,
  });

  final String title;
  final String subtitle;
  final DateTime createdAt;
  final int pointsDelta;
  final String kind;

  Map<String, dynamic> toJson() => {
    'title': title, 'subtitle': subtitle, 'createdAt': createdAt.toIso8601String(),
    'pointsDelta': pointsDelta, 'kind': kind,
  };

  factory ActivityEntry.fromJson(Map<String, dynamic> json) => ActivityEntry(
    title: json['title'] as String,
    subtitle: json['subtitle'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    pointsDelta: (json['pointsDelta'] as num).toInt(),
    kind: json['kind'] as String,
  );
}

class RewardPreview {
  const RewardPreview({
    required this.id,
    required this.title,
    required this.description,
    required this.pointsCost,
    required this.merchantName,
  });

  final String id;
  final String title;
  final String description;
  final int? pointsCost;
  final String merchantName;

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'description': description,
    'pointsCost': pointsCost, 'merchantName': merchantName,
  };

  factory RewardPreview.fromJson(Map<String, dynamic> json) => RewardPreview(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    pointsCost: (json['pointsCost'] as num?)?.toInt(),
    merchantName: json['merchantName'] as String,
  );
}

class HomeDashboard {
  const HomeDashboard({
    required this.displayName,
    required this.pointsBalance,
    required this.programCount,
    required this.activities,
    required this.rewards,
    this.isOfflineCache = false,
  });

  final String displayName;
  final int pointsBalance;
  final int programCount;
  final List<ActivityEntry> activities;
  final List<RewardPreview> rewards;
  final bool isOfflineCache;

  HomeDashboard asOfflineCache() => HomeDashboard(
    displayName: displayName,
    pointsBalance: pointsBalance,
    programCount: programCount,
    activities: activities,
    rewards: rewards,
    isOfflineCache: true,
  );

  Map<String, dynamic> toJson() => {
    'displayName': displayName,
    'pointsBalance': pointsBalance,
    'programCount': programCount,
    'activities': activities.map((item) => item.toJson()).toList(),
    'rewards': rewards.map((item) => item.toJson()).toList(),
  };

  factory HomeDashboard.fromJson(Map<String, dynamic> json) => HomeDashboard(
    displayName: json['displayName'] as String,
    pointsBalance: (json['pointsBalance'] as num).toInt(),
    programCount: (json['programCount'] as num).toInt(),
    activities: (json['activities'] as List)
        .map((item) => ActivityEntry.fromJson(Map<String, dynamic>.from(item as Map))).toList(),
    rewards: (json['rewards'] as List)
        .map((item) => RewardPreview.fromJson(Map<String, dynamic>.from(item as Map))).toList(),
  );
}

class HomeRepository {
  HomeRepository(this._client);
  final SupabaseClient _client;

  Future<HomeDashboard> load() async {
    final user = _client.auth.currentUser;
    if (user == null) throw AuthException('يجب تسجيل الدخول أولاً.');
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'wathaq.home.v1.${user.id}';

    try {
      final profile = await _client
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();

      // Read relations independently to avoid ambiguous PostgREST embeds.
      final accounts = await _client
          .from('loyalty_accounts')
          .select('id, merchant_id, program_id, points_balance')
          .eq('customer_id', user.id);

      final points = accounts.fold<int>(
        0,
        (sum, row) => sum + ((row['points_balance'] as num?)?.toInt() ?? 0),
      );

      final ledger = await _client
          .from('loyalty_ledger')
          .select('id, kind, points_delta, created_at, merchant_id')
          .eq('customer_id', user.id)
          .order('created_at', ascending: false)
          .limit(5);

      final rewardRows = await _client
          .from('rewards')
          .select('id, title, description, points_cost, merchant_id')
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(4);

      final merchantIds = <String>{
        ...accounts.map((row) => row['merchant_id'] as String),
        ...ledger.map((row) => row['merchant_id'] as String),
        ...rewardRows.map((row) => row['merchant_id'] as String),
      }.toList();

      final merchantNames = <String, String>{};
      if (merchantIds.isNotEmpty) {
        final merchants = await _client
            .from('merchants')
            .select('id, name')
            .inFilter('id', merchantIds);
        for (final merchant in merchants) {
          merchantNames[merchant['id'] as String] = merchant['name'] as String;
        }
      }

      final activities = ledger.map((row) {
        final kind = row['kind'] as String? ?? '';
        final merchantName = merchantNames[row['merchant_id']] ?? 'متجر وثاق';
        final title = switch (kind) {
          'earn' => 'اكتسبت نقاطاً',
          'redeem' => 'استبدلت مكافأة',
          'adjustment' => 'تعديل على الرصيد',
          'reversal' => 'عكس عملية سابقة',
          'expiry' => 'انتهاء نقاط',
          _ => 'حركة في رصيدك',
        };
        return ActivityEntry(
          title: title,
          subtitle: merchantName,
          createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
          pointsDelta: (row['points_delta'] as num?)?.toInt() ?? 0,
          kind: kind,
        );
      }).toList();

      final rewards = rewardRows.map((row) => RewardPreview(
        id: row['id'] as String,
        title: row['title'] as String,
        description: row['description'] as String? ?? '',
        pointsCost: (row['points_cost'] as num?)?.toInt(),
        merchantName: merchantNames[row['merchant_id']] ?? 'متجر مشارك',
      )).toList();

      final metadataName = user.userMetadata?['full_name'] as String?;
      final emailName = user.email?.split('@').first;
      final displayName = (profile?['full_name'] as String?)?.trim().isNotEmpty == true
          ? (profile!['full_name'] as String).trim()
          : (metadataName?.trim().isNotEmpty == true ? metadataName!.trim() : (emailName ?? 'ضيف وثاق'));

      final dashboard = HomeDashboard(
        displayName: displayName,
        pointsBalance: points,
        programCount: accounts.length,
        activities: activities,
        rewards: rewards,
      );
      await prefs.setString(cacheKey, jsonEncode(dashboard.toJson()));
      return dashboard;
    } catch (_) {
      final cached = prefs.getString(cacheKey);
      if (cached != null) {
        try {
          return HomeDashboard.fromJson(jsonDecode(cached) as Map<String, dynamic>).asOfflineCache();
        } catch (_) {
          // Ignore malformed or outdated local cache and surface the original request failure.
        }
      }
      rethrow;
    }
  }
}
