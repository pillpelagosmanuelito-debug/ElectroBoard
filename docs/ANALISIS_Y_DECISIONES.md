# ElectroBoard · Análisis crítico y decisiones

Este documento registra el diagnóstico previo y cómo cada hallazgo cambió lo que se construyó. El análisis no reemplazó la construcción: la orientó.

---

## 1. Ficha de evaluación (criterios del proyecto)

| Criterio | Evaluación |
|---|---|
| **1. Valor educativo** | Alto, **con una condición**: la selección de componentes debe tener consecuencias medibles. Si no las tiene, la app es un cuestionario de emparejar nombres. |
| **2. Problema real** | Existe. Los cursos enseñan sensores, microcontroladores y redes por separado; los errores de integración (niveles lógicos, etapas de potencia, energía, enlace) aparecen recién en el proyecto final, cuando cuesta caro corregirlos. |
| **3. Usuario objetivo** | Estudiante de Ingeniería Electrónica de 5.º a 9.º ciclo (Sistemas embebidos, IoT, Automatización). |
| **4. Competencias** | Diseñar sistemas completos, integrar sensores y actuadores, programar dispositivos. |
| **5. Experiencia** | Proyecto con requisitos → tablero de bloques → lógica y firmware → simulación con eventos → informe con reglas explicables → rediseño. |
| **6. Viabilidad técnica** | Alta. Motor en Dart puro, sin servidor ni conexión. Verificado contra una implementación de referencia en Python. |
| **7. Diferenciación** | Frente a un simulador de circuitos: trabaja a nivel de **sistema**. Frente a un kit físico: permite equivocarse gratis y ver la consecuencia de cada decisión. |
| **8. Potencial de uso real** | Alto. Seis proyectos con contexto peruano, precios en soles y contenido editable por el docente. |

---

## 2. Debilidades del planteamiento original y cómo se resolvieron

### 2.1 Riesgo principal: «elegir componentes» sin consecuencias

**Problema.** Si el estudiante elige un sensor de una lista y la app responde «correcto» o «incorrecto», el ejercicio no pasa la prueba de sustitución: un cuestionario en papel hace lo mismo.

**Decisión.** Cada componente tiene propiedades eléctricas reales (tensión de alimentación, nivel lógico, interfaz, exactitud, rango, ancho de banda, corriente, radio integrada, sueño profundo, costo) y **el error se simula, no se anuncia**:

| Error típico | Lo que ocurre en la simulación |
|---|---|
| HC-SR04 (5 V) en un ESP32 sin adaptador | Lecturas intermitentes (40 % inválidas) |
| Calefactor conectado directo al GPIO | El pin se daña en el primer encendido y la temperatura cae |
| Fuente de 1 A para una carga de 3.3 A | El controlador se reinicia cada vez que la carga arranca |
| Ventilador en una incubadora | La temperatura baja en lugar de subir |
| MOSFET IRF540N con lógica de 3.3 V | Entrega solo el 25 % de la potencia |
| Parada por vibración sin enclavamiento | El motor arranca y para cientos de veces por hora |
| LoRaWAN cada 5 minutos | La red descarta los mensajes que exceden el tiempo en el aire |
| Router que se reinicia sin «almacenar y reenviar» | Se pierden los reportes y la alerta |

### 2.2 El ejemplo del encargo («sistema inteligente de temperatura») era demasiado abierto

**Decisión.** Se convirtió en seis **proyectos con requisitos cuantificados** y contexto real: una incubadora en Majes, un aula en Huancayo, un tanque en Miraflores, un vivero en Huaral, una faja minera en Pasco y la cadena de frío de vacunas en Ocongate. Cada uno pone a prueba una integración distinta (tabla en `DISENO_EDUCATIVO.md`).

### 2.3 «Programar dispositivos» corría el riesgo de quedar fuera

Un simulador de bloques enseña a elegir hardware, pero no a programar.

**Decisión.** Tres mecanismos:

1. **Editor de lógica**: algoritmo (encendido/apagado, histéresis, proporcional, PID, disparo con enclavamiento), consigna, ganancias, periodo de muestreo y de reporte.
2. **Arquitectura del firmware**: bloqueante, no bloqueante o RTOS. En modo bloqueante, el simulador suma la conversión del sensor y la latencia de la radio al periodo del lazo.
3. **Firmware generado**: el diseño se traduce a un esqueleto Arduino/C++ comentado (o Python si se elige una Raspberry Pi) que refleja cada decisión: bibliotecas, conversión de unidades, algoritmo, búfer de reenvío, sueño profundo.

### 2.4 Solapamiento con CircuitLab Academy (#34) y CircuitAR (#35)

