// ViewModel del avance del estudiante: intentos, lecciones y pistas.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/content_bundle.dart';
import '../../domain/model/evaluation.dart';
import '../../domain/model/finding.dart';
import '../../domain/model/learning.dart';
import '../providers.dart';

class ProgressState {
  final List<AttemptRecord> attempts;
  final Map<String, int> lessonAnswers;
  final Set<String> hints;

  const ProgressState({required this.attempts, required this.lessonAnswers, required this.hints});

  ProgressState copyWith({List<AttemptRecord>? attempts, Map<String, int>? lessonAnswers, Set<String>? hints}) =>
      ProgressState(
        attempts: attempts ?? this.attempts,
        lessonAnswers: lessonAnswers ?? this.lessonAnswers,
        hints: hints ?? this.hints,
      );

  List<AttemptRecord> attemptsFor(String missionId) =>
      attempts.where((a) => a.missionId == missionId).toList()
        ..sort((a, b) => b.timestampMs.compareTo(a.timestampMs));

  /// Mejor intento: primero los aprobados, luego el puntaje más alto.
  AttemptRecord? bestFor(String missionId) {
    AttemptRecord? best;
    for (final a in attempts.where((a) => a.missionId == missionId)) {
      if (best == null ||
          (a.passed && !best.passed) ||
          (a.passed == best.passed && a.overall > best.overall)) {
        best = a;
      }
    }
    return best;
  }

  bool passed(String missionId) => attempts.any((a) => a.missionId == missionId && a.passed);

  bool lessonAnswered(String lessonId) => lessonAnswers.containsKey(lessonId);

  bool lessonCorrect(Lesson lesson) => lessonAnswers[lesson.id] == lesson.check.answer;

  bool hintRevealed(String missionId, int index) => hints.contains('$missionId#$index');

  /// Promedio por dimensión usando el mejor intento de cada misión.
  Map<Dimension, int> dimensionAverages() {
    final missionIds = attempts.map((a) => a.missionId).toSet();
    final out = <Dimension, int>{};
    if (missionIds.isEmpty) return out;
    for (final d in Dimension.values) {
      var sum = 0;
      for (final id in missionIds) {
        sum += bestFor(id)?.scores[d.key] ?? 0;
      }
      out[d] = (sum / missionIds.length).round();
    }
    return out;
  }

  /// Puntaje por competencia (null si todavía no hay intentos).
  Map<Competency, int?> competencies() {
    final dims = dimensionAverages();
    final out = <Competency, int?>{};
    for (final c in Competency.values) {
      if (dims.isEmpty) {
        out[c] = null;
        continue;
      }
      final related = Dimension.values.where((d) => d.competency == c).toList();
      final sum = related.fold<int>(0, (acc, d) => acc + (dims[d] ?? 0));
      out[c] = (sum / related.length).round();
    }
    return out;
  }

  int correctLessons(ContentBundle content) => content.allLessons.where(lessonCorrect).length;
}

class ProgressViewModel extends Notifier<ProgressState> {
  @override
  ProgressState build() {
    final repo = ref.watch(progressRepositoryProvider);
    return ProgressState(
      attempts: repo.attempts(),
      lessonAnswers: repo.lessonAnswers(),
      hints: repo.revealedHints(),
    );
  }

  Future<void> recordAttempt(AttemptRecord record) async {
    state = state.copyWith(attempts: [...state.attempts, record]);
    final repo = ref.read(progressRepositoryProvider);
    await repo.saveAttempt(record);
    state = state.copyWith(attempts: repo.attempts());
  }

  Future<void> answerLesson(String lessonId, int optionIndex) async {
    state = state.copyWith(lessonAnswers: {...state.lessonAnswers, lessonId: optionIndex});
    await ref.read(progressRepositoryProvider).saveLessonAnswer(lessonId, optionIndex);
  }

  Future<void> revealHint(String missionId, int index) async {
    final key = '$missionId#$index';
    state = state.copyWith(hints: {...state.hints, key});
    await ref.read(progressRepositoryProvider).revealHint(key);
  }

  Future<void> resetAll() async {
    await ref.read(progressRepositoryProvider).clear();
    state = const ProgressState(attempts: [], lessonAnswers: {}, hints: {});
  }
}

final progressProvider = NotifierProvider<ProgressViewModel, ProgressState>(ProgressViewModel.new);
