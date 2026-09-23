// ViewModel del tablero de diseño: el sistema que arma el estudiante.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/catalog.dart';
import '../../domain/model/content_bundle.dart';
import '../../domain/model/design.dart';
import '../../domain/model/evaluation.dart';
import '../../domain/model/mission.dart';
import '../providers.dart';

class BenchState {
  final ContentBundle content;
  final Mission mission;
  final SystemDesign design;
  final RunOutcome? lastRun;

  const BenchState({
    required this.content,
    required this.mission,
    required this.design,
    this.lastRun,
  });

  BenchState copyWith({SystemDesign? design, RunOutcome? lastRun, bool clearRun = false}) => BenchState(
        content: content,
        mission: mission,
        design: design ?? this.design,
        lastRun: clearRun ? null : (lastRun ?? this.lastRun),
      );

  Catalog get catalog => content.catalog;

  /// Componentes disponibles para una ranura, según el catálogo curado de la misión.
  List<PartSpec> poolFor(PartKind kind) {
    final ids = switch (kind) {
      PartKind.sensor => mission.pools.sensors,
      PartKind.controller => mission.pools.controllers,
      PartKind.actuator => mission.pools.actuators,
      PartKind.comm => mission.pools.comms,
      PartKind.power => mission.pools.power,
    };
    return ids.map((id) => catalog.part(kind, id)).toList();
  }

  PartSpec? selected(PartKind kind) {
    final id = design.partId(kind);
    return id == null ? null : catalog.part(kind, id);
  }

  /// Costo estimado con los bloques elegidos hasta ahora.
  double get estimatedCost {
    var total = 0.0;
    for (final kind in PartKind.values) {
      final part = selected(kind);
      if (part == null) continue;
      if (part is CommSpec) {
        final ctrl = selected(PartKind.controller);
        final builtIn = ctrl is ControllerSpec && part.builtInKey.isNotEmpty && ctrl.builtInComms.contains(part.builtInKey);
        if (!builtIn && !part.isNone && part.tech != 'usb') total += part.moduleCostPen;
      } else {
        total += part.costPen;
      }
    }
    if (design.conditioning) total += 4;
    return total;
  }

  bool get overBudget => estimatedCost > mission.requirements.budgetPen;

  List<PartKind> get missingSlots => PartKind.values.where((k) => design.partId(k) == null).toList();
}

class BenchViewModel extends Notifier<BenchState?> {
  @override
  BenchState? build() => null;

  /// Abre una misión recuperando el borrador guardado, si existe.
  void open(ContentBundle content, Mission mission) {
    final current = state;
    if (current != null && current.mission.id == mission.id) return;
    final draft = ref.read(progressRepositoryProvider).draft(mission.id);
    state = BenchState(
      content: content,
      mission: mission,
      design: _sanitize(content, mission, draft) ?? SystemDesign(logic: mission.defaultLogic),
    );
  }

  /// Descarta borradores con identificadores que ya no existen en el catálogo.
  SystemDesign? _sanitize(ContentBundle content, Mission mission, SystemDesign? draft) {
    if (draft == null) return null;
    final pools = mission.pools;
    bool ok(String? id, List<String> pool) => id == null || pool.contains(id);
    if (!ok(draft.sensorId, pools.sensors) ||
        !ok(draft.controllerId, pools.controllers) ||
        !ok(draft.actuatorId, pools.actuators) ||
        !ok(draft.commId, pools.comms) ||
        !ok(draft.powerId, pools.power) ||
        !mission.logic.algorithms.contains(draft.logic.algorithm)) {
      return null;
    }
    return draft;
  }

  void selectPart(PartKind kind, String id) => _update((d) => d.withPart(kind, id));

  void setConditioning(bool value) => _update((d) => d.copyWith(conditioning: value));

  void updateLogic(LogicConfig logic) => _update((d) => d.copyWith(logic: logic));

  void resetDesign() {
    final s = state;
    if (s == null) return;
    _update((_) => SystemDesign(logic: s.mission.defaultLogic));
  }

  void loadReference() {
    final s = state;
    if (s == null) return;
    _update((_) => s.mission.referenceDesign);
  }

  /// Simula y evalúa el diseño actual; guarda el intento en la bitácora.
  RunOutcome? run() {
    final s = state;
    if (s == null || !s.design.isComplete) return null;
    final outcome = ref.read(runPipelineProvider).run(s.content, s.mission, s.design);
    state = s.copyWith(lastRun: outcome);
    final now = ref.read(clockProvider)();
    ref.read(progressProvider.notifier).recordAttempt(AttemptRecord.fromOutcome(s.mission.id, outcome, now));
    return outcome;
  }

  void _update(SystemDesign Function(SystemDesign) change) {
    final s = state;
    if (s == null) return;
    final next = change(s.design);
    state = s.copyWith(design: next, clearRun: true);
    ref.read(progressRepositoryProvider).saveDraft(s.mission.id, next);
  }
}

final benchProvider = NotifierProvider<BenchViewModel, BenchState?>(BenchViewModel.new);
