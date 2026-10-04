import 'dart:html' as html;

const _storageKey = 'election.geography-cache.v1';

Future<String?> readGeographyCacheStorage() async =>
    html.window.localStorage[_storageKey];

Future<void> writeGeographyCacheStorage(String value) async {
  html.window.localStorage[_storageKey] = value;
}
