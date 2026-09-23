import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/board_theme.dart';
import '../../../domain/model/learning.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../../widgets/pcb_backdrop.dart';
import '../about/about_view.dart';
import '../learn/module_view.dart';
import '../logbook/logbook_view.dart';
import '../mission/mission_brief_view.dart';

/// Pantalla principal: la mesa de trabajo con proyectos y módulos.
class WorkbenchView extends ConsumerWidget {
  const WorkbenchView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(workbenchProvider);
    return Scaffold(
      body: summary.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(contentProvider)),
        data: (s) => CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 196,
              title: const Text('ElectroBoard', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              actions: [
                IconButton(
                  tooltip: 'Bitácora',
                  icon: const Icon(Icons.timeline),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LogbookView())),
                ),
                IconButton(
                  tooltip: 'Acerca de ElectroBoard',
                  icon: const Icon(Icons.info_outline),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutView())),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: _Hero(passed: s.passedCount, total: s.missions.length),
              ),
            ),
            SliverToBoxAdapter(child: _CompetencyStrip(values: s.competencies)),
            if (s.next != null)
              SliverToBoxAdapter(
                child: BoardPanel(
                  borderColor: BoardColors.copper,
                  onTap: () => _openMission(context, s.next!.mission.id),
                  child: Row(
                    children: [
                      const Icon(Icons.play_circle_outline, color: BoardColors.copper, size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.next!.started ? 'Continúa tu proyecto' : 'Siguiente proyecto',
                                style: const TextStyle(color: BoardColors.silkDim, fontSize: 12)),
                            const SizedBox(height: 2),
                            Text(s.next!.mission.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: BoardColors.silkDim),
                    ],
                  ),
                ),
              ),
            SliverToBoxAdapter(child: SectionTitle('Proyectos de diseño · ${s.passedCount} de ${s.missions.length} aprobados')),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _MissionCard(data: s.missions[i], onTap: () => _openMission(context, s.missions[i].mission.id)),
                childCount: s.missions.length,
              ),
            ),
            const SliverToBoxAdapter(child: SectionTitle('Módulos de aprendizaje')),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _ModuleCard(
                  data: s.modules[i],
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ModuleView(moduleId: s.modules[i].module.id)),
                  ),
                ),
                childCount: s.modules.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  void _openMission(BuildContext context, String id) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => MissionBriefView(missionId: id)));
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.passed, required this.total});

  final int passed;
  final int total;

  @override
  Widget build(BuildContext context) {
    return PcbBackdrop(
      child: Container(
        alignment: Alignment.bottomLeft,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [BoardColors.maskDeep.withOpacity(0.2), BoardColors.mask],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Diseña, conecta y prueba sistemas embebidos completos.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.25),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                StatusLed(color: passed > 0 ? BoardColors.ok : BoardColors.copper, size: 8),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Sensor · controlador · actuador · enlace · lógica',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: BoardColors.silkDim.withOpacity(0.95), fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompetencyStrip extends StatelessWidget {
  const _CompetencyStrip({required this.values});

  final Map<Competency, int?> values;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          for (final c in Competency.values) ...[
            Expanded(child: _CompetencyGauge(label: c.label, value: values[c])),
            if (c != Competency.values.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _CompetencyGauge extends StatelessWidget {
  const _CompetencyGauge({required this.label, required this.value});

  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) {
    final v = value;
    return Semantics(
      label: '$label: ${v == null ? 'sin datos' : '$v de 100'}',
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: BoardColors.maskRaised,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: BoardColors.trace),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, maxLines: 2, style: const TextStyle(fontSize: 10.5, color: BoardColors.silkDim, height: 1.2)),
            const SizedBox(height: 6),
            Text(v == null ? '—' : '$v',
                style: BoardTheme.mono.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: v == null ? BoardColors.silkDim : scoreColor(v),
                )),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: (v ?? 0) / 100,
                minHeight: 4,
                backgroundColor: BoardColors.maskDeep,
                color: v == null ? BoardColors.trace : scoreColor(v),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.data, required this.onTap});

  final MissionCardData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = data.mission;
    final led = data.passed ? BoardColors.ok : (data.started ? BoardColors.warn : BoardColors.trace);
    final best = data.best;
    return BoardPanel(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: BoardColors.maskDeep,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: BoardColors.copperDim),
                ),
                child: Text(m.code, style: BoardTheme.mono.copyWith(fontSize: 11, color: BoardColors.copper)),
              ),
              const SizedBox(height: 10),
              StatusLed(color: led, glow: data.started),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(m.place, style: const TextStyle(color: BoardColors.silkDim, fontSize: 12.5)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    SpecChip(m.difficulty, icon: Icons.signal_cellular_alt),
                    SpecChip(m.variableLabel, icon: Icons.show_chart),
                    if (best != null)
                      SpecChip(
                        data.passed ? 'Aprobado · ${best.overall}' : 'Mejor: ${best.overall}',
                        color: data.passed ? BoardColors.ok : BoardColors.warn,
                      ),
                    if (data.attempts > 0) SpecChip('${data.attempts} ${data.attempts == 1 ? 'intento' : 'intentos'}'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.data, required this.onTap});

  final ModuleCardData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = data.module;
    return BoardPanel(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('M${m.order}', style: BoardTheme.mono.copyWith(color: BoardColors.signal, fontWeight: FontWeight.w700)),
              const SizedBox(width: 10),
              Expanded(child: Text(m.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
              Text('${data.answered}/${data.total}', style: BoardTheme.mono.copyWith(color: BoardColors.silkDim, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Text(m.tagline, style: const TextStyle(color: BoardColors.silkDim, fontSize: 12.5)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: data.progress,
              minHeight: 4,
              backgroundColor: BoardColors.maskDeep,
              color: BoardColors.signal,
            ),
          ),
        ],
      ),
    );
  }
}
