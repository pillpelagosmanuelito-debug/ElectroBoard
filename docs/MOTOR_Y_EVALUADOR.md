# Motor de simulación y evaluador

El motor tiene dos implementaciones independientes que deben coincidir:

- **Dart** (la app): `lib/domain/engine/` y `lib/domain/evaluator/`.
- **Python** (referencia): `tools/reference_engine.py`, que lee los mismos JSON.

`python3 tools/reference_engine.py` imprime el informe de calibración; `--fixture` regenera `test/fixtures/reference_outcomes.json`, que las pruebas de Dart usan para exigir las mismas conclusiones (86 casos).

## 1. Análisis de cableado (`WiringAnalyzer`)

| Aspecto | Regla |
|---|---|
| Controlador | Vive si alguno de sus rieles de alimentación existe en la fuente |
| Sensor | Se alimenta del riel lógico del controlador si su rango lo admite; si no, del mayor riel disponible |
| Sensor analógico | Sin ADC → sin lectura. Salida mayor que la referencia del ADC → saturación (o divisor, si hay acondicionamiento) |
| Resolución efectiva | `max(resolución del sensor, (Vref / 2^bits) / sensibilidad)`; el error del ADC se suma al ruido |
| Niveles lógicos | 5 V hacia un pin de 3.3 V no tolerante: 40 % de lecturas inválidas. 3.3 V no tolerante en una placa de 5 V: 20 % |
| Ancho de banda | Atenuación = ancho de banda / frecuencia del fenómeno (si es menor) |
| Actuador | Sin efecto sobre la variable, sentido contrario, GPIO sobrecargado, falta de tensión de carga o de bobina, fuente insuficiente, MOSFET estándar (25 % con 3.3 V, 60 % con 5 V) |
| Enlace | Requiere la infraestructura del sitio y alcance suficiente. Pérdida = base + penalización del entorno + 0.3·(d/alcance)² |
| Costo | Suma de bloques + módulo de radio si el controlador no la integra + S/ 4 de acondicionamiento |

## 2. Simulación en el tiempo (`SystemSimulator`)

**Planta** (Euler explícito, paso `dt` de la misión):

```
dx/dt = (T_amb(t) − x)/τ  +  deriva(t)  +  perturbaciones(t)  +  G · efecto · u_efectiva
```

**Sensor**: retardo de primer orden (τ del sensor), sesgo = 0.4 × exactitud, ruido uniforme ± (0.5 × exactitud + error del ADC), deriva diaria, cuantización, rango y saturación. Respeta el intervalo mínimo entre lecturas.

**Lógica** (en los instantes de muestreo): encendido/apagado, histéresis, proporcional, PID con anti-windup y disparo con enclavamiento. Sin lectura válida, el actuador se apaga (falla segura).

**Firmware bloqueante**: la siguiente muestra se retrasa por la conversión del sensor y, en los reportes, por la latencia de la radio.

**Enlace**: reportes periódicos y alertas por evento; pérdida aleatoria, cortes programados, tiempo mínimo entre mensajes (LoRaWAN) y reintento cada 30 s o al volver el enlace si se activa «almacenar y reenviar».

**Energía** (Wh/día): controlador (activo o con ciclo de trabajo si duerme), sensor, radio en reposo, transmisiones y carga. La autonomía se calcula **sin sol**: capacidad ÷ consumo diario.

## 3. Métricas

| Métrica | Definición |
|---|---|
| Tiempo en banda | % de pasos, después del arranque, con la variable real dentro de la banda |
| Latencia de alerta | Desde que la variable real cruza el umbral hasta que llega la alerta (0 si la alerta ya estaba en camino) |
| Latencia de acción | Desde el cruce real hasta que el actuador actúa (solo en la faja) |
| Entrega | Reportes recibidos ÷ reportes que exige la misión |
| Conmutaciones | Arranques del relé o contactor por hora |
| Falsas alarmas | Episodios de alerta en los que la variable real no se acercó al umbral (margen del 10 % de la banda) |

## 4. Reglas del evaluador

Severidad y penalización por dimensión: **crítico −45**, **advertencia −15**, **sugerencia −5**, **acierto 0**. Cada dimensión parte de 100; el puntaje total es el promedio de las seis. **Aprobar = cero hallazgos críticos**.

| Dimensión | Reglas |
|---|---|
| Arquitectura | A01 alimentación del controlador · A02 radio externa · A03 RAM para RTOS · A04 Linux en seguridad · A05 autonomía · A06 presupuesto · A07 sin red eléctrica · A08 sobredimensionado · A09 sin sueño profundo · P05 autonomía suficiente |
| Sensores | S01 magnitud equivocada · S02 rango · S03 exactitud (crítica o marginal) · S04 alimentación · S05 sin ADC · S06 sobretensión analógica · S07 niveles lógicos (dos sentidos) · S08 resolución del ADC · S09 intervalo mínimo · S10 sin sellado · S11 deriva · S12 ancho de banda · P01 sensor correcto |
| Actuadores | C01 sin efecto · C02 sentido contrario · C03 GPIO sobrecargado · C04 tensión de carga · C05 capacidad de la fuente · C06 relé con PWM · C07 compuerta del MOSFET · C08 conmutaciones · C09 bobina sin 5 V · C10 subdimensionado · P02 etapa correcta |
| Comunicación | K01 sin enlace remoto · K02 falta infraestructura · K03 fuera de alcance · K04 tiempo en el aire · K06 entorno hostil · P06 enlace adecuado |
| IoT | I01 entrega insuficiente · I02 reporte lento · I03 sin reenvío · I04 costo mensual · I06 reporte excesivo · P03 entrega garantizada |
| Lógica | L01 tiempo en banda · L02 consigna fuera · L03 sin histéresis · L04 histéresis ancha · L05 muestreo lento · L06 sin enclavamiento · L07 firmware bloqueante · L08 alerta tardía · L09 falsas alarmas · L10 parada tardía · L11 PWM durante el sueño · P04 enclavamiento |

## 5. Valores de calibración (diseño de referencia)

| Misión | Tiempo en banda | Alerta | Entrega | Energía | Costo |
|---|---|---|---|---|---|
| EB-01 Incubadora | 94.1 % | 41 s | 100 % | 607 Wh/día | S/ 113 |
| EB-02 Aula | 84.3 % | 28 s | 100 % | 462 Wh/día | S/ 248 |
| EB-03 Tanque | 84.5 % | 0 s | 100 % | 106 Wh/día | S/ 282 |
| EB-04 Vivero | 87.0 % | 1490 s | 100 % | 5.1 Wh/día (16.6 días) | S/ 323 |
| EB-05 Faja | 100 % | parada antes del umbral | 100 % | 7.8 Wh/día | S/ 542 |
| EB-06 Vacunas | 96.8 % | 0 s | 100 % | 924 Wh/día | S/ 205 |

## 6. Límites declarados

- Dinámica de primer orden: sirve para comparar decisiones, no para dimensionar un equipo real.
- Sin transitorios eléctricos, interferencia electromagnética ni temperatura de los componentes.
- Modelos de enlace estadísticos (pérdida y latencia), no de propagación.
- Precios referenciales en soles.
