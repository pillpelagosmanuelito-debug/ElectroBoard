/// Generador congruencial lineal determinista.
///
/// Es idéntico al de tools/reference_engine.py: con la misma semilla, Dart y
/// Python producen la misma secuencia, lo que permite comparar resultados.
class LcgRandom {
  LcgRandom(int seed) : _state = seed & 0x7FFFFFFF;

  int _state;

  /// Devuelve un número en [0, 1].
  double next() {
    _state = (_state * 1103515245 + 12345) & 0x7FFFFFFF;
    return _state / 2147483647.0;
  }
}

/// Redondeo al par más cercano, como round() de Python.
double roundHalfEven(double v) {
  final floor = v.floorToDouble();
  final diff = v - floor;
  if (diff > 0.5) return floor + 1.0;
  if (diff < 0.5) return floor;
  return (floor % 2 == 0) ? floor : floor + 1.0;
}
