import 'dart:io';

/// El runner de `flutter test` no carga las librerías nativas de layout/texto
/// de Rive. En ese entorno usamos el respaldo; en la app real Rive se carga
/// normalmente.
bool get isFlutterTest => Platform.environment['FLUTTER_TEST'] == 'true';
