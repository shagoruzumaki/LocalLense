import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:local_lense/theme/app_theme.dart';
import 'package:local_lense/theme/theme_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('provides distinct accessible light and dark themes', () {
    expect(AppTheme.light.brightness, Brightness.light);
    expect(AppTheme.dark.brightness, Brightness.dark);
    expect(
      AppTheme.light.scaffoldBackgroundColor,
      isNot(AppTheme.dark.scaffoldBackgroundColor),
    );
  });

  test('saves and restores the selected theme', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = ThemeController();

    await controller.load();
    expect(controller.value, ThemeMode.dark);

    await controller.setMode(ThemeMode.light);
    final restoredController = ThemeController();
    await restoredController.load();

    expect(restoredController.value, ThemeMode.light);
  });
}
