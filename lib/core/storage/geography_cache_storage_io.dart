import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<File> _cacheFile() async {
  final directory = await getApplicationSupportDirectory();
  return File(
    '${directory.path}${Platform.pathSeparator}geography-cache-v1.json',
  );
}

Future<String?> readGeographyCacheStorage() async {
  final file = await _cacheFile();
  if (!await file.exists()) return null;
  return file.readAsString();
}

Future<void> writeGeographyCacheStorage(String value) async {
  final file = await _cacheFile();
  await file.writeAsString(value, flush: true);
}
