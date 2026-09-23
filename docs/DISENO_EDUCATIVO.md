# Diseño educativo

## 1. Problema que resuelve

Los estudiantes de Electrónica aprenden sensores, microcontroladores, etapas de potencia y redes en cursos distintos. Cuando llega el proyecto integrador, los errores aparecen en las **interfaces**: un sensor de 5 V en un pin de 3.3 V, un calefactor sin etapa de potencia, una batería que dura dos días, un enlace que no llega. ElectroBoard entrena exactamente esa integración, antes de comprar un solo componente.

## 2. Competencias y cómo se miden

| Competencia | Dimensiones de la rúbrica | Evidencia en la app |
|---|---|---|
| **Diseñar sistemas completos** | Arquitectura · Comunicación · IoT | Rieles de alimentación, presupuesto, autonomía, alcance, entrega de datos |
| **Integrar sensores y actuadores** | Sensores · Actuadores | Magnitud, rango, exactitud, niveles lógicos, ADC, etapa de potencia, sentido de la acción |
| **Programar dispositivos** | Lógica de control | Algoritmo, consigna, histéresis, ganancias, muestreo, arquitectura del firmware, enclavamiento |

La bitácora calcula cada competencia con el **mejor intento** de cada proyecto.

## 3. Recorrido de aprendizaje

```
Ficha del proyecto ─▶ Tablero de bloques ─▶ Lógica y firmware ─▶ Simulación ─▶ Informe ─┐
      ▲                                                                                  │
      └───────────────────────────── rediseño ◀──── lección enlazada ◀───────────────────┘
```

1. **Ficha**: contexto real, requisitos cuantificados, infraestructura del lugar y condiciones de prueba (eventos).
2. **Tablero**: cinco ranuras (alimentación, sensor, controlador, actuador, comunicación) más la lógica. El costo se actualiza en vivo.
3. **Lógica**: algoritmo, parámetros, muestreo, reporte, arquitectura del firmware, reenvío y bajo consumo.
4. **Simulación**: osciloscopio con valor real, lectura del sensor, banda, umbral, eventos y salida del actuador.
5. **Informe**: requisitos cumplidos, rúbrica radial, competencias y hallazgos con la corrección y la lección que los explica.
6. **Firmware**: el mismo diseño expresado como código.

**Andamiaje.** Tres pistas por proyecto (se revelan una a una) y la solución de referencia, que se desbloquea **solo después de aprobar**, para comparar.

## 4. Proyectos

| Código | Proyecto | Lugar | Integración que pone a prueba | Error típico que provoca |
|---|---|---|---|---|
| EB-01 | Incubadora avícola | Majes, Arequipa | Exactitud del sensor frente a una banda de 1 °C; etapa de potencia; reenvío | DHT11 + relé en encendido/apagado |
| EB-02 | Aire saludable en el aula | Huancayo | Magnitud real medida; dimensionamiento del actuador; control proporcional | MQ-135 o CCS811 como «sensor de CO₂» |
| EB-03 | Tanque elevado | Miraflores, Lima | Zona ciega, niveles lógicos, divisor, sellado; enlace a través de losas | HC-SR04 de 5 V en un ESP32 |
| EB-04 | Riego autónomo | Huaral, Lima | Presupuesto de energía, sueño profundo, LoRaWAN y tiempo en el aire | Bomba siempre encendida con Wi-Fi |
| EB-05 | Parada segura de una faja | Pasco | Ancho de banda del acelerómetro, enclavamiento, RS-485 en planta | MPU-6050 y encendido/apagado |
| EB-06 | Cadena de frío de vacunas | Ocongate, Cusco | Rango del sensor, límite de arranques del compresor, enlace celular | Histéresis estrecha y LM35 |

Cada proyecto ofrece un catálogo curado que incluye **distractores plausibles**: un DHT22 en el proyecto de riego (mide humedad del aire, no del suelo), un ventilador en la incubadora, un zumbador que avisa pero no actúa.

## 5. Módulos

| Módulo | Lecciones |
|---|---|
| M1 Arquitectura embebida | Cadena de bloques · Presupuesto de energía · Sueño profundo · Tiempo real · Firmware bloqueante |
| M2 Sensores | Magnitud real · Exactitud y tolerancia · Rango y zona ciega · Niveles lógicos · Ancho de banda · Entorno y deriva |
| M3 Actuadores y control | Etapas de potencia · Dimensionamiento · Límites de conmutación · Histéresis · Proporcional y PID · Enclavamiento |
| M4 Comunicación | Alcance e infraestructura · LoRaWAN · Comunicación en planta · Enlace celular |
| M5 IoT | MQTT · Entrega garantizada · Frecuencia de reporte · Seguridad básica |

Cada lección es breve (dos párrafos, ideas clave, fórmula cuando corresponde), explica **dónde aparece en ElectroBoard** y cierra con una pregunta de control con retroalimentación.

## 6. Gamificación: la mínima necesaria

No hay puntos de experiencia, rachas ni insignias. El único indicador es el puntaje de la rúbrica, que mide calidad de diseño. Motivo: en diseño de ingeniería, un sistema de recompensas por uso premia la cantidad de intentos, no su calidad.

## 7. Indicadores sugeridos para un piloto

- Porcentaje de estudiantes que aprueban cada proyecto y número de intentos hasta aprobar.
- Hallazgos críticos más frecuentes por proyecto (revelan qué interfaz cuesta más).
- Comparación antes y después en una tarea de diseño en papel o con hardware real.
