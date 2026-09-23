import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/board_theme.dart';
import '../../../domain/model/evaluation.dart';
import '../../../domain/model/finding.dart';
import '../../../domain/model/learning.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../../widgets/radar_chart.dart';
import '../../widgets/score_ring.dart';
import '../bench/bench_view.dart';
import '../firmware/firmware_view.dart';
import '../learn/lesson_view.dart';

/// Informe del evaluador de diseño.
class ReportView extends ConsumerWidget {
  const ReportView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(benchProvider);
    final run = state?.lastRun;
    if (state == null || run == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Informe')),
        body: const Center(child: Text('Todavía no hay una simulación para evaluar.')),
      );
    }
    final e = run.evaluation;
    final m = state.mission;
    final content = state.content;
    return Scaffold(
      appBar: AppBar(title: Text('${m.code} · Informe del evaluador')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                ScoreRing(score: e.overall),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StatusLed(color: e.passed ? BoardColors.ok : BoardColors.crit),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e.passed ? 'Diseño aprobado' : 'El diseño aún no cumple',
                              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        e.passed
                            ? 'Cumple todos los requisitos sin fallas críticas. Revisa las advertencias para mejorarlo.'
                            : 'Tiene ${e.criticalCount} ${e.criticalCount == 1 ? 'falla crítica' : 'fallas críticas'}. '
                                'Corrígelas y vuelve a simular.',
                        style: const TextStyle(color: BoardColors.silkDim, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle('Requisitos de la misión'),
          BoardPanel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              children: [for (final r in e.requirements) _RequirementRow(check: r)],
            ),
          ),
          const SectionTitle('Rúbrica por dimensión'),
          Center(
            child: RadarChart(
              labels: [for (final d in Dimension.values) d.label],
              values: [for (final d in Dimension.values) e.scores[d] ?? 0],
            ),
          ),
          _CompetencyRows(scores: e.competencyScores),
          for (final sev in Severity.values)
            if (e.bySeverity(sev).isNotEmpty) ...[
              SectionTitle('${_sevTitle(sev)} (${e.bySeverity(sev).length})'),
              for (final f in e.bySeverity(sev))
                _FindingTile(
                  finding: f,
                  lessonTitle: content.lesson(f.lessonId)?.title,
                  onLesson: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => LessonView(lessonId: f.lessonId))),
                ),
            ],
          BoardPanel(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: const Text(
              'El evaluador aplica reglas deterministas sobre tu diseño y sobre la simulación: el mismo diseño '
              'siempre recibe el mismo informe. Cada hallazgo indica la regla, el valor que la activó y la lección '
              'que la explica.',
              style: TextStyle(color: BoardColors.silkDim, fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.code),
                label: const Text('Firmware'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FirmwareView())),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                icon: const Icon(Icons.developer_board),
                label: const Text('Volver al tablero'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                onPressed: () => Navigator.of(context).popUntil(
                  (route) => route.settings.name == BenchView.routeName || route.isFirst,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sevTitle(Severity s) => switch (s) {
        Severity.critical => 'Fallas críticas',
        Severity.warning => 'Advertencias',
        Severity.suggestion => 'Sugerencias',
        Severity.positive => 'Aciertos',
      };
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.check});

  final RequirementCheck check;

  @override
  Widget build(BuildContext context) {
    final color = check.met ? BoardColors.ok : BoardColors.crit;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(check.met ? Icons.check_circle : Icons.cancel, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(check.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('Logrado: ${check.achieved} · Meta: ${check.target}',
                    style: const TextStyle(color: BoardColors.silkDim, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompetencyRows extends StatelessWidget {
  const _CompetencyRows({required this.scores});

  final Map<Competency, int> scores;

  @override
  Widget build(BuildContext context) {
    return BoardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Competencias en este intento', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final c in Competency.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(flex: 5, child: Text(c.label, style: const TextStyle(fontSize: 13))),
                  Expanded(
                    flex: 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: (scores[c] ?? 0) / 100,
                        minHeight: 6,
                        backgroundColor: BoardColors.maskDeep,
                        color: scoreColor(scores[c] ?? 0),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text('${scores[c] ?? 0}',
                        textAlign: TextAlign.right, style: BoardTheme.mono.copyWith(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FindingTile extends StatelessWidget {
  const _FindingTile({required this.finding, required this.lessonTitle, required this.onLesson});

  final Finding finding;
  final String? lessonTitle;
  final VoidCallback onLesson;

  @override
  Widget build(BuildContext context) {
    final f = finding;
    final color = severityColor(f.severity);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: BoardColors.maskRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: color.withOpacity(0.6)),
        ),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          initiallyExpanded: f.severity == Severity.critical,
          leading: Icon(severityIcon(f.severity), color: color),
          title: Text(f.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
          subtitle: Text('${f.dimension.label} · ${f.severity.label}',
              style: TextStyle(color: color.withOpacity(0.9), fontSize: 12)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (f.message.isNotEmpty) Text(f.message, style: const TextStyle(height: 1.4)),
            if (f.fix.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.build_outlined, size: 16, color: BoardColors.copper),
                  const SizedBox(width: 6),
                  Expanded(child: Text(f.fix, style: const TextStyle(color: BoardColors.copper, height: 1.35))),
                ],
              ),
            ],
            if (lessonTitle != null) ...[
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: onLesson,
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: Text('Repasar: $lessonTitle'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
