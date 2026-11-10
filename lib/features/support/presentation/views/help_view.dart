import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:senasgo/core/constants/app_constants.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/support/data/support_repository.dart';
import 'package:senasgo/features/support/domain/support_ticket.dart';
import 'package:senasgo/shared/widgets/app_bottom_nav.dart';
import 'package:senasgo/shared/widgets/pushable_button.dart';

/// Centro de ayuda offline: preguntas frecuentes, reportes guardados y
/// datos de contacto. Reemplaza a la antigua tienda en la navegación.
class HelpView extends StatefulWidget {
  const HelpView({super.key});

  @override
  State<HelpView> createState() => _HelpViewState();
}

class _HelpViewState extends State<HelpView> {
  late List<SupportTicket> _tickets = SupportRepository.tickets;

  void _refresh() => setState(() => _tickets = SupportRepository.tickets);

  Future<void> _newReport([SupportCategory? category]) async {
    await context.push(
        '/support${category == null ? '' : '?category=${category.name}'}');
    if (mounted) _refresh();
  }

  void _openTicket(SupportTicket ticket) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => _TicketSheet(
        ticket: ticket,
        onChanged: () {
          _refresh();
          if (sheetContext.mounted) Navigator.of(sheetContext).pop();
        },
      ),
    ).then((_) {
      if (mounted) _refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Pestaña raíz: sin flecha aunque Aprender la abra con push.
        automaticallyImplyLeading: false,
        title: const Text('Ayuda'),
        actions: [
          IconButton(
            tooltip: 'Nuevo reporte',
            onPressed: _newReport,
            icon: const Icon(Icons.add_comment_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _Hero(onReport: _newReport),
          const SizedBox(height: 24),
          _SectionTitle(
            title: 'Tus reportes',
            subtitle: _tickets.isEmpty
                ? 'Todavía no guardaste ninguno.'
                : '${_tickets.length} guardado${_tickets.length == 1 ? '' : 's'} en este teléfono.',
          ),
          const SizedBox(height: 10),
          if (_tickets.isEmpty)
            _EmptyTickets(onReport: _newReport)
          else
            for (final ticket in _tickets) ...[
              _TicketCard(ticket: ticket, onTap: () => _openTicket(ticket)),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 26),
          const _SectionTitle(
            title: 'Preguntas frecuentes',
            subtitle: 'Respuestas cortas para seguir aprendiendo.',
          ),
          const SizedBox(height: 10),
          for (final faq in _faqs) _FaqTile(faq: faq),
          const SizedBox(height: 18),
          const _AboutCard(),
          const SizedBox(height: 10),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onReport});

  final Future<void> Function([SupportCategory? category]) onReport;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B3B2E), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.support_agent_rounded, color: Colors.white, size: 34),
              SizedBox(width: 10),
              Expanded(
                child: Text('Estamos para ayudarte',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Contanos si algo no funciona, si una seña no se entiende o si '
            'tenés una idea. Tu mensaje queda guardado en tu teléfono.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 16),
          PushableButton(
            onPressed: () => onReport(),
            color: Colors.white,
            shadowColor: const Color(0xFFBFD9FF),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text('ESCRIBIR UN REPORTE',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
                        letterSpacing: 0.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Faq {
  const _Faq(this.question, this.answer);

  final String question;
  final String answer;
}

const _faqs = [
  _Faq(
    '¿Necesito una cuenta?',
    'Sí. Para usar SeñasGo creás una cuenta con tu nombre, tu correo y una '
        'contraseña. Así tu progreso queda guardado y lo recuperás en '
        'cualquier teléfono.',
  ),
  _Faq(
    '¿Necesito internet para usar SeñasGo?',
    'Solo para crear la cuenta o iniciar sesión. Después, las lecciones, el '
        'profesor 3D y la práctica funcionan sin conexión, y tu progreso se '
        'sincroniza solo cuando vuelve internet.',
  ),
  _Faq(
    'Olvidé mi contraseña, ¿qué hago?',
    'En la pantalla de inicio, entrá a Iniciar sesión y tocá «¿Olvidaste tu '
        'contraseña?». Escribí tu correo, te llega un código de 6 dígitos y '
        'con ese código creás una contraseña nueva.',
  ),
  _Faq(
    '¿Qué pasa si cambio de teléfono o cierro sesión?',
    'Tu progreso está en tu cuenta: en otro teléfono iniciás sesión y sigue '
        'todo. Al cerrar sesión, el progreso se borra de este teléfono (no de '
        'tu cuenta), para que otra persona no vea tus datos.',
  ),
  _Faq(
    '¿Qué datos guarda mi cuenta?',
    'Tu nombre, correo, XP, señas aprendidas, intentos de práctica, racha, '
        'retos, cofres y preferencias. Nunca imágenes de la cámara. Solo vos '
        'podés ver tus datos; Soporte ve únicamente los reportes que enviás.',
  ),
  _Faq(
    '¿La cámara graba o envía mis imágenes?',
    'No. La cámara se usa solo para analizar la forma de tu mano en el '
        'momento. Las imágenes no se guardan, no se suben y no salen del '
        'teléfono.',
  ),
  _Faq(
    '¿Cómo practico una seña?',
    'En Aprender, tocá la seña actual y elegí PRACTICAR. Primero ves la '
        'demostración del profesor; después buscás luz pareja, ponés la mano '
        'dentro del recuadro y tocás Comenzar.',
  ),
  _Faq(
    '¿Puedo aprender sin cámara?',
    'Sí. La biblioteca, el profesor 3D paso a paso y el repaso rápido '
        'funcionan aunque el teléfono no tenga cámara o no des permiso. Solo '
        'la práctica con la mano la necesita.',
  ),
  _Faq(
    '¿Por qué la demostración dice “por validar”?',
    'Las señas del profesor 3D son ilustrativas y están pendientes de '
        'revisión por una persona experta en LSPy. Sirven para practicar la '
        'forma general, no como referencia oficial del idioma.',
  ),
  _Faq(
    '¿Cómo funcionan los XP, los retos y los cofres?',
    'Ganás XP con cada seña correcta y al reclamar retos. Al completar una '
        'lección se abre un cofre con XP extra o un protector de racha. Los XP '
        'suben tu nivel; no se compran ni se gastan.',
  ),
  _Faq(
    '¿Cómo envío un reporte?',
    'En Ayuda, escribí lo que pasó y tocá Enviar reporte: le llega directo '
        'al equipo de soporte. Si no tenés conexión, se envía solo cuando '
        'vuelva internet. En Tus reportes ves si ya está resuelto.',
  ),
  _Faq(
    '¿Cómo borro mi cuenta?',
    'Enviá un reporte pidiéndolo desde la cuenta que querés borrar. El '
        'equipo la elimina junto con todos tus datos.',
  ),
];

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.faq});

  final _Faq faq;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: AppColors.primary,
        collapsedIconColor: AppColors.muted,
        title: Text(faq.question,
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
                color: AppColors.ink)),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(faq.answer,
                style: TextStyle(
                    color: AppColors.muted, height: 1.45, fontSize: 13.5)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.ink)),
        const SizedBox(height: 3),
        Text(subtitle,
            style: TextStyle(color: AppColors.muted, fontSize: 13.5)),
      ],
    );
  }
}

