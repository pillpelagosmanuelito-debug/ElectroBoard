import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/model/design.dart';
import '../../domain/model/evaluation.dart';
import '../../domain/repositories/progress_repository.dart';

/// Guarda el avance en SharedPreferences como JSON.
class PrefsProgressRepository implements ProgressRepository {
  PrefsProgressRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _kAttempts = 'eb.attempts.v1';
  static const _kLessons = 'eb.lessons.v1';
  static const _kDraftPrefix = 'eb.draft.v1.';
  static const _kHints = 'eb.hints.v1';

  /// Máximo de intentos guardados por misión (los más recientes).
  static const maxAttemptsPerMission = 30;

  @override
  List<AttemptRecord> attempts() {
    final raw = _prefs.getString(_kAttempts);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => AttemptRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveAttempt(AttemptRecord record) async {
    final all = attempts()..add(record);
    final byMission = <String, List<AttemptRecord>>{};
    for (final a in all) {
      byMission.putIfAbsent(a.missionId, () => []).add(a);
    }
    final trimmed = <AttemptRecord>[];
    for (final list in byMission.values) {
      list.sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
      final start = list.length > maxAttemptsPerMission ? list.length - maxAttemptsPerMission : 0;
      trimmed.addAll(list.sublist(start));
    }
    trimmed.sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
    await _prefs.setString(_kAttempts, jsonEncode(trimmed.map((e) => e.toJson()).toList()));
  }

  @override
  Map<String, int> lessonAnswers() {
    final raw = _prefs.getString(_kLessons);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> saveLessonAnswer(String lessonId, int optionIndex) async {
    final all = lessonAnswers()..[lessonId] = optionIndex;
    await _prefs.setString(_kLessons, jsonEncode(all));
  }

  @override
  SystemDesign? draft(String missionId) {
    final raw = _prefs.getString('$_kDraftPrefix$missionId');
    if (raw == null) return null;
    try {
      return SystemDesign.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveDraft(String missionId, SystemDesign design) async {
    await _prefs.setString('$_kDraftPrefix$missionId', jsonEncode(design.toJson()));
  }

  @override
  Set<String> revealedHints() => (_prefs.getStringList(_kHints) ?? const <String>[]).toSet();

  @override
  Future<void> revealHint(String key) async {
    final all = revealedHints()..add(key);
    await _prefs.setStringList(_kHints, all.toList());
  }

  @override
  Future<void> clear() async {
    final keys = _prefs.getKeys().where((k) => k.startsWith('eb.')).toList();
    for (final k in keys) {
      await _prefs.remove(k);
    }
  }
}
