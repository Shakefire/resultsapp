String? _value;

Future<String?> readGeographyCacheStorage() async => _value;

Future<void> writeGeographyCacheStorage(String value) async {
  _value = value;
}
