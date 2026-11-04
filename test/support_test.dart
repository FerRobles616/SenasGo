import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:senasgo/core/services/hive_service.dart';
import 'package:senasgo/features/support/data/support_repository.dart';
import 'package:senasgo/features/support/domain/support_ticket.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('senasgo_support');
    Hive.init(dir.path);
    await HiveService.registerAdapters();
    await HiveService.initBoxes();
  });

  setUp(() => SupportRepository.clear());

  tearDownAll(() async {
    await Hive.deleteFromDisk();
  });

  test('Guarda, lista y elimina reportes locales', () async {
    final ticket = SupportTicket.create(
      category: SupportCategory.bug,
      message: 'La cámara queda negra en mi teléfono.',
      email: 'persona@example.com',
      context: 'Práctica · Hola',
    );
    await SupportRepository.save(ticket);

    final saved = SupportRepository.tickets;
    expect(saved, hasLength(1));
    expect(saved.single.id, ticket.id);
    expect(saved.single.message, contains('cámara'));
    expect(SupportRepository.count, 1);

    await SupportRepository.delete(ticket.id);
    expect(SupportRepository.tickets, isEmpty);
  });

  test('Marcar como resuelto persiste el cambio', () async {
    final ticket = SupportTicket.create(
      category: SupportCategory.idea,
      message: 'Me gustaría practicar dos señas seguidas.',
    );
    await SupportRepository.save(ticket);

    await SupportRepository.setResolved(ticket.id, true);
    expect(SupportRepository.tickets.single.isResolved, isTrue);

    await SupportRepository.setResolved(ticket.id, false);
    expect(SupportRepository.tickets.single.isResolved, isFalse);
  });

  test('El reporte de texto no incluye datos vacíos', () {
    final ticket = SupportTicket.create(
      category: SupportCategory.content,
      message: 'La demostración de gracias no coincide con la guía.',
      diagnostics: const {'plataforma': 'Android'},
    );
    final text = ticket.toReport();

    expect(text, contains('Contenido'));
    expect(text, contains('La demostración de gracias'));
    expect(text, contains('plataforma: Android'));
    expect(text, isNot(contains('Contacto:')));
    expect(ticket.subject, startsWith('[SeñasGo]'));
  });
}
