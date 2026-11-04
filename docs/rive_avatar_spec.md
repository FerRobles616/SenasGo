# Avatar profesor en Rive: especificación para diseño

Este documento es el contrato entre el archivo `assets/rive/sign_avatar.riv` y la app.
Si se respetan **los nombres exactos** de la State Machine, los inputs y los huesos,
la app usa el archivo automáticamente, sin cambiar código: lo detecta al iniciar y
reemplaza al avatar procedural. En equipos con poca RAM se sigue usando el procedural.

> **Riesgo R3 (documentación v3_04):** las señas de abajo son ilustrativas. Antes de
> animarlas, una persona que conozca LSPy debe validar cada una.

---

## 1. Dirección de arte ("3D suave" en vectores)

| Aspecto | Regla |
|---|---|
| Estilo | Vector limpio con volumen: degradados suaves en piel y ropa, luz desde arriba a la izquierda, borde de luz (*rim light*) cálido del lado contrario y sombras de contacto difusas. Sin contornos negros gruesos. |
| Personaje | **Jaguareté** amigable (referencia del equipo: guerrero jaguareté con túnica roja), en versión tierna: sin pinchos ni armadura agresiva. |
| Proporciones | Cabeza grande y amable (la figura mide ~3,5 cabezas hasta la cintura); plano medio, de la cintura hacia arriba. |
| Manos | **Lo más importante.** Cada mano es ~1,1× el tamaño de la cara, con cinco dedos que se distinguen, uñas sutiles y pliegue del pulgar. Nunca "manoplas". |
| Rostro | Pelaje naranja con rosetas, orejas redondas, hocico crema, nariz y bigotes. Ojos grandes con brillo; "cejas" de pelaje oscuro muy móviles (son gramática en LSPy) y boca de felino expresiva. |
| Ropa | Túnica violeta de la marca con guarda geométrica clara (rombos), pechera plateada lavanda con chevrones, cinturón y capa/pañuelo violeta. El color es fijo: no hay tienda ni vestuario. |
| Paleta | Pelaje `#F2A33A` (sombra `#D07D1C`), manchas `#3B2A20`, hocico `#FFF4DE`, **manos crema `#F6E7CA`** (contrastan con la túnica para leer la seña), túnica `#C9372C`, metal `#C3CCD6`, dorado `#E4B63E`, cuero `#7B4A2A`. Fondo transparente: la app dibuja el escenario. |
| Artboard | `Profesor`, 1000 × 1000 px, figura centrada; la app lo muestra con `BoxFit.contain`. |

## 2. Esqueleto (nombres exactos)

```
root
└── hips
    └── spine
        └── chest
            ├── neck ── head ─┬─ brow_L, brow_R
            │                 ├─ eyelid_L, eyelid_R
            │                 └─ jaw
            ├── shoulder_R ── upperarm_R ── forearm_R ── hand_R
            │       hand_R ─┬─ thumb_R_1 ── thumb_R_2 ── thumb_R_3
            │               ├─ index_R_1 ── index_R_2 ── index_R_3
            │               ├─ middle_R_1 ── middle_R_2 ── middle_R_3
            │               ├─ ring_R_1 ── ring_R_2 ── ring_R_3
            │               └─ pinky_R_1 ── pinky_R_2 ── pinky_R_3
            └── shoulder_L ── … (igual, con sufijo _L)
```

- `_R` es la **mano dominante** (derecha del profesor). Se ve a la izquierda de la
  pantalla, como en un espejo, para que el estudiante copie el movimiento.
- **IK:** restricción *IK* en `forearm_R` y `forearm_L` hacia los controles
  `ctrl_wrist_R` / `ctrl_wrist_L`, con el codo doblado hacia afuera y abajo. Se
  animan los controles, no los brazos hueso por hueso: así las trayectorias son suaves.
- **Mallas:** manos y antebrazos como *mesh* con pesos sobre las falanges, para que los
  nudillos se deformen sin quebrarse.

## 3. Configuraciones manuales (poses reutilizables)

Ángulos de flexión por falange (MCP / PIP / DIP) cuando el dedo está "cerrado" =
**80° / 95° / 70°**. "Extendido" = 0°. Valores intermedios = proporcional.

| Pose | Pulgar | Índice | Medio | Anular | Meñique | Separación |
|---|---|---|---|---|---|---|
| `relaxed` | 0,12 | 0,12 | 0,16 | 0,20 | 0,24 | baja |
| `open` (mano abierta) | 0 | 0 | 0 | 0 | 0 | alta (abanico) |
| `flat` (mano plana) | 0,1 | 0 | 0 | 0 | 0 | ninguna |
| `fist` (puño) | 0,6 · cruzado | 1 | 1 | 1 | 1 | — |
| `index` (1) | 0,7 · cruzado | 0 | 1 | 1 | 1 | — |
| `v` (2) | 0,7 · cruzado | 0 | 0 | 1 | 1 | media |
| `three` (3) | 0,7 · cruzado | 0 | 0 | 0 | 1 | media |
| `pinch` (pinza) | 0,45 | 0,55 | 0,55 | 1 | 1 | — |

Son los mismos valores que usa la app (`HandShape` en
`lib/features/avatar/domain/sign_animation_model.dart`).

## 4. Animaciones (timelines)

| Timeline | Tipo | Duración |
|---|---|---|
| `idle` | Loop | 4 s: respiración suave (el pecho sube 1–2 px) y parpadeo en 2,5 s |
| `sign_<id>` | One shot | La de la tabla; **empieza y termina en la pose de `idle`** |

Las duraciones tienen que coincidir con las de la app, para que la barra de progreso
de los controles vaya sincronizada. Los tiempos están en milisegundos desde el inicio.

