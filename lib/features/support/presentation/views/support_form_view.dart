import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/cloud/data/cloud_sync_service.dart';
import 'package:senasgo/features/support/data/support_diagnostics.dart';
import 'package:senasgo/features/support/data/support_repository.dart';
import 'package:senasgo/features/support/domain/support_ticket.dart';
import 'package:senasgo/shared/widgets/pushable_button.dart';

/// Formulario de comentarios, ideas y problemas.
///
/// Un solo botón: el reporte se envía a Soporte (Supabase) y queda en el
/// historial del teléfono. Sin conexión queda pendiente y se envía solo en la
/// próxima sincronización. El contacto es el correo de la cuenta.
class SupportFormView extends StatefulWidget {
  const SupportFormView({
    this.initialCategory = SupportCategory.comment,
    this.contextLabel,
    super.key,
  });

  final SupportCategory initialCategory;
  final String? contextLabel;

  @override
  State<SupportFormView> createState() => _SupportFormViewState();
}

class _SupportFormViewState extends State<SupportFormView> {
  final _message = TextEditingController();
  late SupportCategory _category = widget.initialCategory;
  bool _includeDiagnostics = true;
  bool _saving = false;
  String? _error;
  SupportTicket? _saved;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _message.text.trim();
    if (text.length < 10) {
      setState(
          () => _error = 'Escribí al menos 10 caracteres para entenderte.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final diagnostics = _includeDiagnostics
        ? await SupportDiagnostics.collect()
        : const <String, String>{};
    final app = diagnostics['app'] ?? '';
    final ticket = SupportTicket.create(
      category: _category,
      message: text,
      context: widget.contextLabel ?? '',
      appVersion: app.replaceFirst('SeñasGo ', ''),
      platform: diagnostics['plataforma'] ?? '',
      diagnostics: diagnostics,
    );
    await SupportRepository.save(ticket);
    final sent = await CloudSyncService.sendTicket(ticket);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saved = sent ? ticket.copyWith(sentAt: DateTime.now()) : ticket;
    });
  }

  void _reset() {
    _message.clear();
    setState(() {
      _saved = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_saved == null ? 'Ayuda y comentarios' : 'Reporte enviado'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/help'),
        ),
      ),
      body: SafeArea(
        child: _saved == null ? _form(context) : _success(context, _saved!),
      ),
    );
  }

  Widget _form(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0B3B2E), Color(0xFF0F766E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.forum_outlined, color: Colors.white, size: 30),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tu voz mejora SeñasGo',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900)),
                    SizedBox(height: 4),
                    Text(
                      'Contanos qué pasó o qué te gustaría ver. Guardamos el '
                      'mensaje en tu teléfono para que no se pierda.',
                      style: TextStyle(color: Colors.white70, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (widget.contextLabel != null) ...[
          const SizedBox(height: 14),
          _ContextChip(label: widget.contextLabel!),
        ],
        const SizedBox(height: 22),
        Text('¿Qué querés contarnos?',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.ink)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final category in SupportCategory.values)
              _CategoryChip(
                category: category,
                selected: _category == category,
                onTap: () => setState(() => _category = category),
              ),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _message,
          minLines: 5,
          maxLines: 8,
          maxLength: 1200,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Mensaje',
            hintText: _hintFor(_category),
            alignLabelWithHint: true,
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: AppColors.outlineStrong),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: AppColors.outlineStrong),
            ),
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        const SizedBox(height: 6),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          value: _includeDiagnostics,
          onChanged: (v) => setState(() => _includeDiagnostics = v),
          contentPadding: EdgeInsets.zero,
          activeThumbColor: AppColors.primary,
          title: const Text('Incluir datos técnicos',
              style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
            'Versión, plataforma y tipo de equipo. Sin fotos ni cámara.',
            style: TextStyle(color: AppColors.muted, fontSize: 12.5),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.errorSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: AppColors.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!,
                      style: TextStyle(
                          color: AppColors.error, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        PushableButton(
          onPressed: _saving ? null : _submit,
          color: AppColors.primary,
          shadowColor: const Color(0xFF115E59),
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                )
              : const Text('ENVIAR REPORTE',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      letterSpacing: 0.4)),
        ),
        const SizedBox(height: 12),
        Text(
          'El reporte queda en este teléfono. Para enviarlo, después podés '
          'copiarlo o abrir tu correo. SeñasGo no tiene servidores ni recibe '
          'datos automáticamente.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4),
        ),
      ],
    );
  }

  Widget _success(BuildContext context, SupportTicket ticket) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.successSoft,
              shape: BoxShape.circle,
            ),
            child:
                Icon(Icons.check_rounded, size: 54, color: AppColors.success),
          ),
        ),
        const SizedBox(height: 18),
        Text(ticket.isSent ? '¡Reporte enviado!' : '¡Gracias por escribirnos!',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w900,
                color: AppColors.ink)),
        const SizedBox(height: 8),
        Text(
          ticket.isSent
              ? 'Le llegó al equipo de soporte. Te respondemos al correo de tu '
                  'cuenta y vas a ver el estado en Ayuda → Tus reportes.'
              : 'No hay conexión ahora. Tu reporte quedó guardado y se envía '
                  'solo apenas vuelva internet.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, height: 1.45),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _CategoryBadge(category: ticket.category),
                  const Spacer(),
                  Text(
                    '${ticket.createdAt.day.toString().padLeft(2, '0')}/'
                    '${ticket.createdAt.month.toString().padLeft(2, '0')}/'
                    '${ticket.createdAt.year}',
                    style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(ticket.message,
                  style: TextStyle(color: AppColors.ink, height: 1.4)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        TextButton.icon(
          onPressed: _reset,
          icon: const Icon(Icons.add_comment_outlined),
          label: const Text('Escribir otro reporte'),
        ),
        TextButton(
          onPressed: () => context.go('/help'),
          child: const Text('Volver a Ayuda'),
        ),
      ],
    );
  }

  String _hintFor(SupportCategory category) => switch (category) {
        SupportCategory.bug =>
          'Ej.: al abrir la cámara la pantalla queda en negro. Uso un Moto G.',
        SupportCategory.idea =>
          'Ej.: me gustaría poder practicar dos señas seguidas.',
        SupportCategory.content =>
          'Ej.: la demostración de “gracias” no coincide con lo que aprendí.',
        SupportCategory.comment =>
          'Ej.: la app me resultó fácil de usar, pero el texto es pequeño.',
      };
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final SupportCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      label: Text(category.label),
      avatar: Icon(_iconFor(category),
          size: 18, color: selected ? AppColors.onPrimary : AppColors.primary),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      side: BorderSide(color: AppColors.outlineStrong),
      labelStyle: TextStyle(
        color: selected ? AppColors.onPrimary : AppColors.ink,
        fontWeight: FontWeight.w800,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}

class _ContextChip extends StatelessWidget {
  const _ContextChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.place_outlined, size: 17, color: AppColors.primary),
          const SizedBox(width: 7),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});

  final SupportCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconFor(category), size: 14, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(category.label,
              style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800)),
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
