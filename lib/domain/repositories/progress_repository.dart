import '../model/design.dart';
import '../model/evaluation.dart';

/// Persistencia local del avance del estudiante.
abstract class ProgressRepository {
  List<AttemptRecord> attempts();
  Future<void> saveAttempt(AttemptRecord record);

  Map<String, int> lessonAnswers();
  Future<void> saveLessonAnswer(String lessonId, int optionIndex);

  SystemDesign? draft(String missionId);
  Future<void> saveDraft(String missionId, SystemDesign design);

  Set<String> revealedHints();
  Future<void> revealHint(String key);

  Future<void> clear();
}
