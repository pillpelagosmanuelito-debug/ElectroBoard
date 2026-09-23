import 'dart:convert';
import 'dart:io';

import 'package:electroboard/data/repositories/json_content_repository.dart';
import 'package:electroboard/data/sources/json_source.dart';
import 'package:electroboard/domain/model/content_bundle.dart';
import 'package:electroboard/domain/model/design.dart';

const contentFiles = ['components.json', 'missions.json', 'modules.json', 'findings.json'];

/// Lee los JSON de assets/data de forma síncrona (compatible con testWidgets).
Map<String, String> readContentDocuments() => {
      for (final name in contentFiles) name: File('assets/data/$name').readAsStringSync(),
    };

MemoryJsonSource memorySource() => MemoryJsonSource(readContentDocuments());

Future<ContentBundle> loadContent() => JsonContentRepository(memorySource()).load();

/// Casos calculados por tools/reference_engine.py --fixture.
List<Map<String, dynamic>> referenceCases() {
  final raw = File('test/fixtures/reference_outcomes.json').readAsStringSync();
  return ((jsonDecode(raw) as Map<String, dynamic>)['cases'] as List<dynamic>).cast<Map<String, dynamic>>();
}

SystemDesign designFrom(Map<String, dynamic> json) => SystemDesign.fromJson(json);
