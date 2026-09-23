// Formato de números y magnitudes para la interfaz (convención con punto decimal,
// como en las hojas de datos de los componentes).

String fmtNum(double v, [int decimals = 1]) {
  if (v.isInfinite) return '∞';
  if (v.isNaN) return '—';
  final s = v.toStringAsFixed(decimals);
  // Evita «-0.0».
  if (s.startsWith('-') && double.parse(s) == 0) return s.substring(1);
  return s;
}

/// Número con la cantidad justa de decimales (sin ceros sobrantes).
String fmtCompact(double v, {int maxDecimals = 2}) {
  if (v.isInfinite) return '∞';
  var s = v.toStringAsFixed(maxDecimals);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
  }
  if (s == '-0') s = '0';
  return s;
}

String fmtPen(double v) => 'S/ ${v.round()}';

String fmtPct(double v, [int decimals = 0]) => '${fmtNum(v, decimals)} %';

/// Duración legible: 45 s, 12 min, 1.5 h, 3 días.
String fmtDuration(double seconds) {
  if (seconds.isInfinite) return 'nunca';
  if (seconds < 90) return '${fmtCompact(seconds, maxDecimals: 1)} s';
  if (seconds < 5400) return '${fmtCompact(seconds / 60, maxDecimals: 1)} min';
  if (seconds < 172800) return '${fmtCompact(seconds / 3600, maxDecimals: 1)} h';
  return '${fmtCompact(seconds / 86400, maxDecimals: 1)} días';
}

/// Intervalo de muestreo o reporte expresado en la unidad más natural.
String fmtInterval(double seconds) {
  if (seconds < 60) return '${fmtCompact(seconds, maxDecimals: 1)} s';
  if (seconds < 3600) return '${fmtCompact(seconds / 60, maxDecimals: 1)} min';
  return '${fmtCompact(seconds / 3600, maxDecimals: 1)} h';
}

String fmtVolts(double v) => '${fmtCompact(v, maxDecimals: 1)} V';

String fmtRails(List<double> rails) => rails.map(fmtVolts).join(', ');

/// Hora del reloj de simulación (hh:mm) a partir de segundos.
String fmtClock(double seconds) {
  final total = seconds.round();
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  if (h == 0) return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

String fmtDate(DateTime d) {
  const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'set', 'oct', 'nov', 'dic'];
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${months[d.month - 1]} · $hh:$mm';
}

/// Etiqueta en español de las magnitudes que mide un sensor.
String measureLabel(String key) => switch (key) {
      'temperature' => 'temperatura',
      'air_humidity' => 'humedad del aire',
      'soil_moisture' => 'humedad del suelo',
      'co2' => 'CO₂',
      'eco2' => 'compuestos orgánicos volátiles (eCO₂ estimado)',
      'level' => 'nivel',
      'vibration' => 'velocidad de vibración RMS',
      'vibration_presence' => 'presencia de golpes',
      _ => key,
    };

String infraLabel(String key) => switch (key) {
      'router' => 'un router Wi-Fi',
      'phone' => 'un teléfono cercano',
      'gateway' => 'un gateway LoRaWAN',
      'coverage' => 'cobertura celular',
      'cable' => 'un cable hasta el PLC',
      'pc' => 'una computadora cercana',
      _ => key,
    };

String interfaceLabel(String key) => switch (key) {
      'analog' => 'Analógica',
      'digital' => 'Digital',
      'i2c' => 'I²C',
      'spi' => 'SPI',
      'onewire' => '1-Wire',
      'uart' => 'UART',
      'pulse' => 'Pulso',
      _ => key,
    };

String driverLabel(String key) => switch (key) {
      'relay' => 'Relé',
      'mosfet_ll' => 'MOSFET de nivel lógico',
      'mosfet_std' => 'MOSFET estándar',
      'gpio' => 'Directo al GPIO',
      'servo' => 'Señal de servo',
      _ => key,
    };
