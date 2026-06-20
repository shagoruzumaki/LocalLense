import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.dark);

  static const _preferenceKey = 'theme_mode';

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    value = preferences.getString(_preferenceKey) == 'light'
        ? ThemeMode.light
        : ThemeMode.dark;
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == value) return;
    value = mode;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _preferenceKey,
      mode == ThemeMode.light ? 'light' : 'dark',
    );
  }
}

final themeController = ThemeController();
