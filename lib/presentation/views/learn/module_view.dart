import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/board_theme.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../mission/mission_brief_view.dart';
import 'lesson_view.dart';

/// Módulo de aprendizaje: lecciones y proyectos relacionados.
class ModuleView extends ConsumerWidget {
  const ModuleView({super.key, required this.moduleId});

  final String moduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentProvider);
    final progress = ref.watch(progressProvider);
    return content.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (e, _) => Scaffold(body: ErrorView(error: e)),
      data: (c) {
        final mod = c.module(moduleId);
        final related = c.missions.where((m) => m.modules.contains(mod.id)).toList();
        return Scaffold(
          appBar: AppBar(title: Text('M${mod.order} · ${mod.title}')),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(mod.tagline, style: const TextStyle(fontSize: 15, height: 1.4)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: SpecChip('Competencia: ${mod.competency.label}', color: BoardColors.signal, icon: Icons.school_outlined),
              ),
              const SectionTitle('Lecciones'),
              for (var i = 0; i < mod.lessons.length; i++)
                BoardPanel(
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => LessonView(lessonId: mod.lessons[i].id))),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: progress.lessonAnswered(mod.lessons[i].id) ? BoardColors.ok : BoardColors.maskDeep,
                          border: Border.all(color: BoardColors.trace),
                        ),
                        child: progress.lessonAnswered(mod.lessons[i].id)
                            ? const Icon(Icons.check, size: 18, color: BoardColors.maskDeep)
                            : Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(mod.lessons[i].title, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(mod.lessons[i].summary,
                                style: const TextStyle(color: BoardColors.silkDim, fontSize: 12.5, height: 1.3)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              if (related.isNotEmpty) ...[
                const SectionTitle('Aplícalo en un proyecto'),
                for (final m in related)
                  BoardPanel(
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => MissionBriefView(missionId: m.id))),
                    child: Row(
                      children: [
                        Text(m.code, style: BoardTheme.mono.copyWith(color: BoardColors.copper)),
                        const SizedBox(width: 12),
                        Expanded(child: Text(m.title)),
                        StatusLed(color: progress.passed(m.id) ? BoardColors.ok : BoardColors.trace,
                            glow: progress.passed(m.id)),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}
