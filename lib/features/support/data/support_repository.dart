import 'package:hive/hive.dart';
import 'package:senasgo/core/constants/app_constants.dart';
import 'package:senasgo/features/support/domain/support_ticket.dart';

/// Persistencia local de reportes. Sin backend ni envío automático.
class SupportRepository {
  const SupportRepository._();

  static Box<dynamic> get _box =>
      Hive.box<dynamic>(AppConstants.hiveBoxSupport);

  static List<SupportTicket> get tickets {
    final list = <SupportTicket>[];
    for (final value in _box.values) {
      if (value is Map) {
        final ticket = SupportTicket.fromMap(value);
        if (ticket.id.isNotEmpty) list.add(ticket);
      }
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  static int get count => tickets.length;

  static Future<SupportTicket> save(SupportTicket ticket) async {
    await _box.put(ticket.id, ticket.toMap());
    return ticket;
  }

  static Future<void> setResolved(String id, bool resolved) async {
    final value = _box.get(id);
    if (value is! Map) return;
    final ticket = SupportTicket.fromMap(value).copyWith(isResolved: resolved);
    await _box.put(id, ticket.toMap());
  }

  static Future<void> delete(String id) => _box.delete(id);

  static Future<void> clear() => _box.clear();
}
