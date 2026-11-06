import 'package:flutter/material.dart';
import 'package:senasgo/core/services/hive_service.dart';

/// Apariencia elegida en el perfil.
enum AppearancePreference {
  dark('Oscuro'),
  light('Claro'),
  system('Según el sistema');

  const AppearancePreference(this.label);

  final String label;
}

/// Guarda la apariencia elegida (en Hive, sin internet) y avisa a la app para
/// que se vuelva a construir con la paleta nueva.
class ThemeController extends ChangeNotifier {
  ThemeController._(this._preference);

  static const _key = 'appearance';

  static ThemeController? _instance;

  /// Única instancia. Si `init()` todavía no corrió (por ejemplo en un test de
  /// widget), se usa una preferencia segura por defecto en vez de fallar.
  static ThemeController get instance =>
      _instance ??= ThemeController._(AppearancePreference.dark);

  /// La app arranca en oscuro hasta que la persona elija otra cosa.
  static void init() {
    final saved = HiveService.prefsBox.get(_key) as String?;
    _instance = ThemeController._(
        AppearancePreference.values.asNameMap()[saved] ??
            AppearancePreference.dark);
  }

  AppearancePreference _preference;

  AppearancePreference get preference => _preference;

  ThemeMode get mode => switch (_preference) {
        AppearancePreference.dark => ThemeMode.dark,
        AppearancePreference.light => ThemeMode.light,
        AppearancePreference.system => ThemeMode.system,
      };

  Future<void> setPreference(AppearancePreference value) async {
    if (value == _preference) return;
    _preference = value;
    notifyListeners();
    await HiveService.prefsBox.put(_key, value.name);
  }
}
