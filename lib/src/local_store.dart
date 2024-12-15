import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStore {
  static const String _pendingOperationsKey = 'pending_operations';
  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<dynamic> get(String key) async {
    final value = _prefs.getString(key);
    if (value == null) return null;
    return jsonDecode(value);
  }

  Future<void> set(String key, dynamic value) async {
    await _prefs.setString(key, jsonEncode(value));
  }

  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }

  Future<void> clear() async {
    await _prefs.clear();
  }

  Future<bool> containsKey(String key) async {
    return _prefs.containsKey(key);
  }
}
