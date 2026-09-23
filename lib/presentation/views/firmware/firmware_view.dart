import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/board_theme.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

/// Firmware de referencia generado a partir del diseño.
class FirmwareView extends ConsumerWidget {
  const FirmwareView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(benchProvider);
    if (state == null || !state.design.isComplete) {
      return Scaffold(
        appBar: AppBar(title: const Text('Firmware')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Completa los cinco bloques del tablero para generar el firmware.', textAlign: TextAlign.center),
          ),
        ),
      );
    }
    final listing = ref.read(firmwareGeneratorProvider).generate(state.mission, state.catalog, state.design);
    final lines = listing.code.split('\n');
    return Scaffold(
      appBar: AppBar(
        title: Text(listing.fileName, style: BoardTheme.mono.copyWith(fontSize: 15)),
        actions: [
          IconButton(
            tooltip: 'Copiar el código',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: listing.code));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código copiado.')));
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          BoardPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${listing.language} · ${lines.length} líneas', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text(
                  'Este esqueleto muestra cómo cada decisión del tablero se convierte en código: bibliotecas, '
                  'conversión de unidades, algoritmo de control, comunicación y arquitectura del bucle. '
                  'Revisa pines y credenciales antes de cargarlo en una placa real.',
                  style: TextStyle(color: BoardColors.silkDim, fontSize: 12.5, height: 1.4),
                ),
                if (listing.libraries.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final l in listing.libraries) SpecChip(l, icon: Icons.inventory_2_outlined)],
                  ),
                ],
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF04140F),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: BoardColors.trace),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text.rich(
                  TextSpan(
                    children: [
                      for (var i = 0; i < lines.length; i++) ...[
                        TextSpan(
                          text: '${(i + 1).toString().padLeft(3)}  ',
                          style: BoardTheme.mono.copyWith(color: BoardColors.trace, fontSize: 12),
                        ),
                        TextSpan(
                          text: '${lines[i]}\n',
                          style: BoardTheme.mono.copyWith(color: _lineColor(lines[i]), fontSize: 12, height: 1.45),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _lineColor(String line) {
    final t = line.trimLeft();
    if (t.startsWith('#include') || t.startsWith('#define') || t.startsWith('import ') || t.startsWith('from ')) {
      return BoardColors.signal;
    }
    if (t.startsWith('//') || t.startsWith('/*') || t.startsWith('*') || t.startsWith('#')) {
      return BoardColors.silkDim;
    }
    if (t.contains('ADVERTENCIA')) return BoardColors.warn;
    return BoardColors.silk;
  }
}