| # | Timeline | Palabra | Duración | Momentos clave |
|---|---|---|---|---|
| 0 | `sign_saludo_hola` | Hola | 2600 | 780: `open` junto a la frente · 1430: hacia afuera y arriba, palma girada −25° · 1872: retención · sonrisa |
| 1 | `sign_saludo_chau` | Chau | 2400 | 480: `open` a la altura del hombro · 768 / 1056 / 1344 / 1632: lateral +7 cm / −5 cm con muñeca ±14° · cabeza inclinada 4° · sonrisa |
| 2 | `sign_numero_uno` | Uno | 1800 | 630: `index` frente al pecho alto · 1350: retención |
| 3 | `sign_numero_dos` | Dos | 1800 | 630: `v` · 1350: retención |
| 4 | `sign_numero_tres` | Tres | 1800 | 630: `three` · 1350: retención |
| 5 | `sign_basico_gracias` | Gracias | 2200 | 616: `flat` en el mentón, palma hacia el profesor · 1364: hacia adelante y abajo, dedos al frente, leve reverencia (cabeza 8°, torso 3°) · 1760: retención · sonrisa |
| 6 | `sign_basico_si` | Sí | 2200 | 484: `fist` de costado · 748 / 1012 / 1276 / 1540: muñeca asiente (+35° / −5°) y la cabeza acompaña (12° / −2°) |
| 7 | `sign_basico_no` | No | 2300 | 506: `v`, palma a 60° · 782 / 1058 / 1334 / 1610: alterna `pinch` y `v` · la cabeza niega ±14° · **ceño fruncido** (negación) |
| 8 | `sign_basico_por_favor` | Por favor | 2600 | 520: `flat` sobre el pecho, palma hacia el cuerpo · círculo de 5 cm, un punto cada 234 ms · cejas de pedido · cabeza inclinada −5° |

Las timelines `sign_*` animan **solo manos, brazos y torso**. El rostro y la cabeza los
controla la app desde los inputs (sección 5), así cada seña lleva la expresión justa.

## 5. State Machine `SignLanguage`

### Inputs (nombres exactos)

| Input | Tipo | Rango | Lo envía la app cuando… |
|---|---|---|---|
| `signIndex` | Number | 0–8 | se elige una seña (`#` de la tabla de la sección 4) |
| `play` | Trigger | — | se reproduce o se repite la seña |
| `progress` | Number | 0–100 | en cada fotograma (solo en la variante de la sección 6) |
| `browRaise` | Number | 0–100 | en cada fotograma: cejas arriba (preguntas) |
| `browFurrow` | Number | 0–100 | en cada fotograma: ceño fruncido (negación) |
| `smile` | Number | 0–100 | en cada fotograma |
| `mouthOpen` | Number | 0–100 | en cada fotograma |
| `headNod` | Number | −100–100 | en cada fotograma: asentir |
| `headShake` | Number | −100–100 | en cada fotograma: negar |

> El runtime de Rive para Flutter (`rive` 0.13) **no admite inputs de texto**. Por eso
> `playSign("Hola")` traduce la palabra a `signIndex = 0` y dispara `play`.

### Capas

| Capa | Contenido | Transiciones |
|---|---|---|
| 1 · **Señas** | `Entry → idle` (loop). Un estado `sign_<id>` por seña. | **Any State → `sign_<id>`**: condición `play` **y** `signIndex == #`, *duration* 250 ms. Al salir de **Any State**, una seña repetida a mitad de camino reinicia con un fundido, sin corte. **`sign_<id>` → `idle`**: *exit time* 100 %, *duration* 300 ms. |
| 2 · **Rostro** | *Blend State Direct* con `face_browRaise`, `face_browFurrow`, `face_smile` y `face_mouthOpen` (cada una es una pose de 1 fotograma), cada una mezclada por su input. | — |
| 3 · **Asentir** | *Blend State 1D* según `headNod`: `head_up` (−100), `head_neutral` (0), `head_down` (100). | — |
| 4 · **Negar** | *Blend State 1D* según `headShake`: `head_turn_L` (−100), neutral (0), `head_turn_R` (100). | — |
| 5 · **Vida** | `idle_blink` en loop (solo párpados), para que parpadee también durante la seña. | — |

**Regla de oro:** dos capas nunca animan la misma propiedad del mismo hueso. Si no, en
Rive gana la última capa y la seña se "rompe".

### Velocidad, pausa y repetición

No hacen falta inputs extra: la app escala el tiempo del runtime. Con 0.5x avanza la
mitad de rápido y en pausa no avanza. Repetir vuelve a disparar `play`.

## 6. Variante con línea de tiempo arrastrable (opcional)

Para que también funcione **arrastrar la barra de progreso**, cada `sign_<id>` de la
capa 1 puede ser un *Blend State 1D* según `progress` (0–100) en lugar de una timeline.
Se arma con poses de 1 fotograma en los momentos clave de la tabla: 0 = idle,
30 ≈ 780 ms, etc. La app ya envía `progress` en cada fotograma; no hay que cambiar nada.

## 7. Exportar y probar

1. En Rive: **Export → Export for runtime** (`.riv`).
2. Guardarlo como `assets/rive/sign_avatar.riv` (la carpeta ya está declarada en `pubspec.yaml`).
3. Correr la app: en la lección, el profesor procedural se reemplaza solo.
4. Probar cada seña: tocarla en la lista de la lección y usar **Repetir**, **0.5x** y **pausa**.
5. Confirmar con la persona que conoce LSPy, seña por seña, y recién ahí marcar
   `validatedByLspyExpert: true` en `sign_animation_catalog.dart` (eso quita la
   etiqueta "POR VALIDAR").
