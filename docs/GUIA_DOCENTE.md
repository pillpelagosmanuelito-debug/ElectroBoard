# Guía docente

## 1. Uso en clase

| Momento | Actividad sugerida | Tiempo |
|---|---|---|
| Antes de la sesión | Lecciones del módulo relacionado con la pregunta de control | 20 min |
| En la sesión | Proyecto en parejas: una persona elige el hardware y la otra la lógica; luego intercambian | 40 min |
| Cierre | Comparar informes: ¿qué hallazgo crítico apareció más? ¿Por qué? | 15 min |
| Tarea | Justificar por escrito el diseño aprobado y compararlo con la solución de referencia | — |

**Sugerencia.** Pida que el estudiante registre el primer intento aunque falle. El valor está en leer el informe y rediseñar.

## 2. Editar el contenido sin programar

Todo el contenido está en `assets/data/`:

| Quiero… | Archivo | Campo |
|---|---|---|
| Actualizar un precio | `components.json` | `costPen` |
| Agregar un sensor | `components.json` | nuevo objeto en `sensors` (id ASCII en minúsculas) |
| Ofrecer un componente en un proyecto | `missions.json` | `pools` |
| Endurecer un requisito | `missions.json` | `requirements` (por ejemplo, `minTimeInBandPct`) |
| Cambiar un evento | `missions.json` | `events` (tipo, inicio, duración, valor) |
| Corregir el texto de un hallazgo | `findings.json` | `title`, `message`, `fix` (conserve los `{marcadores}`) |
| Editar una lección | `modules.json` | `lessons` |

Después de editar:

```bash
python3 tools/validate_content.py          # referencias cruzadas y preguntas
python3 tools/reference_engine.py          # ¿la referencia sigue aprobando?
python3 tools/reference_engine.py --fixture   # actualiza los casos esperados de las pruebas
```

Si cambia la dinámica de un proyecto, revise que la solución de referencia apruebe con margen y que los errores típicos sigan fallando por la razón correcta.

## 3. Validación académica pendiente

Antes de un piloto, un docente de Sistemas Embebidos debería revisar:

1. Los valores de las hojas de datos en `components.json` (exactitud, rangos, consumos).
2. Los requisitos de cada proyecto (¿son realistas para el contexto?).
3. Los textos de las 60 reglas y de las 25 lecciones.
4. Los precios referenciales en soles.

## 4. Preguntas frecuentes

**¿Por qué el DS18B20 recibe una advertencia en la incubadora?** Porque su exactitud (±0.5 °C) consume toda la tolerancia de la banda (±0.5 °C). Es el mejor sensor disponible en ese proyecto, pero en la práctica habría que calibrarlo. La advertencia enseña eso.

**¿Por qué el evaluador no usa IA?** Ver `ANALISIS_Y_DECISIONES.md`, sección 3.

**¿El firmware generado compila?** Es un esqueleto didáctico con las bibliotecas y estructuras correctas. Requiere ajustar pines, credenciales y, en algunos casos, versiones de bibliotecas.
