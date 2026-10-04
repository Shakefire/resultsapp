import '../../../core/services/vercel_api_client.dart';
import 'geography_catalog_cache.dart';

class ManagedAccount {
  const ManagedAccount(this.json);
  final Map<String, dynamic> json;
  String get id => json['auth_user_id'] as String;
  String get userId => json['user_id'] as String;
  String get name => json['full_name'] as String;
  String get role => json['role'] as String;
  bool get active => json['is_active'] as bool? ?? false;
  String get scope => [
    json['state_code'],
    json['lga_code'],
    json['ward_code'],
    json['polling_unit_code'],
  ].whereType<String>().join(' / ');
}

class ManagedGeography {
  const ManagedGeography(this.json, {this.isFromCache = false});
  final Map<String, dynamic> json;
  final bool isFromCache;
  String get code => json['code'] as String;
  String get name => json['name'] as String;
  bool get active => json['is_active'] as bool? ?? false;
}

class AdminManagementService {
  AdminManagementService({VercelApiClient? api})
    : _api = api ?? VercelApiClient.instance;
  final VercelApiClient _api;

  Future<List<ManagedAccount>> getAccounts() async {
    final data = await _api.get('/api/v1/admin/accounts');
    return (data['items'] as List<dynamic>? ?? const [])
        .map((item) => ManagedAccount(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> updateAccount(String accountId, String action) =>
      _api.patch('/api/v1/admin/accounts', {
        'accountId': accountId,
        'action': action,
      });

  Future<String> assignAccount(
    String accountId, {
    required String role,
    required String stateCode,
    String? lgaCode,
    String? wardCode,
    String? pollingUnitCode,
  }) async {
    final data = await _api.patch('/api/v1/admin/accounts', {
      'accountId': accountId,
      'action': 'assign',
      'role': role,
      'stateCode': stateCode,
      'lgaCode': lgaCode,
      'wardCode': wardCode,
      'pollingUnitCode': pollingUnitCode,
    });
    return data['userId'] as String;
  }

  Future<List<ManagedGeography>> getGeography(
    String level, {
    String? stateCode,
    String? lgaCode,
    String? wardCode,
  }) async {
    final cache = GeographyCatalogCache.instance;
    final cacheKey = cache.key(
      catalog: 'management',
      level: level,
      stateCode: stateCode,
      lgaCode: lgaCode,
      wardCode: wardCode,
    );
    final query = <String, String>{
      'level': level,
      if (stateCode != null) 'stateCode': stateCode,
      if (lgaCode != null) 'lgaCode': lgaCode,
      if (wardCode != null) 'wardCode': wardCode,
    };
    try {
      final data = await _api.get(
        '/api/v1/admin/geography?${Uri(queryParameters: query).query}',
      );
      final rows = (data['items'] as List<dynamic>? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(growable: false);
      await cache.write(cacheKey, rows);
      return rows.map(ManagedGeography.new).toList(growable: false);
    } catch (_) {
      final cached = await cache.read(cacheKey);
      if (cached != null) {
        return cached
            .map((item) => ManagedGeography(item, isFromCache: true))
            .toList(growable: false);
      }
      rethrow;
    }
  }

  Future<void> createGeography({
    required String level,
    required String code,
    required String name,
    String? stateCode,
    String? lgaCode,
    String? wardCode,
  }) async {
    await _api.post('/api/v1/admin/geography', {
      'level': level,
      'code': code,
      'name': name,
      'stateCode': stateCode,
      'lgaCode': lgaCode,
      'wardCode': wardCode,
    });
  }

  Future<void> updateGeography({
    required String level,
    required String code,
    required String? name,
    required bool? active,
    String? stateCode,
    String? lgaCode,
    String? wardCode,
  }) async {
    await _api.patch(
      '/api/v1/admin/geography',
      {
        'level': level,
        'code': code,
        'name': name,
        'isActive': active,
        'stateCode': stateCode,
        'lgaCode': lgaCode,
        'wardCode': wardCode,
      }..removeWhere((_, value) => value == null),
    );
  }
}
