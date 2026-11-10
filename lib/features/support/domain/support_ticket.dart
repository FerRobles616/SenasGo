import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

/// Tipos de mensaje que una persona puede enviar desde la app.
enum SupportCategory {
  bug('Problema', 'Algo no funciona o se ve mal'),
  idea('Idea', 'Una mejora para aprender mejor'),
  content('Contenido', 'Una seña, texto o dato para revisar'),
  comment('Comentario', 'Una opinión o experiencia de uso');

  const SupportCategory(this.label, this.description);

  final String label;
  final String description;

  static SupportCategory fromName(String? name) => values.firstWhere(
        (c) => c.name == name,
        orElse: () => SupportCategory.comment,
      );
}

/// Reporte de soporte. Se guarda en el teléfono y se envía a Supabase
/// (tabla support_tickets). Si no hay conexión queda pendiente y se envía en
/// la próxima sincronización. [isResolved] lo marca Soporte desde el panel.
class SupportTicket extends Equatable {
  const SupportTicket({
    required this.id,
    required this.createdAt,
    required this.category,
    required this.message,
    this.email = '',
    this.context = '',
    this.appVersion = '',
    this.platform = '',
    this.diagnostics = const {},
    this.isResolved = false,
    this.sentAt,
  });

  factory SupportTicket.create({
    required SupportCategory category,
    required String message,
    String email = '',
    String context = '',
    String appVersion = '',
    String platform = '',
    Map<String, String> diagnostics = const {},
  }) =>
      SupportTicket(
        id: const Uuid().v4(),
        createdAt: DateTime.now(),
        category: category,
        message: message.trim(),
        email: email.trim(),
        context: context,
        appVersion: appVersion,
        platform: platform,
        diagnostics: diagnostics,
        isResolved: false,
      );

  factory SupportTicket.fromMap(Map<dynamic, dynamic> map) => SupportTicket(
        id: map['id'] as String? ?? '',
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
            DateTime.now(),
        category: SupportCategory.fromName(map['category'] as String?),
        message: map['message'] as String? ?? '',
        email: map['email'] as String? ?? '',
        context: map['context'] as String? ?? '',
        appVersion: map['appVersion'] as String? ?? '',
        platform: map['platform'] as String? ?? '',
        diagnostics: {
          if (map['diagnostics'] is Map)
            for (final entry in (map['diagnostics'] as Map).entries)
              entry.key.toString(): entry.value.toString(),
        },
        isResolved: map['isResolved'] as bool? ?? false,
        sentAt: DateTime.tryParse(map['sentAt'] as String? ?? ''),
      );

  final String id;
  final DateTime createdAt;
  final SupportCategory category;
  final String message;
  final String email;
  final String context;
  final String appVersion;
  final String platform;
  final Map<String, String> diagnostics;
  final bool isResolved;

  /// Cuándo llegó a Supabase. null = pendiente de envío.
  final DateTime? sentAt;

  bool get isSent => sentAt != null;

  String get subject =>
      '[SeñasGo] ${category.label} · ${_shortDate(createdAt)}';

  Map<String, dynamic> toMap() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'category': category.name,
        'message': message,
        'email': email,
        'context': context,
        'appVersion': appVersion,
        'platform': platform,
        'diagnostics': diagnostics,
        'isResolved': isResolved,
        if (sentAt != null) 'sentAt': sentAt!.toIso8601String(),
      };

  SupportTicket copyWith({bool? isResolved, DateTime? sentAt}) => SupportTicket(
        id: id,
        createdAt: createdAt,
        category: category,
        message: message,
        email: email,
        context: context,
        appVersion: appVersion,
        platform: platform,
        diagnostics: diagnostics,
        isResolved: isResolved ?? this.isResolved,
        sentAt: sentAt ?? this.sentAt,
      );

  /// Texto listo para copiar o pegar en un correo.
  String toReport() {
    final buffer = StringBuffer()
      ..writeln('SeñasGo · ${category.label}')
      ..writeln('Fecha: ${_longDate(createdAt)}')
      ..writeln('Mensaje: $message');
    if (email.isNotEmpty) buffer.writeln('Contacto: $email');
    if (context.isNotEmpty) buffer.writeln('Dónde ocurrió: $context');
    if (appVersion.isNotEmpty) buffer.writeln('Versión: $appVersion');
    if (platform.isNotEmpty) buffer.writeln('Plataforma: $platform');
    if (diagnostics.isNotEmpty) {
      buffer.writeln('Diagnóstico técnico (sin datos personales):');
      for (final entry in diagnostics.entries) {
        buffer.writeln('  ${entry.key}: ${entry.value}');
      }
    }
    return buffer.toString().trimRight();
  }

  static String _shortDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  static String _longDate(DateTime d) =>
      '${_shortDate(d)}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  List<Object?> get props => [
        id,
        createdAt,
        category,
        message,
        email,
        context,
        appVersion,
        platform,
        diagnostics,
        isResolved,
      ];
}
