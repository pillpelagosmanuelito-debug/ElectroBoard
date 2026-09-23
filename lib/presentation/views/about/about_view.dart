import 'package:flutter/material.dart';

import '../../../app/board_theme.dart';
import '../../widgets/common.dart';

/// Propósito, funcionamiento del evaluador y límites declarados del modelo.
class AboutView extends StatelessWidget {
  const AboutView({super.key});

  static const version = '1.0.0';

  @override
  Widget build(BuildContext context) {
    Widget para(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Text(t, style: const TextStyle(height: 1.45)),
        );
    Widget bullet(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 7),
                child: StatusLed(color: BoardColors.copper, size: 5, glow: false),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(t, style: const TextStyle(height: 1.4))),
            ],
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Acerca de ElectroBoard')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SectionTitle('Para qué sirve'),
          para('ElectroBoard entrena el diseño de sistemas electrónicos inteligentes. En los cursos se estudian '
              'los componentes por separado; aquí se integran: eliges sensor, controlador, actuador, enlace, '
              'alimentación y lógica, y el simulador muestra qué ocurre cuando el sistema completo funciona.'),
          const SectionTitle('Cómo evalúa'),
          para('Cada diseño pasa por dos etapas. Primero, un análisis eléctrico revisa rieles de alimentación, '
              'niveles lógicos, conversores, etapas de potencia y enlaces. Después, una simulación en el tiempo '
              'recorre las condiciones de la misión con eventos reales: puertas abiertas, cortes de red, fallas.'),
          para('El evaluador es un conjunto de reglas deterministas: el mismo diseño recibe siempre el mismo '
              'informe, cada hallazgo cita el valor que lo activó y enlaza la lección que lo explica. No usa un '
              'modelo de lenguaje: un diagnóstico eléctrico equivocado enseñaría física falsa.'),
          const SectionTitle('Límites declarados del modelo'),
          bullet('La planta se modela con dinámica de primer orden. Sirve para comparar decisiones, no para dimensionar un equipo real.'),
          bullet('Los sensores tienen sesgo, ruido, cuantización y retardo simplificados a partir de su hoja de datos.'),
          bullet('Los precios son referenciales, en soles, para comparar alternativas.'),
          bullet('El firmware generado es un esqueleto didáctico: requiere revisión antes de cargarlo en una placa.'),
          bullet('No se simulan transitorios eléctricos, interferencias electromagnéticas ni temperatura de los componentes.'),
          const SectionTitle('Privacidad'),
          para('La aplicación funciona sin conexión. Tus intentos y respuestas se guardan solo en este teléfono.'),
          const SectionTitle('Versión'),
          para('ElectroBoard $version · Educational Mobile Apps Factory · Ingeniería Electrónica.'),
        ],
      ),
    );
  }
}
