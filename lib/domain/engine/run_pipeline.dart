// Orquesta simulación y evaluación de un diseño completo.

import '../evaluator/design_evaluator.dart';
import '../model/content_bundle.dart';
import '../model/design.dart';
import '../model/evaluation.dart';
import '../model/mission.dart';
import 'system_simulator.dart';

class RunPipeline {
  const RunPipeline({this.simulator = const SystemSimulator()});

  final SystemSimulator simulator;

  RunOutcome run(ContentBundle content, Mission mission, SystemDesign design) {
    final sim = simulator.run(mission, content.catalog, design);
    final evaluation = DesignEvaluator(content.findingTemplates).evaluate(mission, content.catalog, design, sim);
    return RunOutcome(design: design, sim: sim, evaluation: evaluation);
  }
}
