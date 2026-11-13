import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class DeviceCommandToken {
  DeviceCommandToken._();

  static const _storageKey = 'command_center_device_token';
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static Future<String>? _token;

  static Future<String> getOrCreate() {
    final inProgress = _token;
    if (inProgress != null) return inProgress;

    final created = _loadOrCreate();
    _token = created;
    created.catchError((Object _) {
      if (identical(_token, created)) _token = null;
      return '';
    });
    return created;
  }

  static Future<String> _loadOrCreate() async {
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(_storageKey)?.trim();
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final characters = List<String>.generate(
      20,
      (_) => _alphabet[random.nextInt(_alphabet.length)],
    );
    final token =
        'CMD-${characters.take(5).join()}-${characters.skip(5).take(5).join()}-${characters.skip(10).take(5).join()}-${characters.skip(15).join()}';
    await preferences.setString(_storageKey, token);
    return token;
  }
}
