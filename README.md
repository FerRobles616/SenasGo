# SeñasGo — Aprender LSPy sin conexión

App Flutter para aprender Lengua de Señas Paraguaya (LSPy) con un profesor
3D, práctica guiada por cámara y soporte integrado. Funciona en el teléfono
sin conexión; la sincronización en la nube es opcional y se apoya en
Supabase/PostgreSQL.

## Qué incluye

La navegación principal tiene cinco pestañas: **Aprender**, **Biblioteca**,
**Retos**, **Progreso** y **Ayuda**.

La identidad visual **“Selva eléctrica”** combina verde profundo, turquesa,
ámbar jaguar y coral. Incluye fondos con gradientes suaves, tarjetas con
profundidad y transiciones de pantalla con fade/desplazamiento. Las
animaciones respetan la opción de reducir movimiento del sistema.

- **Aprender**: tarjeta **“Tu próxima seña”** con nombre, progreso, guía y un
  único botón **EMPEZAR**; debajo queda el camino de nodos. La racha y el XP
  viven en una barra compacta, sin tarjetas secundarias que compitan
  con la práctica.
- **Biblioteca**: selector **Lecciones / Señas**, búsqueda contextual y filtros
  por saludos, números y palabras básicas. Cada seña abre su guía o práctica.
- **Retos**: metas diarias y semanales calculadas en el teléfono. Solo se
  muestran los retos activos; las recompensas reclamadas quedan plegadas y
  únicamente aparece un botón cuando hay algo para reclamar.
- **Cofres**: recompensas locales comunes, raras y épicas al completar una
  unidad o un hito. Se abren una sola vez, con animación y sin compras.
- **Progreso**: nivel, XP, precisión, actividad semanal y avance por lección.
- **Racha**: calendario de constancia, mejor racha y protectores locales.
- **Recordatorios**: en Android/iOS se puede agendar una práctica semanal en
  el calendario del teléfono. En web se informa que requiere la app móvil.
- **Perfil**: meta diaria editable, calendario, liga de práctica y comunidad
  offline. No hay amigos, rankings ni cuentas inventadas: la liga compara tu
  XP semanal contra metas personales y la comunidad solo comparte tu progreso
  cuando vos lo decidís.
- **Progreso en la nube (opcional)**: con Supabase/PostgreSQL se puede crear
  una cuenta y recuperar XP, rachas, señas y cofres en otro teléfono. La app
  sigue funcionando sin conexión y sin cuenta; el detalle de configuración
  está en `docs/SUPABASE.md`.
- **Apariencia**: modo **Oscuro**, **Claro** o **Según el sistema**, con
  persistencia local y adaptación de fondos, tarjetas, textos y navegación.
- **Onboarding**: tres pasos (bienvenida, meta diaria y compromiso) y una
  recompensa única de bienvenida de **+10 XP**.
- **Acceso rápido**: tutorial honesto para anclar SeñasGo a la pantalla de
  inicio en Android o instalarlo como PWA. No se simula un widget nativo.
- **Práctica**: cámara a 10–15 FPS, chequeo de luz, encuadre y evaluación
  formativa de los 5 parámetros (sin porcentajes).
- **Profesor 3D guiado**: `assets/models/teacher.glb` con clips por seña y
  pasos **Forma → Lugar → Movimiento**. La cámara no es libre: cada paso elige
  un encuadre de **cabeza a torso** con énfasis en las manos, y el clip termina
  sosteniendo la pose. El panel de pasos es compacto: una instrucción, un
  indicador de progreso, repetir como ícono y una sola acción principal. Si el
  equipo no puede con el visor, cae al póster texturizado y al avatar 2D.
- **Sendero continuo**: el camino de nodos usa una cinta conectada y animada, con tramos completados y pendientes, en lugar de puntos aislados.
- **Panel de pasos simple**: muestra “Paso 2 de 2 · Lugar”, una frase corta y
  botones **Anterior / Siguiente**; al final el botón principal pasa a **Ver
  seña completa**. La navegación por pestañas grandes se reemplazó por puntos
  de progreso.
- **Ayuda y comentarios**: preguntas frecuentes, reportes guardados en Hive,
  copiar al portapapeles y abrir el correo. Nada se envía solo.
- **Sin tienda**: no hay compras ni moneda. Los XP son solo de avance y no se
  gastan.

> Las demostraciones 3D y los valores de referencia son ilustrativos y están
> pendientes de validación por una persona experta en LSPy. La app no
> reemplaza una clase con una persona intérprete o instructora certificada.

## Requisitos

| Requisito | Versión mínima |
|-----------|----------------|
| Flutter | 3.24+ (probado con 3.47.7) |
| Dart | 3.5+ |
| Android SDK | 36, Java 17 |
| Xcode | solo para iOS (macOS) |
| Chrome | solo para la variante web de prueba |
| Blender | 4.x/5.x, solo para regenerar el GLB y el póster |

## Ejecutar

