// ViewModel de la mesa de trabajo (pantalla principal).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/content_bundle.dart';
import '../../domain/model/evaluation.dart';
import '../../domain/model/learning.dart';
import '../../domain/model/mission.dart';
import '../providers.dart';

class MissionCardData {
  final Mission mission;
  final int attempts;
  final AttemptRecord? best;

  const MissionCardData({required this.mission, required this.attempts, required this.best});

  bool get passed => best?.passed ?? false;
  bool get started => attempts > 0;
}

class ModuleCardData {
  final LearningModule module;
  final int answered;
  final int correct;

  const ModuleCardData({required this.module, required this.answered, required this.correct});

  int get total => module.lessons.length;
  double get progress => total == 0 ? 0 : answered / total;
}

class WorkbenchSummary {
  final List<MissionCardData> missions;
  final List<ModuleCardData> modules;
  final Map<Competency, int?> competencies;

  const WorkbenchSummary({required this.missions, required this.modules, required this.competencies});

  int get passedCount => missions.where((m) => m.passed).length;

  /// Siguiente misión sugerida: la primera sin aprobar.
  MissionCardData? get next {
    for (final m in missions) {
      if (!m.passed) return m;
    }
    return null;
  }

  static WorkbenchSummary build(ContentBundle content, ProgressState progress) => WorkbenchSummary(
        missions: content.missions
            .map((m) => MissionCardData(
                  mission: m,
                  attempts: progress.attemptsFor(m.id).length,
                  best: progress.bestFor(m.id),
                ))
            .toList(),
        modules: content.modules
            .map((mod) => ModuleCardData(
                  module: mod,
                  answered: mod.lessons.where((l) => progress.lessonAnswered(l.id)).length,
                  correct: mod.lessons.where(progress.lessonCorrect).length,
                ))
            .toList(),
        competencies: progress.competencies(),
      );
}

final workbenchProvider = Provider<AsyncValue<WorkbenchSummary>>((ref) {
  final content = ref.watch(contentProvider);
  final progress = ref.watch(progressProvider);
  return content.whenData((c) => WorkbenchSummary.build(c, progress));
});
