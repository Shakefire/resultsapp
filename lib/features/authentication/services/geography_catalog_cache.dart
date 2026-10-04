import 'dart:convert';

import '../../../core/storage/geography_cache_storage.dart';

/// Persists successfully fetched geography lists for offline lookup fallback.
class GeographyCatalogCache {
  GeographyCatalogCache._();

  static final GeographyCatalogCache instance = GeographyCatalogCache._();

  Map<String, dynamic> _entries = {};
  Future<void>? _loadFuture;

  String key({
    required String catalog,
    required String level,
    String? stateCode,
    String? lgaCode,
    String? wardCode,
  }) => [
    catalog,
    level,
    stateCode ?? '-',
    lgaCode ?? '-',
    wardCode ?? '-',
  ].map(Uri.encodeComponent).join('/');

  Future<List<Map<String, dynamic>>?> read(String key) async {
    await _ensureLoaded();
    final value = _entries[key];
    final rows = value is Map ? value['rows'] : value;
    if (rows is! List) return null;
    return rows
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<void> write(String key, List<Map<String, dynamic>> rows) async {
    try {
      await _ensureLoaded();
      _entries[key] = {
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'rows': rows,
      };
      var encoded = jsonEncode(_entries);
      while (encoded.length > 2 * 1024 * 1024 && _entries.length > 1) {
        final oldestKey = _entries.keys
            .where((entryKey) => entryKey != key)
            .reduce((oldest, candidate) {
              final oldestTime = _timestamp(_entries[oldest]);
              final candidateTime = _timestamp(_entries[candidate]);
              return candidateTime < oldestTime ? candidate : oldest;
            });
        _entries.remove(oldestKey);
        encoded = jsonEncode(_entries);
      }
      if (encoded.length <= 2 * 1024 * 1024) {
        await writeGeographyCacheStorage(encoded);
      }
    } catch (_) {
      // Network results remain usable even if local persistence is unavailable.
    }
  }

  Future<void> _ensureLoaded() => _loadFuture ??= _load();

  Future<void> _load() async {
    try {
      final encoded = await readGeographyCacheStorage();
      if (encoded == null || encoded.isEmpty) return;
      final decoded = jsonDecode(encoded);
      if (decoded is Map) _entries = Map<String, dynamic>.from(decoded);
    } catch (_) {
      _entries = {};
    }
  }

  int _timestamp(dynamic value) =>
      value is Map && value['updatedAt'] is int ? value['updatedAt'] as int : 0;
}
