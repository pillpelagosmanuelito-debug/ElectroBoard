import 'package:flutter/material.dart';

import '../../app/board_theme.dart';
import '../../domain/model/catalog.dart';
import '../../domain/model/finding.dart';

/// Título de sección con marca de serigrafía.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing, this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 8)});

  final String text;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(width: 4, height: 16, color: BoardColors.copper),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: const TextStyle(
                color: BoardColors.silkDim,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Indicador tipo LED.
class StatusLed extends StatelessWidget {
  const StatusLed({super.key, required this.color, this.size = 10, this.glow = true});

  final Color color;
  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: glow ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: size, spreadRadius: 1)] : null,
      ),
    );
  }
}

/// Etiqueta compacta de especificación técnica.
class SpecChip extends StatelessWidget {
  const SpecChip(this.label, {super.key, this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = color ?? BoardColors.silkDim;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: BoardColors.maskDeep,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: c), const SizedBox(width: 4)],
          Flexible(
            child: Text(label, style: TextStyle(color: c, fontSize: 11.5), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

/// Panel con fondo de placa elevada.
class BoardPanel extends StatelessWidget {
  const BoardPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Material(
        color: BoardColors.maskRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: borderColor ?? BoardColors.trace),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Cifra destacada con etiqueta.
class MetricTile extends StatelessWidget {
  const MetricTile({super.key, required this.label, required this.value, this.color, this.caption});

  final String label;
  final String value;
  final Color? color;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: BoardColors.maskDeep,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: BoardColors.trace),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: BoardColors.silkDim, fontSize: 11)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: BoardTheme.mono.copyWith(color: color ?? BoardColors.silk, fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(caption!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: BoardColors.silkDim, fontSize: 10.5)),
          ],
        ],
      ),
    );
  }
}

Color severityColor(Severity s) => switch (s) {
      Severity.critical => BoardColors.crit,
      Severity.warning => BoardColors.warn,
      Severity.suggestion => BoardColors.hint,
      Severity.positive => BoardColors.ok,
    };

IconData severityIcon(Severity s) => switch (s) {
      Severity.critical => Icons.dangerous_outlined,
      Severity.warning => Icons.warning_amber_rounded,
      Severity.suggestion => Icons.lightbulb_outline,
      Severity.positive => Icons.check_circle_outline,
    };

IconData partIcon(PartKind kind) => switch (kind) {
      PartKind.sensor => Icons.sensors,
      PartKind.controller => Icons.memory,
      PartKind.actuator => Icons.settings_input_component,
      PartKind.comm => Icons.cell_tower,
      PartKind.power => Icons.bolt,
    };

String partTitle(PartKind kind) => switch (kind) {
      PartKind.sensor => 'Sensor',
      PartKind.controller => 'Controlador',
      PartKind.actuator => 'Actuador',
      PartKind.comm => 'Comunicación',
      PartKind.power => 'Alimentación',
    };

Color scoreColor(int score) {
  if (score >= 85) return BoardColors.ok;
  if (score >= 60) return BoardColors.warn;
  return BoardColors.crit;
}

/// Estado de carga.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message = 'Cargando el catálogo…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: BoardColors.silkDim)),
        ],
      ),
    );
  }
}

/// Estado de error con reintento.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: BoardColors.crit, size: 40),
            const SizedBox(height: 12),
            const Text('No se pudo cargar el contenido.', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('$error', textAlign: TextAlign.center, style: const TextStyle(color: BoardColors.silkDim, fontSize: 12)),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ],
        ),
      ),
    );
  }
}
