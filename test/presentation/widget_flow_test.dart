// Recorrido completo de la interfaz: mesa de trabajo → ficha → tablero →
// simulación → informe → firmware, más lecciones y bitácora.

import 'package:electroboard/app/electroboard_app.dart';
import 'package:electroboard/presentation/providers.dart';
import 'package:electroboard/presentation/views/bench/logic_editor_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_content.dart';

Future<ProviderContainer> pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    jsonSourceProvider.overrideWithValue(memorySource()),
  ]);
  addTearDown(container.dispose);
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const ElectroBoardApp()));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('la mesa de trabajo muestra proyectos, módulos y competencias', (tester) async {
    await pumpApp(tester);
    expect(find.text('ElectroBoard'), findsOneWidget);
    expect(find.text('Incubadora avícola inteligente'), findsWidgets);
    expect(find.text('Diseñar sistemas completos'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Arquitectura embebida'), 300);
    expect(find.text('Arquitectura embebida'), findsOneWidget);
  });

  testWidgets('recorrido: ficha, tablero, simulación, informe y firmware', (tester) async {
    final container = await pumpApp(tester);

    await tester.tap(find.text('Incubadora avícola inteligente').last);
    await tester.pumpAndSettle();
    expect(find.text('Requisitos que se evaluarán'.toUpperCase()), findsOneWidget);

    await tester.tap(find.text('Abrir el tablero de diseño'));
    await tester.pumpAndSettle();
    expect(find.text('EB-01 · Tablero'), findsOneWidget);
    expect(find.textContaining('Completa los 5 bloques'), findsOneWidget);

    // Elegir un sensor desde el catálogo de la ranura.
    await tester.tap(find.text('SENSOR'));
    await tester.pumpAndSettle();
    expect(find.text('Elige: sensor'), findsOneWidget);
    final ds = find.text('DS18B20 (sonda impermeable)');
    await tester.scrollUntilVisible(ds, 200, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.tap(ds);
    await tester.pumpAndSettle();
    expect(container.read(benchProvider)!.design.sensorId, 'ds18b20');

    // Completar con la solución de referencia y simular.
    container.read(benchProvider.notifier).loadReference();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simular y evaluar'));
    await tester.pumpAndSettle();
    expect(find.text('EB-01 · Simulación'), findsOneWidget);
    expect(find.text('Tiempo en la banda'), findsOneWidget);

    await tester.tap(find.text('Ver el informe del evaluador'));
    await tester.pumpAndSettle();
    expect(find.text('Diseño aprobado'), findsOneWidget);

    await tester.tap(find.text('Firmware'));
    await tester.pumpAndSettle();
    expect(find.text('electroboard_incubadora.ino'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Volver al tablero'));
    await tester.pumpAndSettle();
    expect(find.text('EB-01 · Tablero'), findsOneWidget);
    expect(find.text('Último intento: aprobado'), findsOneWidget);
  });

  testWidgets('el editor de lógica cambia el algoritmo', (tester) async {
    final container = await pumpApp(tester);
    final content = container.read(contentProvider).value!;
    container.read(benchProvider.notifier).open(content, content.mission('cadena_frio'));
    await tester.pumpAndSettle();
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(MaterialPageRoute(builder: (_) => const LogicEditorView()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Histéresis'));
    await tester.pumpAndSettle();
    expect(container.read(benchProvider)!.design.logic.algorithm.key, 'hysteresis');
    expect(find.textContaining('Enciende en'), findsOneWidget);
  });

  testWidgets('una lección registra la respuesta de control', (tester) async {
    final container = await pumpApp(tester);
    await tester.scrollUntilVisible(find.text('Sensores').last, 300);
    await tester.tap(find.text('Sensores').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rango y zona ciega'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Porque no mide por debajo de 2 °C'), 300);
    await tester.tap(find.text('Porque no mide por debajo de 2 °C'));
    await tester.pumpAndSettle();
    expect(container.read(progressProvider).lessonAnswers['sen_rango'], 1);
    expect(find.textContaining('¡Correcto!'), findsOneWidget);
  });

  testWidgets('la bitácora y la ficha «Acerca de» se abren', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Bitácora'));
    await tester.pumpAndSettle();
    expect(find.text('Sin intentos todavía.'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Acerca de ElectroBoard'));
    await tester.pumpAndSettle();
    expect(find.text('Para qué sirve'.toUpperCase()), findsOneWidget);
  });
}
