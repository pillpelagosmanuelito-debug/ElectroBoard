// Inyección de dependencias con Riverpod.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repositories/json_content_repository.dart';
import '../data/repositories/prefs_progress_repository.dart';
import '../data/sources/json_source.dart';
import '../domain/codegen/firmware_generator.dart';
import '../domain/engine/run_pipeline.dart';
import '../domain/model/content_bundle.dart';
import '../domain/repositories/content_repository.dart';
import '../domain/repositories/progress_repository.dart';

export 'viewmodels/bench_view_model.dart';
export 'viewmodels/logbook_view_model.dart';
export 'viewmodels/progress_view_model.dart';
export 'viewmodels/workbench_view_model.dart';

/// Se reemplaza en main() con la instancia real.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider debe inyectarse en main().'),
);

final jsonSourceProvider = Provider<JsonSource>((ref) => AssetJsonSource());

final contentRepositoryProvider = Provider<ContentRepository>(
  (ref) => JsonContentRepository(ref.watch(jsonSourceProvider)),
);

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => PrefsProgressRepository(ref.watch(sharedPreferencesProvider)),
);

final contentProvider = FutureProvider<ContentBundle>(
  (ref) => ref.watch(contentRepositoryProvider).load(),
);

final runPipelineProvider = Provider<RunPipeline>((ref) => const RunPipeline());

final firmwareGeneratorProvider = Provider<FirmwareGenerator>((ref) => const FirmwareGenerator());

/// Reloj inyectable para las pruebas.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
