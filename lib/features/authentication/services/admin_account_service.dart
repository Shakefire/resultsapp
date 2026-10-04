import '../../../core/services/vercel_api_client.dart';
import '../models/user_role.dart';
import 'geography_catalog_cache.dart';

class GeographyOption {
  const GeographyOption({
    required this.code,
    required this.name,
    this.isFromCache = false,
  });
  final String code;
  final String name;
  final bool isFromCache;

  factory GeographyOption.fromJson(
    Map<String, dynamic> json, {
    bool isFromCache = false,
  }) => GeographyOption(
    code: json['code'] as String,
    name: json['name'] as String,
    isFromCache: isFromCache,
  );
}

class ProvisionedAccount {
  const ProvisionedAccount({
    required this.userId,
    required this.temporaryPassword,
  });
  final String userId;
  final String temporaryPassword;
}

/// Account provisioning operations exposed to the Super Admin interface.
class AdminAccountService {
  AdminAccountService({VercelApiClient? api})
    : _api = api ?? VercelApiClient.instance;
  final VercelApiClient _api;

  Future<List<GeographyOption>> getGeography({
    required String level,
    String? stateCode,
    String? lgaCode,
    String? wardCode,
  }) async {
    final cache = GeographyCatalogCache.instance;
    final cacheKey = cache.key(
      catalog: 'provisioning',
      level: level,
      stateCode: stateCode,
      lgaCode: lgaCode,
      wardCode: wardCode,
    );
    final query = <String, String>{'level': level};
    if (stateCode != null) query['stateCode'] = stateCode;
    if (lgaCode != null) query['lgaCode'] = lgaCode;
    if (wardCode != null) query['wardCode'] = wardCode;
    try {
      final response = await _api.get(
        '/api/v1/geography?${Uri(queryParameters: query).query}',
      );
      final rows = (response['items'] as List<dynamic>)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(growable: false);
      await cache.write(cacheKey, rows);
      return rows.map(GeographyOption.fromJson).toList(growable: false);
    } catch (_) {
      final cached = await cache.read(cacheKey);
      if (cached != null) {
        return cached
            .map((item) => GeographyOption.fromJson(item, isFromCache: true))
            .toList(growable: false);
      }
      rethrow;
    }
  }

  Future<ProvisionedAccount> createAccount({
    required String fullName,
    required UserRole role,
    required String stateCode,
    String? lgaCode,
    String? wardCode,
    String? pollingUnitCode,
    bool canProvisionUsers = false,
  }) async {
    final response = await _api.post('/api/v1/admin/users', {
      'fullName': fullName.trim(),
      'role': role.code,
      'stateCode': stateCode,
      'lgaCode': lgaCode,
      'wardCode': wardCode,
      'pollingUnitCode': pollingUnitCode,
      if (canProvisionUsers) 'canProvisionUsers': true,
    });
    return ProvisionedAccount(
      userId: response['userId'] as String,
      temporaryPassword: response['temporaryPassword'] as String,
    );
  }
}
