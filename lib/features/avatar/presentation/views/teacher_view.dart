import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:senasgo/core/services/hive_service.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/avatar/presentation/widgets/guided_teacher.dart';
import 'package:senasgo/features/support/presentation/support_actions.dart';

/// Vista inmersiva del profesor 3D, para mirar la seña con comodidad.
class TeacherView extends StatelessWidget {
  const TeacherView({required this.signId, super.key});

  final String signId;

  @override
  Widget build(BuildContext context) {
    final sign = HiveService.signById(signId);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profesor Jaguareté'),
        actions: [
          IconButton(
            tooltip: 'Ayuda y comentarios',
            onPressed: () => SupportSheet.show(context,
                contextLabel: 'Profesor 3D · ${sign?.name ?? signId}'),
            icon: const Icon(Icons.support_agent_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              GuidedTeacher(
                signId: signId,
                height: (box.maxHeight - 300).clamp(250.0, 620.0),
              ),
              const SizedBox(height: 16),
              if (sign != null) ...[
                Text(sign.name,
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink)),
                const SizedBox(height: 4),
                Text(sign.description,
                    style: TextStyle(
                        fontSize: 15, color: AppColors.muted, height: 1.4)),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => context.push('/practice?sign=${sign.id}'),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('PRACTICAR ESTA SEÑA'),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/library'),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Volver'),
              ),
              const SizedBox(height: 10),
              Text(
                'Las demostraciones son ilustrativas y están pendientes de '
                'validación por una persona experta en LSPy.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
