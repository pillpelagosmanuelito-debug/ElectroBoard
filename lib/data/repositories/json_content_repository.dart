import '../../domain/model/catalog.dart';
import '../../domain/model/content_bundle.dart';
import '../../domain/model/finding.dart';
import '../../domain/model/learning.dart';
import '../../domain/model/mission.dart';
import '../../domain/repositories/content_repository.dart';
import '../sources/json_source.dart';

class JsonContentRepository implements ContentRepository {
  JsonContentRepository(this.source);

  final JsonSource source;
  ContentBundle? _cache;

  @override
  Future<ContentBundle> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final results = await Future.wait([
      source.read('components.json'),
      source.read('missions.json'),
      source.read('modules.json'),
      source.read('findings.json'),
    ]);
    final missions = (results[1]['missions'] as List<dynamic>)
        .map((e) => Mission.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final modules = (results[2]['modules'] as List<dynamic>)
        .map((e) => LearningModule.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final templates = (results[3]['findings'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, FindingTemplate.fromJson(v as Map<String, dynamic>)));
    final bundle = ContentBundle(
      catalog: Catalog.fromJson(results[0]),
      missions: missions,
      modules: modules,
      findingTemplates: templates,
    );
    _cache = bundle;
    return bundle;
  }
}
