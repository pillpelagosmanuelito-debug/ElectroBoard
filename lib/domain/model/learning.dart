// Módulos de aprendizaje y lecciones breves con pregunta de control.

String _s(Object? v) => v?.toString() ?? '';
List<String> _ls(Object? v) =>
    (v as List<dynamic>? ?? const <dynamic>[]).map((e) => e.toString()).toList();

/// Las tres competencias del encargo.
enum Competency {
  disenar('disenar', 'Diseñar sistemas completos'),
  integrar('integrar', 'Integrar sensores y actuadores'),
  programar('programar', 'Programar dispositivos');

  const Competency(this.key, this.label);

  final String key;
  final String label;

  static Competency fromKey(String key) =>
      Competency.values.firstWhere((c) => c.key == key, orElse: () => Competency.disenar);
}

class CheckQuestion {
  final String prompt;
  final List<String> options;
  final int answer;
  final String explanation;

  const CheckQuestion({
    required this.prompt,
    required this.options,
    required this.answer,
    required this.explanation,
  });

  factory CheckQuestion.fromJson(Map<String, dynamic> j) => CheckQuestion(
        prompt: _s(j['prompt']),
        options: _ls(j['options']),
        answer: (j['answer'] as num).toInt(),
        explanation: _s(j['explanation']),
      );
}

class Lesson {
  final String id;
  final String moduleId;
  final String title;
  final String summary;
  final List<String> body;
  final List<String> keyPoints;
  final String? formula;
  final String inDesign;
  final CheckQuestion check;

  const Lesson({
    required this.id,
    required this.moduleId,
    required this.title,
    required this.summary,
    required this.body,
    required this.keyPoints,
    required this.formula,
    required this.inDesign,
    required this.check,
  });

  factory Lesson.fromJson(Map<String, dynamic> j, String moduleId) => Lesson(
        id: _s(j['id']),
        moduleId: moduleId,
        title: _s(j['title']),
        summary: _s(j['summary']),
        body: _ls(j['body']),
        keyPoints: _ls(j['keyPoints']),
        formula: j['formula'] as String?,
        inDesign: _s(j['inDesign']),
        check: CheckQuestion.fromJson(j['check'] as Map<String, dynamic>),
      );
}

class LearningModule {
  final String id;
  final int order;
  final String title;
  final String tagline;
  final Competency competency;
  final List<Lesson> lessons;

  const LearningModule({
    required this.id,
    required this.order,
    required this.title,
    required this.tagline,
    required this.competency,
    required this.lessons,
  });

  factory LearningModule.fromJson(Map<String, dynamic> j) {
    final id = _s(j['id']);
    return LearningModule(
      id: id,
      order: (j['order'] as num).toInt(),
      title: _s(j['title']),
      tagline: _s(j['tagline']),
      competency: Competency.fromKey(_s(j['competency'])),
      lessons: (j['lessons'] as List<dynamic>)
          .map((e) => Lesson.fromJson(e as Map<String, dynamic>, id))
          .toList(),
    );
  }
}
