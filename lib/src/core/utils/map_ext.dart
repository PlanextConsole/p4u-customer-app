extension MapRead on Map<String, dynamic> {
  String s(String key, [String fallback = '']) => this[key]?.toString() ?? fallback;

  num n(String key, [num fallback = 0]) {
    final value = this[key];
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? fallback;
  }

  int i(String key, [int fallback = 0]) => n(key, fallback).round();

  double d(String key, [double fallback = 0]) => n(key, fallback).toDouble();

  bool b(String key, [bool fallback = false]) {
    final value = this[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return ['true', '1', 'yes', 'active'].contains(value.toLowerCase());
    return fallback;
  }
}
