// Informe del evaluador y registro de intentos.

import 'design.dart';
import 'finding.dart';
import 'learning.dart';
import 'sim_result.dart';

class RequirementCheck {
  final String label;
  final String target;
  final String achieved;
  final bool met;

  const RequirementCheck({
    required this.label,
    required this.target,
    required this.achieved,
    required this.met,
  });
}

class Evaluation {
  final List<Finding> findings;
  final Map<Dimension, int> scores;
  final int overall;
  final bool passed;
  final List<RequirementCheck> requirements;

  const Evaluation({
    required this.findings,
    required this.scores,
    required this.overall,
    required this.passed,
    required this.requirements,
  });

  List<Finding> bySeverity(Severity s) => findings.where((f) => f.severity == s).toList();

  int get criticalCount => bySeverity(Severity.critical).length;
  int get warningCount => bySeverity(Severity.warning).length;

  Set<String> get criticalCodes => bySeverity(Severity.critical).map((f) => f.code).toSet();

  /// Puntaje por competencia: promedio de las dimensiones asociadas.
  Map<Competency, int> get competencyScores {
    final out = <Competency, int>{};
    for (final c in Competency.values) {
      final dims = Dimension.values.where((d) => d.competency == c).toList();
      final sum = dims.fold<int>(0, (acc, d) => acc + (scores[d] ?? 0));
      out[c] = (sum / dims.length).round();
    }
    return out;
  }
}

/// Resultado completo de ejecutar un diseño.
class RunOutcome {
  final SystemDesign design;
  final SimResult sim;
  final Evaluation evaluation;

  const RunOutcome({required this.design, required this.sim, required this.evaluation});
}

/// Intento guardado en la bitácora del estudiante.
class AttemptRecord {
  final String missionId;
  final int timestampMs;
  final int overall;
  final bool passed;
  final Map<String, int> scores;
  final int criticalCount;
  final double timeInBandPct;
  final double costPen;
  final SystemDesign design;

  const AttemptRecord({
    required this.missionId,
    required this.timestampMs,
    required this.overall,
    required this.passed,
    required this.scores,
    required this.criticalCount,
    required this.timeInBandPct,
    required this.costPen,
    required this.design,
  });

  factory AttemptRecord.fromOutcome(String missionId, RunOutcome o, DateTime when) => AttemptRecord(
        missionId: missionId,
        timestampMs: when.millisecondsSinceEpoch,
        overall: o.evaluation.overall,
        passed: o.evaluation.passed,
        scores: o.evaluation.scores.map((k, v) => MapEntry(k.key, v)),
        criticalCount: o.evaluation.criticalCount,
        timeInBandPct: o.sim.metrics.timeInBandPct,
        costPen: o.sim.metrics.costPen,
        design: o.design,
      );

  Map<String, dynamic> toJson() => {
        'missionId': missionId,
        'timestampMs': timestampMs,
        'overall': overall,
        'passed': passed,
        'scores': scores,
        'criticalCount': criticalCount,
        'timeInBandPct': timeInBandPct,
        'costPen': costPen,
        'design': design.toJson(),
      };

  factory AttemptRecord.fromJson(Map<String, dynamic> j) => AttemptRecord(
        missionId: j['missionId'] as String,
        timestampMs: (j['timestampMs'] as num).toInt(),
        overall: (j['overall'] as num).toInt(),
        passed: j['passed'] == true,
        scores: (j['scores'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toInt())),
        criticalCount: (j['criticalCount'] as num).toInt(),
        timeInBandPct: (j['timeInBandPct'] as num).toDouble(),
        costPen: (j['costPen'] as num).toDouble(),
        design: SystemDesign.fromJson(j['design'] as Map<String, dynamic>),
      );
}
