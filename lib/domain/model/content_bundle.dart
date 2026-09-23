// Todo el contenido declarativo que la aplicación carga al iniciar.

import 'catalog.dart';
import 'finding.dart';
import 'learning.dart';
import 'mission.dart';

class ContentBundle {
  final Catalog catalog;
  final List<Mission> missions;
  final List<LearningModule> modules;
  final Map<String, FindingTemplate> findingTemplates;

  const ContentBundle({
    required this.catalog,
    required this.missions,
    required this.modules,
    required this.findingTemplates,
  });

  Mission mission(String id) => missions.firstWhere((m) => m.id == id);

  LearningModule module(String id) => modules.firstWhere((m) => m.id == id);

  Iterable<Lesson> get allLessons => modules.expand((m) => m.lessons);

  Lesson? lesson(String id) {
    for (final l in allLessons) {
      if (l.id == id) return l;
    }
    return null;
  }

  int get lessonCount => allLessons.length;
}
