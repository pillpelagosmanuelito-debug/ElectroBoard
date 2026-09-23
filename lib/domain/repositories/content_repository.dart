import '../model/content_bundle.dart';

/// Fuente del contenido educativo (catálogo, misiones, módulos y textos del evaluador).
abstract class ContentRepository {
  Future<ContentBundle> load();
}
