// ViewModel de la bitácora: historial de intentos y competencias.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/content_bundle.dart';
import '../../domain/model/evaluation.dart';
import '../../domain/model/finding.dart';
import '../../domain/model/learning.dart';
import '../../domain/model/mission.dart';
import '../providers.dart';

class MissionLog {
  final Mission mission;
  final List<AttemptRecord> attempts;
  final AttemptRecord? best;

  const MissionLog({required this.mission, required this.attempts, required this.best});

  /// Puntajes en orden cronológico, para la mini gráfica de evolución.
  List<int> get trend => attempts.reversed.map((a) => a.overall).toList();
}

class LogbookSummary {
  final Map<Competency, int?> competencies;
  final Map<Dimension, int> dimensions;
  final List<MissionLog> missions;
  final int lessonsCorrect;
  final int lessonsTotal;
  final int totalAttempts;

  const LogbookSummary({
    required this.competencies,
    required this.dimensions,
    required this.missions,
    required this.lessonsCorrect,
    required this.lessonsTotal,
    required this.totalAttempts,
  });

  static LogbookSummary build(ContentBundle content, ProgressState progress) => LogbookSummary(
        competencies: progress.competencies(),
        dimensions: progress.dimensionAverages(),
        missions: content.missions
            .map((m) => MissionLog(mission: m, attempts: progress.attemptsFor(m.id), best: progress.bestFor(m.id)))
            .toList(),
        lessonsCorrect: progress.correctLessons(content),
        lessonsTotal: content.lessonCount,
        totalAttempts: progress.attempts.length,
      );
}

final logbookProvider = Provider<AsyncValue<LogbookSummary>>((ref) {
  final content = ref.watch(contentProvider);
  final progress = ref.watch(progressProvider);
  return content.whenData((c) => LogbookSummary.build(c, progress));
});