```bash
flutter pub get
flutter run                 # Android/iOS conectado
flutter run -d chrome       # variante web (práctica en modo conceptual)
```

Para Android, el visor 3D usa un servidor local de `model_viewer_plus`; por eso
el manifest incluye `INTERNET` y una configuración de red que solo permite
cleartext hacia `localhost`/`127.0.0.1`. No hay conexiones externas.

### APK

```bash
flutter build apk --release
# Salida: build/app/outputs/flutter-apk/app-release.apk
```

La firma de release todavía debe configurarse con una clave propia antes de
publicar. Para una prueba local también sirve `flutter build apk --debug`.

## Profesor 3D

El GLB se regenera desde el modelo original con:

```bash
blender --background --python tool/build_teacher.py
```

El script crea, por cada seña, un clip completo y tres clips de paso:
`<seña>_forma`, `<seña>_lugar` y `<seña>_movimiento` (los números no tienen
movimiento). La app los consume desde
`lib/features/avatar/domain/teacher_step.dart`; si se agrega una seña hay que
actualizar el catálogo y volver a exportar el GLB.

La cámara del profesor está fijada por paso:

- **Manos**: `0deg 82deg 1.90m`, objetivo en la mano que firma.
- **Cuerpo**: `0deg 80deg 2.60m`, objetivo `0m 1.55m 0m`.

Ambas vistas mantienen cabeza, hombros y torso dentro del encuadre, incluso en
pantallas de 320×640. El póster de respaldo se genera desde el mismo GLB con
materiales y texturas reales:

```bash
blender --background --python tool/render_teacher_poster.py
```

Las demostraciones siguen siendo ilustrativas hasta que una persona experta
en LSPy las valide. Los archivos VRM de muestra no se versionan; el pipeline
espera un avatar propio o uno con licencia que permita modificarlo y
distribuirlo.

## Modelo de IA (Edge AI)

Colocá los modelos en `assets/models/` para activar la inferencia real:

- `hand_landmark.tflite` (MediaPipe Hands)
- `gesture_model.tflite` y `gesture_labels.txt` (clasificador opcional)

Sin ellos la app sigue siendo navegable y usa el **modo conceptual**, que
simula la evaluación para la fase 1 de la documentación. El motor real está
detrás de `LandmarkEngine`; en web se usa un stub sin TensorFlow Lite. En
Android, la cámara y la inferencia real todavía deben probarse en un equipo
físico.

## Estructura

```
lib/
├── core/
│   ├── config/          Hive (móvil y web)
│   ├── constants/       versión, umbrales, metas y textos de soporte
│   ├── services/        cámara, inferencia, Hive, rendimiento
│   ├── theme/           paleta azul, tarjetas, botones y navegación
│   └── vision/          landmarks, geometría, evaluador, tolerancias
├── features/
│   ├── avatar/          profesor 3D, póster y avatar 2D de respaldo
│   ├── challenges/      retos diarios y semanales locales
│   ├── home/            camino de aprendizaje y estadísticas
│   ├── learning/        biblioteca, lección y catálogo semilla
│   ├── onboarding/      bienvenida, meta diaria y recompensa inicial
│   ├── practice/        captura, evaluación y feedback
│   ├── profile/         perfil, liga local y tutorial de acceso rápido
│   ├── progress/        nivel, precisión y actividad
│   ├── streak/          calendario, protectores y mejor racha
│   └── support/         ayuda, reportes y diagnóstico local
├── shared/
│   ├── models/          Hive: usuario, lección, seña, progreso, intento
│   └── widgets/         navegación inferior, botones y mascota
└── main.dart            router GoRouter y arranque offline
```

## Pruebas

```bash
dart analyze
flutter test
```

La suite cubre evaluación geométrica, tolerancias por nivel, progreso,
rachas, reportes de soporte, onboarding, pantallas nuevas y el mapeo de
clips del profesor. Al momento de esta versión pasan **62 pruebas**.

## Notas de diseño

- Documento de referencia: `SeñasGo-Documentacion(v3_05).docx`.
- La app es portrait-only; el recuadro guía asume esa orientación.
- La interfaz usa la paleta **Selva eléctrica** (verde, turquesa y ámbar),
  con camino continuo, tarjetas redondeadas y gamificación propia. Los bordes
  interactivos usan un token de alto contraste para no perderse en modo claro.
- La simplificación prioriza una acción principal por pantalla, menos texto
  duplicado y opciones avanzadas plegadas.
- Los reportes de soporte se guardan como mapas dinámicos en `support_box`,
  sin adapters nuevos ni migraciones.
- El correo de soporte configurado es **senasgolspy@gmail.com**.
- La sincronización en la nube requiere `SUPABASE_URL` y
  `SUPABASE_ANON_KEY`; sin ellos queda desactivada y la app es local.
- La validación de las señas con una persona experta en LSPy sigue pendiente.
  Las fuentes oficiales de referencia incluyen el Signario Digital de Lengua
  de Señas y el manual del Instituto Desarrollo.