class _EmptyTickets extends StatelessWidget {
  const _EmptyTickets({required this.onReport});

  final Future<void> Function([SupportCategory? category]) onReport;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.inbox_outlined, size: 26, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No hay reportes guardados',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: AppColors.ink)),
                Text(
                  'Escribinos si algo falla o querés proponer una mejora.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => onReport(SupportCategory.idea),
            child: const Text('Sugerir'),
          ),
        ],
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onTap});

  final SupportTicket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final resolved = ticket.isResolved;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color:
                      resolved ? AppColors.successSoft : AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  resolved
                      ? Icons.check_circle_outline_rounded
                      : _iconFor(ticket.category),
                  color: resolved ? AppColors.success : AppColors.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(ticket.category.label,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 13.5)),
                        const Spacer(),
                        Text(
                          '${ticket.createdAt.day.toString().padLeft(2, '0')}/'
                          '${ticket.createdAt.month.toString().padLeft(2, '0')}',
                          style:
                              TextStyle(color: AppColors.muted, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ticket.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppColors.muted, fontSize: 13, height: 1.35),
                    ),
                    const SizedBox(height: 5),
                    Text(
                        resolved
                            ? 'Resuelto por soporte'
                            : ticket.isSent
                                ? 'Enviado · en revisión'
                                : 'Pendiente de envío (sin conexión)',
                        style: TextStyle(
                            color: resolved
                                ? AppColors.success
                                : ticket.isSent
                                    ? AppColors.primary
                                    : AppColors.muted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketSheet extends StatelessWidget {
  const _TicketSheet({required this.ticket, required this.onChanged});

  final SupportTicket ticket;
  final VoidCallback onChanged;

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Borrar este reporte?'),
        content: const Text(
            'Se borra del historial de este teléfono. Si ya se envió, el '
            'equipo de soporte lo sigue teniendo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await SupportRepository.delete(ticket.id);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.locked,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(ticket.category.label,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink)),
                const Spacer(),
                if (ticket.isResolved)
                  Chip(
                    label: Text('Resuelto'),
                    backgroundColor: AppColors.successSoft,
                    labelStyle: TextStyle(
                        color: AppColors.success, fontWeight: FontWeight.w700),
                    side: BorderSide.none,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${ticket.createdAt.day.toString().padLeft(2, '0')}/'
              '${ticket.createdAt.month.toString().padLeft(2, '0')}/'
              '${ticket.createdAt.year} · '
              '${ticket.isSent ? 'enviado a soporte' : 'pendiente de envío'}',
              style: TextStyle(color: AppColors.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(18),
              ),
              child: SingleChildScrollView(
                child: Text(ticket.message,
                    style: TextStyle(
                        color: AppColors.ink, height: 1.45, fontSize: 14)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => _delete(context),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Borrar reporte'),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sobre SeñasGo',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppColors.ink)),
          const SizedBox(height: 8),
          Text(
            'Versión ${AppConstants.appVersion} · Aprendizaje inicial de '
            'Lengua de Señas Paraguaya (LSPy).',
            style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 8),
          Text(
            'Las demostraciones 3D y los valores de referencia son '
            'ilustrativos y deben ser validados por una persona experta en '
            'LSPy antes de usarse como material oficial.',
            style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.mail_outline_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 7),
              SelectableText(AppConstants.supportEmail,
                  style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5)),
            ],
          ),
        ],
      ),
    );
  }
}

IconData _iconFor(SupportCategory category) => switch (category) {
      SupportCategory.bug => Icons.bug_report_outlined,
      SupportCategory.idea => Icons.lightbulb_outline_rounded,
      SupportCategory.content => Icons.sign_language_outlined,
      SupportCategory.comment => Icons.chat_bubble_outline_rounded,
    };
