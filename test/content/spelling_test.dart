// Ortografía: palabras técnicas que deben llevar tilde.
//
// Revisa todo el texto visible: los JSON de contenido y las cadenas de la
// interfaz en lib/. El generador de firmware se excluye porque sus cadenas
// son código C++ con identificadores ASCII (por ejemplo, «medicion»).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Forma sin tilde → forma correcta.
const misspellings = <String, String>{
  'simulacion': 'simulación',
  'comunicacion': 'comunicación',
  'configuracion': 'configuración',
  'logica': 'lógica',
  'energia': 'energía',
  'bateria': 'batería',
  'evaluacion': 'evaluación',
  'informacion': 'información',
  'medicion': 'medición',
  'tension': 'tensión',
  'precision': 'precisión',
  'resolucion': 'resolución',
  'conexion': 'conexión',
  'senal': 'señal',
  'diseno': 'diseño',
  'leccion': 'lección',
  'lecciones': 'lecciones',
  'modulo': 'módulo',
  'critico': 'crítico',
  'criticos': 'críticos',
  'parametro': 'parámetro',
  'tambien': 'también',
  'ademas': 'además',
  'despues': 'después',
  'rapido': 'rápido',
  'minimo': 'mínimo',
  'maximo': 'máximo',
  'numero': 'número',
  'valvula': 'válvula',
  'electronica': 'electrónica',
  'electrica': 'eléctrica',
  'telefono': 'teléfono',
  'codigo': 'código',
  'dias': 'días',
  'autonomia': 'autonomía',
  'segun': 'según',
  'facil': 'fácil',
  'tecnologia': 'tecnología',
  'analisis': 'análisis',
  'diagnostico': 'diagnóstico',
  'metrica': 'métrica',
  'metricas': 'métricas',
  'deteccion': 'detección',
  'accion': 'acción',
  'funcion': 'función',
  'alimentacion': 'alimentación',
  'vibracion': 'vibración',
  'conversion': 'conversión',
  'direccion': 'dirección',
  'relacion': 'relación',
  'operacion': 'operación',
  'solucion': 'solución',
  'version': 'versión',
  'aplicacion': 'aplicación',
  'intermitente': 'intermitente',
  'histeresis': 'histéresis',
  'consigna': 'consigna',
  'analogico': 'analógico',
  'analogica': 'analógica',
  'digitalizacion': 'digitalización',
  'termico': 'térmico',
  'ultimo': 'último',
  'rele': 'relé',
  'reles': 'relés',
  'bitacora': 'bitácora',
  'rubrica': 'rúbrica',
  'dimension': 'dimensión',
  'competencia': 'competencia',
  'estres': 'estrés',
  'pais': 'país',
  'aqui': 'aquí',
  'asi': 'así',
  'dia': 'día',
  'podria': 'podría',
  'deberia': 'debería',
  'tecnica': 'técnica',
  'tecnico': 'técnico',
  'practica': 'práctica',
  'mecanico': 'mecánico',
  'automatizacion': 'automatización',
  'frecuencia': 'frecuencia',
  'muestreo': 'muestreo',
  'reenvio': 'reenvío',
  'envio': 'envío',
  'exito': 'éxito',
  'proposito': 'propósito',
  'limite': 'límite',
  'limites': 'límites',
  'grafico': 'gráfico',
  'fisica': 'física',
  'fisico': 'físico',
};

final _word = RegExp(r"[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+");

List<String> _jsonStrings(Object? node) {
  if (node is String) return [node];
  if (node is List) return node.expand(_jsonStrings).toList();
  if (node is Map) return node.values.expand(_jsonStrings).toList();
  return const [];
}

/// Extrae el contenido de las cadenas literales de un archivo Dart.
List<String> _dartLiterals(String src) {
  final out = <String>[];
  final re = RegExp(r"'((?:[^'\\\n]|\\.)*)'");
  for (final line in src.split('\n')) {
    final t = line.trimLeft();
    if (t.startsWith('import ') || t.startsWith('export ') || t.startsWith('//')) continue;
    for (final m in re.allMatches(line)) {
      out.add(m.group(1)!.replaceAll(RegExp(r'\$\{[^}]*\}'), ' ').replaceAll(RegExp(r'\$\w+'), ' '));
    }
  }
  return out;
}

void main() {
  final bad = {for (final e in misspellings.entries) if (e.key != e.value) e.key: e.value};

  List<String> problemsIn(Iterable<String> texts, String source) {
    final problems = <String>[];
    for (final text in texts) {
      for (final m in _word.allMatches(text)) {
        final w = m.group(0)!.toLowerCase();
        if (bad.containsKey(w)) problems.add('$source: «${m.group(0)}» debería ser «${bad[w]}» en: $text');
      }
    }
    return problems;
  }

  test('el contenido JSON no tiene palabras sin tilde', () {
    final problems = <String>[];
    for (final name in ['components.json', 'missions.json', 'modules.json', 'findings.json']) {
      final data = jsonDecode(File('assets/data/$name').readAsStringSync());
      // Los valores de identificadores (ids, claves técnicas) son ASCII por diseño.
      final texts = _jsonStrings(data).where((s) => s.contains(' ') || RegExp(r'[A-ZÁÉÍÓÚ]').hasMatch(s));
      problems.addAll(problemsIn(texts, name));
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('las cadenas de la interfaz no tienen palabras sin tilde', () {
    final problems = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.contains('codegen'));
    for (final f in files) {
      final literals = _dartLiterals(f.readAsStringSync()).where((s) => s.contains(' '));
      problems.addAll(problemsIn(literals, f.path));
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('los textos no usan comillas rectas dobles como citas', () {
    final missions = File('assets/data/missions.json').readAsStringSync();
    expect(missions.contains('\\"'), isFalse);
  });
}
