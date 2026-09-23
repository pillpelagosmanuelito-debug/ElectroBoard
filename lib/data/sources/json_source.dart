import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// Origen de los documentos JSON de contenido.
abstract class JsonSource {
  Future<Map<String, dynamic>> read(String name);
}

/// Lee los JSON empaquetados en assets/data.
class AssetJsonSource implements JsonSource {
  AssetJsonSource({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  @override
  Future<Map<String, dynamic>> read(String name) async {
    final raw = await _bundle.loadString('assets/data/$name');
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}

/// Fuente en memoria, útil para pruebas.
class MemoryJsonSource implements JsonSource {
  MemoryJsonSource(this.documents);

  final Map<String, String> documents;

  @override
  Future<Map<String, dynamic>> read(String name) async {
    final raw = documents[name];
    if (raw == null) throw StateError('Documento no encontrado: $name');
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}
