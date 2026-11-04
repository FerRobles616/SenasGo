import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

class HiveConfig {
  static Future<void> init() async {
    if (kIsWeb) {
      // En web Hive usa IndexedDB y no acepta una ruta de archivo.
      await Hive.initFlutter();
    } else {
      final dir = await getApplicationDocumentsDirectory();
      await Hive.initFlutter(dir.path);
    }

    // Los adapters se registran en HiveService (TypeAdapters generados).
  }

  static Future<Box<T>> openBox<T>(String boxName) async {
    if (!Hive.isBoxOpen(boxName)) {
      return Hive.openBox<T>(boxName);
    }
    return Hive.box<T>(boxName);
  }
}