| App | Pregunta que responde | Nivel |
|---|---|---|
| CircuitLab Academy | ¿Cómo se comporta este circuito? | Circuito (nodos, corrientes) |
| CircuitAR | ¿Qué componente uso y por qué? | Componente |
| **ElectroBoard** | **¿Cómo integro los bloques para cumplir los requisitos?** | **Sistema** |

ElectroBoard no resuelve circuitos: modela interfaces entre bloques y la dinámica del proceso.

### 2.5 Realismo del modelo

**Riesgo.** Un modelo demasiado simple enseña conclusiones falsas; uno demasiado complejo no se puede construir ni mantener.

**Decisión.** Planta de primer orden con perturbaciones, sensor con sesgo, ruido, cuantización, retardo y saturación, y enlace con pérdida, latencia y cortes. Los límites se declaran en la pantalla «Acerca de» y en `MOTOR_Y_EVALUADOR.md`. Las misiones se calibraron para que la solución de referencia apruebe con margen y los errores típicos fallen por la razón correcta.

---

## 3. Decisión sobre la IA: «Evaluador de diseño»

El encargo pide una IA evaluadora. Se evaluó con el mismo criterio de las apps anteriores: ¿aporta algo que una alternativa determinista no pueda dar?

| Función | ¿La IA aporta valor único? | Decisión |
|---|---|---|
| Detectar incompatibilidades eléctricas | **No.** Son reglas finitas y verificables (tensiones, corrientes, interfaces). | **Reglas deterministas** (60 reglas) |
| Medir el desempeño del diseño | **No.** Lo mide la simulación. | **Simulación** |
| Explicar el error y sugerir la corrección | **No en esta versión.** Cada regla tiene un texto revisado, con los valores concretos del diseño. | **Plantillas** con valores |
| Conversar sobre alternativas abiertas («¿y si uso Zigbee?») | **Sí.** | **Versión 2.0**, con el motor como árbitro |

**Razonamiento.** Un diagnóstico eléctrico equivocado enseña física falsa y el estudiante no tiene cómo detectarlo. Cambiar una respuesta siempre correcta por una casi siempre correcta, a cambio de latencia, costo por consulta y dependencia de conexión, es un mal negocio en una app educativa. Por eso, en la app el evaluador se presenta como lo que es: **un evaluador experto basado en reglas**, sin llamarlo IA.

**Condición para la versión 2.0.** Un asistente conversacional podrá proponer diseños y explicar, pero cualquier cifra o veredicto lo dará el simulador y el evaluador, nunca el modelo de lenguaje.

---

## 4. Alcance del MVP

| Incluido | Excluido (y por qué) |
|---|---|
| 6 proyectos, 55 componentes, 5 módulos con 25 lecciones | Editor libre de circuitos: es el terreno de CircuitLab |
| Simulación con 11 eventos (puertas, cortes de red, fallas) | Transitorios eléctricos, EMI, temperatura de los chips |
| 60 reglas con textos y lección asociada | IA generativa (ver §3) |
| Firmware generado (Arduino/C++ y Python) | Compilar o cargar firmware real: requiere hardware |
| Bitácora local, competencias, pistas, solución de referencia al aprobar | Cuentas de usuario, sincronización y panel docente en línea |

---

## 5. Riesgos que quedan abiertos

| Riesgo | Mitigación |
|---|---|
| El estudiante «optimiza al simulador» en vez de al problema | Las misiones incluyen eventos que no se ven en el tablero; la ficha los anuncia, pero no dice cómo resolverlos |
| Precios desactualizados | Están en `components.json`; el docente puede editarlos sin programar |
| Validación académica | Falta que un docente de Sistemas Embebidos revise misiones y reglas antes del piloto (ver `GUIA_DOCENTE.md`) |
| Compilación | El entorno de desarrollo no tenía SDK de Flutter: el primer análisis y compilación reales ocurren en GitHub Actions |

---

## 6. Estructura propia de esta app

El encargo pidió una estructura distinta a la de las apps anteriores. ElectroBoard se organiza así:

| Aspecto | Decisión en ElectroBoard |
|---|---|
| Navegación | Sin barra de pestañas: una **mesa de trabajo** única (`CustomScrollView`) y un flujo lineal por proyecto: ficha → tablero → simulación → informe |
| Interacción principal | **Tablero de bloques** con pistas de cobre que se iluminan al conectar cada ranura |
| Resultado | **Osciloscopio con reproducción**, rúbrica radial de 6 dimensiones y **firmware generado** |
| Contenido | **JSON en `assets/data`**, editable por el docente sin programar y validado por script y pruebas |
| Capas | `domain/` (motor, evaluador, generador de firmware) · `data/` (fuentes y repositorios) · `presentation/` (ViewModels, vistas, widgets) |
| Estética | Placa de circuito: máscara de soldadura verde, cobre y trazo de osciloscopio; ícono propio con microcontrolador, sensor y señal inalámbrica |
