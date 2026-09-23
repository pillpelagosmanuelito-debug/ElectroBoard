import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/board_theme.dart';
import '../../../domain/model/learning.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

/// Lección breve con pregunta de control.
class LessonView extends ConsumerWidget {
  const LessonView({super.key, required this.lessonId});

  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentProvider);
    final progress = ref.watch(progressProvider);
    return content.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (e, _) => Scaffold(body: ErrorView(error: e)),
      data: (c) {
        final lesson = c.lesson(lessonId);
        if (lesson == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Lección no encontrada.')));
        }
        final module = c.module(lesson.moduleId);
        final answer = progress.lessonAnswers[lesson.id];
        return Scaffold(
          appBar: AppBar(title: Text(module.title)),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(lesson.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(lesson.summary,
                    style: const TextStyle(color: BoardColors.copper, fontSize: 15, height: 1.35)),
              ),
              for (final p in lesson.body)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(p, style: const TextStyle(height: 1.5, fontSize: 15)),
                ),
              if (lesson.formula != null)
                BoardPanel(
                  margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  borderColor: BoardColors.signal,
                  child: Text(
                    lesson.formula!,
                    style: BoardTheme.mono.copyWith(color: BoardColors.signal, fontSize: 14, height: 1.4),
                  ),
                ),
              const SectionTitle('Ideas clave'),
              for (final k in lesson.keyPoints)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 3, 16, 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: StatusLed(color: BoardColors.copper, size: 6, glow: false),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(k, style: const TextStyle(height: 1.4))),
                    ],
                  ),
                ),
              const SectionTitle('En ElectroBoard'),
              BoardPanel(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.developer_board, color: BoardColors.copper),
                    const SizedBox(width: 10),
                    Expanded(child: Text(lesson.inDesign, style: const TextStyle(height: 1.4))),
                  ],
                ),
              ),
              const SectionTitle('Comprueba lo aprendido'),
              _CheckCard(
                question: lesson.check,
                answer: answer,
                onAnswer: (i) => ref.read(progressProvider.notifier).answerLesson(lesson.id, i),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CheckCard extends StatelessWidget {
  const _CheckCard({required this.question, required this.answer, required this.onAnswer});

  final CheckQuestion question;
  final int? answer;
  final ValueChanged<int> onAnswer;

  @override
  Widget build(BuildContext context) {
    final answered = answer != null;
    final correct = answer == question.answer;
    return BoardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question.prompt, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35)),
          const SizedBox(height: 10),
          for (var i = 0; i < question.options.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _OptionButton(
                text: question.options[i],
                state: !answered
                    ? _OptionState.idle
                    : i == question.answer
                        ? _OptionState.correct
                        : (i == answer ? _OptionState.wrong : _OptionState.idle),
                onTap: () => onAnswer(i),
              ),
            ),
          if (answered) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(correct ? Icons.check_circle : Icons.info_outline,
                    color: correct ? BoardColors.ok : BoardColors.warn, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${correct ? '¡Correcto! ' : 'No es la respuesta. '}${question.explanation}',
                    style: const TextStyle(height: 1.4),
                  ),
                ),
              ],
            ),
            if (!correct)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Puedes elegir otra opción para volver a intentarlo.',
                    style: TextStyle(color: BoardColors.silkDim, fontSize: 12.5)),
              ),
          ],
        ],
      ),
    );
  }
}

enum _OptionState { idle, correct, wrong }

class _OptionButton extends StatelessWidget {
  const _OptionButton({required this.text, required this.state, required this.onTap});

  final String text;
  final _OptionState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _OptionState.correct => BoardColors.ok,
      _OptionState.wrong => BoardColors.crit,
      _OptionState.idle => BoardColors.trace,
    };
    return Material(
      color: state == _OptionState.idle ? BoardColors.maskDeep : color.withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: color)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(child: Text(text, style: const TextStyle(height: 1.3))),
              if (state == _OptionState.correct) const Icon(Icons.check, color: BoardColors.ok, size: 18),
              if (state == _OptionState.wrong) const Icon(Icons.close, color: BoardColors.crit, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
