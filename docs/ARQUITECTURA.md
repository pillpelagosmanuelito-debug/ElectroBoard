# Arquitectura técnica

**Stack:** Flutter 3.24 · Dart 3.5 · Riverpod 2.5 · MVVM · Repository Pattern · `shared_preferences`.
Sin librerías de gráficos: el tablero, el osciloscopio, la rúbrica radial y el ícono se dibujan con `CustomPainter` o con scripts propios.

## 1. Capas

```
lib/
├── main.dart                      Arranque: SharedPreferences + ProviderScope
├── app/                           MaterialApp y tema «placa de circuito»
├── core/format.dart               Formato de números, duraciones y etiquetas en español
├── domain/                        Lógica pura, sin Flutter
│   ├── model/                     Catálogo, misión, diseño, hallazgos, resultados
│   ├── engine/                    WiringAnalyzer → SystemSimulator → RunPipeline
│   ├── evaluator/                 DesignEvaluator (60 reglas deterministas)
│   ├── codegen/                   FirmwareGenerator (Arduino/C++ y Python)
│   └── repositories/              Contratos: ContentRepository, ProgressRepository
├── data/
│   ├── sources/json_source.dart   AssetJsonSource (app) · MemoryJsonSource (pruebas)
│   └── repositories/              JsonContentRepository · PrefsProgressRepository
└── presentation/
    ├── providers.dart             Inyección de dependencias (Riverpod)
    ├── viewmodels/                Progress, Bench, Workbench, Logbook
    ├── views/                     Mesa de trabajo, ficha, tablero, lógica, simulación, informe…
    └── widgets/                   BlockBoard, ScopeChart, RadarChart, ScoreRing, PcbBackdrop
```

La dirección de dependencias es `presentation → domain ← data`. El dominio no importa Flutter, por eso el motor y el evaluador se prueban como Dart puro.

## 2. MVVM con Riverpod

| ViewModel | Tipo | Estado | Responsabilidad |
|---|---|---|---|
| `ProgressViewModel` | `Notifier<ProgressState>` | Intentos, respuestas, pistas | Registrar intentos y respuestas; calcular competencias |
| `BenchViewModel` | `Notifier<BenchState?>` | Misión, diseño, último resultado | Abrir misión (con borrador), elegir bloques, editar lógica, simular |
| `workbenchProvider` | `Provider<AsyncValue<…>>` | Resumen derivado | Tarjetas de proyectos y módulos |
| `logbookProvider` | `Provider<AsyncValue<…>>` | Resumen derivado | Bitácora por competencia y proyecto |

Las vistas solo leen estado (`ref.watch`) y llaman métodos del ViewModel (`ref.read(...notifier)`). Ninguna vista ejecuta el simulador directamente.

## 3. Repository Pattern

| Contrato (dominio) | Implementación (datos) | Fuente |
|---|---|---|
| `ContentRepository` | `JsonContentRepository` | `JsonSource`: assets empaquetados o memoria |
| `ProgressRepository` | `PrefsProgressRepository` | `SharedPreferences` (JSON, claves `eb.*`) |

Las pruebas reemplazan `jsonSourceProvider` por una `MemoryJsonSource` y `sharedPreferencesProvider` por un simulacro, sin tocar el código de producción.

## 4. Flujo de una simulación

```
BenchView ── run() ──▶ BenchViewModel
                          │
                          ▼
                     RunPipeline
                     ├─ WiringAnalyzer   rieles, niveles lógicos, ADC, etapa de potencia, enlace, costo
                     ├─ SystemSimulator  planta + sensor + lógica + enlace + energía (≈600 puntos)
                     └─ DesignEvaluator  reglas → hallazgos, rúbrica, requisitos
                          │
                          ▼
            RunOutcome ──▶ ProgressViewModel.recordAttempt()  (bitácora)
                          ▼
                RunView (osciloscopio) → ReportView (informe) → FirmwareView
```

La simulación es síncrona y tarda milisegundos: la misión más larga (48 h de riego) son 17 280 pasos.

## 5. Contenido declarativo

| Archivo | Contenido |
|---|---|
| `assets/data/components.json` | 6 controladores, 20 sensores, 16 actuadores, 7 enlaces, 6 fuentes |
| `assets/data/missions.json` | 6 misiones: planta, requisitos, sitio, eventos, catálogo curado, lógica por defecto, referencia y 80 variantes de calibración |
| `assets/data/modules.json` | 5 módulos, 25 lecciones con pregunta de control |
| `assets/data/findings.json` | Textos de las 60 reglas con marcadores `{valor}` |

## 6. Plataforma Android

La carpeta `android/` no se versiona. `scripts/prepare_android.sh` la genera con `flutter create`, fija el nombre «ElectroBoard» y crea los íconos con `flutter_launcher_icons`. CI ejecuta el mismo script.

## 7. Decisiones técnicas

| Decisión | Motivo |
|---|---|
| Motor en Dart puro, sin servidor | Funciona sin conexión, respuesta inmediata, sin costo por uso |
| Generador pseudoaleatorio LCG propio | Mismo resultado en Dart y en Python: permite pruebas de paridad |
| Redondeo al par (`roundHalfEven`) | Igual que `round()` de Python en la cuantización del ADC |
| Sin `Color.withValues`, `CardTheme` ni APIs recientes | Compatibilidad con Flutter 3.24 fijado en CI |
| Identificadores ASCII | Las tildes van solo en cadenas y comentarios (verificado por script) |
