# Detección de señas con cámara

## Cómo funciona

1. **Cámara** (`camera_service.dart`): la cámara frontal envía 10-15 cuadros por segundo. Ese límite evita que el teléfono se caliente.
2. **Preparación del cuadro** (`frame_processor.dart`, en segundo plano):
   - Mide la luz de la zona central contra los bordes y detecta si está muy oscuro, si hay contraluz o si hay demasiada luz.
   - Endereza la imagen, la espeja como un espejo (vista selfie) y la reduce a 512 px en el lado mayor, en formato RGBA.
3. **MediaPipe Tasks** (`VisionChannel.kt`, Android, en el teléfono y sin internet):
   - `HandLandmarker`: detecta hasta 2 manos, cada una con 21 puntos en la imagen y en 3D (metros).
   - `PoseLandmarker lite`: detecta 33 puntos del cuerpo (cara, hombros, torso).
   - Usa la GPU si el equipo la soporta y, si no, la CPU.
4. **Evaluación** (`sign_evaluator.dart`): mide los parámetros formativos de la seña.

   | Parámetro | Cómo se mide |
   |---|---|
   | Configuración manual | Rectitud 3D de cada dedo, independiente de la distancia y del ángulo. Cada dedo pedido tiene que coincidir. |
   | Orientación de la palma | Normal 3D de la palma (hacia la cámara o hacia la persona), en el percentil 70 del tramo. |
   | Lugar | Posición de la mano respecto de la nariz, la boca y los hombros, medida en "anchos de hombro". Así no depende de qué tan lejos esté el teléfono. |
   | Movimiento | Trayectoria de la palma: quieta, de lado a lado, arriba y abajo, alejarse de la cara o circular. |
   | Expresión facial | Todavía no se evalúa, y la app lo informa así. |

   El evaluador sigue una sola mano: si se ven las dos, no confunde el salto de una mano a la otra con un movimiento. Se prueban tramos de 1,3 s dentro de una ventana de 3 s y se queda con el mejor. Si la seña ya está completa, responde antes de que termine la ventana.
5. **Tolerancia por nivel** (`tolerance_profile.dart`): el nivel 1 acepta más margen en forma, palma, lugar y movimiento. El nivel 5 es más exigente.

## Encuadre

La seña se evalúa respecto del cuerpo, así que hace falta un **encuadre de medio cuerpo**: cara, hombros y mano dentro de la imagen, con el teléfono a un brazo de distancia.
- La pantalla muestra una silueta guía y dos indicadores: "Cara y hombros" y "Mano".
- Los puntos de la mano detectada se dibujan en vivo sobre la imagen.

## Calibración y pruebas

- `test/fixtures/vision/` tiene puntos extraídos de dos fuentes:
  - `real_*`: un video real de una persona haciendo señas.
  - `synth_*`: el esqueleto del profesor 3D. Se usa porque MediaPipe no reconoce las manos estilizadas del avatar.
- Herramientas en `tool/vision/`:
  - `extract_landmarks.py` (video → puntos, con los mismos modelos que la app)
  - `synth_from_avatar.py` (esqueleto → puntos)
  - `confusion_matrix_test.dart`, que imprime la matriz de confusión: `flutter test tool/vision/confusion_matrix_test.dart`
- `test/sign_detection_test.dart` verifica en los niveles 1, 3 y 5:
  - Cada grabación se acepta como su seña.
  - El reposo no se acepta como ninguna seña.
  - No hay confusiones fuera de las anotadas.
- Confusiones conocidas, porque los parámetros medibles coinciden:
  - "dos" ↔ "no": misma forma; el "no" del profesor no golpea los dedos.
  - "chau" → "hola": "chau" empieza con un "hola" quieto.
  - Algunas señas de otros temas, por ejemplo "buenas noches" → "sí".

> Los valores de referencia de cada seña (`sign_reference.dart`) son ilustrativos. Una persona conocedora de LSPy debe validarlos.

## Plataformas

- **Android**: detector real (EDGE AI).
- **iOS y web**: modo conceptual (simulado) hasta integrar MediaPipe en esas plataformas.
