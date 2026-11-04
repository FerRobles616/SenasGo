import 'dart:io';

/// Lee la RAM física total desde /proc/meminfo (Android, sin permisos).
Future<int?> totalRamBytes() async {
  try {
    final meminfo = await File('/proc/meminfo').readAsLines();
    final line = meminfo.firstWhere((l) => l.startsWith('MemTotal:'));
    final kb = int.parse(RegExp(r'\d+').firstMatch(line)!.group(0)!);
    return kb * 1024;
  } catch (_) {
    return null;
  }
}
