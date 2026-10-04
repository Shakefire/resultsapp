import 'geography_cache_storage_memory.dart'
    if (dart.library.io) 'geography_cache_storage_io.dart'
    if (dart.library.html) 'geography_cache_storage_web.dart'
    as platform;

Future<String?> readGeographyCacheStorage() =>
    platform.readGeographyCacheStorage();

Future<void> writeGeographyCacheStorage(String value) =>
    platform.writeGeographyCacheStorage(value);
