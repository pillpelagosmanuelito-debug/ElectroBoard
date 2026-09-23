// Hallazgos del evaluador de diseño.

import 'learning.dart';

enum Severity {
  critical('Crítico', 45),
  warning('Advertencia', 15),
  suggestion('Sugerencia', 5),
  positive('Acierto', 0);

  const Severity(this.label, this.penalty);

  final String label;
  final int penalty;
}

/// Dimensiones de la rúbrica. Coinciden con los módulos más la lógica de control.
enum Dimension {
  arquitectura('arquitectura', 'Arquitectura', Competency.disenar),
  sensores('sensores', 'Sensores', Competency.integrar),
  actuadores('actuadores', 'Actuadores', Competency.integrar),
  comunicacion('comunicacion', 'Comunicación', Competency.disenar),
  iot('iot', 'IoT', Competency.disenar),
  logica('logica', 'Lógica de control', Competency.programar);

  const Dimension(this.key, this.label, this.competency);

  final String key;
  final String label;
  final Competency competency;

  static Dimension fromKey(String key) =>
      Dimension.values.firstWhere((d) => d.key == key, orElse: () => Dimension.arquitectura);
}

class FindingTemplate {
  final String title;
  final String message;
  final String fix;
  final String lessonId;

  const FindingTemplate({
    required this.title,
    required this.message,
    required this.fix,
    required this.lessonId,
  });

  factory FindingTemplate.fromJson(Map<String, dynamic> j) => FindingTemplate(
        title: j['title']?.toString() ?? '',
        message: j['message']?.toString() ?? '',
        fix: j['fix']?.toString() ?? '',
        lessonId: j['lessonId']?.toString() ?? '',
      );

  /// Reemplaza los marcadores {clave} por los valores del hallazgo.
  static String fill(String template, Map<String, String> params) {
    var out = template;
    params.forEach((k, v) => out = out.replaceAll('{$k}', v));
    return out;
  }
}

class Finding {
  final String code;
  final Dimension dimension;
  final Severity severity;
  final String title;
  final String message;
  final String fix;
  final String lessonId;

  const Finding({
    required this.code,
    required this.dimension,
    required this.severity,
    required this.title,
    required this.message,
    required this.fix,
    required this.lessonId,
  });
}
