# Progreso en la nube (Supabase/PostgreSQL)

SeñasGo exige una cuenta: la primera pantalla es **Crear cuenta / Iniciar
sesión** y no hay modo invitado. La sesión queda guardada en el teléfono, así
que después la app funciona sin conexión con Hive y sincroniza cuando hay
internet. Al cerrar sesión, el progreso queda en la cuenta y se borra del
teléfono (se conserva solo la apariencia elegida).

## 1. Crear el proyecto

1. Crear un proyecto en Supabase.
2. Abrir **SQL Editor**.
3. Ejecutar, en este orden:
   1. `supabase/migrations/202611090001_init.sql`
   2. `supabase/migrations/202611090002_support_tickets.sql` (reportes)
   3. `supabase/migrations/202611090003_normalizacion_catalogos.sql`
   4. `supabase/seed.sql` (siempre al final; se puede repetir)
5. En **Authentication**, habilitar Email/Password.
6. Para Android, agregar la huella SHA-1 del build en la configuración de Auth.

## 2. Configurar la app

La app lee la configuración por compilación. No se guardan claves en el
repositorio: copiá `supabase.example.json` como `supabase.json` (ignorado por
git) y completá los dos valores (Supabase → Project Settings → API).

- **Android Studio:** elegí la configuración de ejecución **main (Supabase)**.
- **Terminal:** `flutter run --dart-define-from-file=supabase.json`
- **APK:** `flutter build apk --release --dart-define-from-file=supabase.json`

También se pueden pasar sueltos:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://TU_PROYECTO.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=TU_PUBLISHABLE_KEY
```

Para el APK:

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://TU_PROYECTO.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=TU_PUBLISHABLE_KEY
```

Usar la **publishable key / anon key**, nunca la service role key.

## 3. Tablas (3FN)

Diagrama: `docs/diagramas/entidad_relacion.png` (fuente `.mmd`).

| Tabla | PK | FK | Contenido |
|---|---|---|---|
| `categories` | `id` | — | Saludos, Números, Palabras básicas |
| `lessons` | `id` | `category_id → categories` | Lecciones (posición única) |
| `signs` | `id` | `lesson_id → lessons` | Señas (única por lección y posición) |
| `challenge_periods` | `id` | — | Diario, semanal, una sola vez |
| `challenges` | `id` | `period_id → challenge_periods` | Retos |
| `chest_rarities` | `id` | — | Rareza y su premio (XP, protectores) |
| `chests` | `lesson_id` | `lesson_id → lessons`, `rarity_id → chest_rarities` | Cofre de cada lección |
| `appearance_modes` | `id` | — | Oscuro, claro, según el sistema |
| `support_categories` | `id` | — | Problema, idea, contenido, comentario |
| `ticket_statuses` | `id` | — | Abierto, en curso, resuelto |
| `profiles` | `user_id` | `user_id → auth.users` | Nombre y XP (el nivel se calcula) |
| `preferences` | `user_id` | `user_id → profiles`, `appearance → appearance_modes` | Meta diaria, apariencia, recordatorio |
| `streaks` | `user_id` | `user_id → profiles` | Racha, mejor racha, protectores |
| `user_signs` | `(user_id, sign_id)` | `→ profiles`, `→ signs` | Señas aprendidas |
| `attempts` | `id` | `user_id → profiles`, `sign_id → signs` | Historial de práctica |
| `user_challenges` | `(user_id, challenge_id)` | `→ profiles`, `→ challenges` | Retos reclamados |
| `user_chests` | `(user_id, lesson_id)` | `→ profiles`, `→ chests` | Cofres abiertos |
| `support_tickets` | `id` (UUID del teléfono) | `user_id → profiles`, `category → support_categories`, `status → ticket_statuses` | Reportes de soporte |

**Normalización (3FN):** no se guarda nada derivable: el nivel sale de la XP,
la categoría de una seña sale de su lección y el premio de un cofre sale de su
rareza (`chest_rarities`), no de la lección. Los valores fijos (período,
apariencia, categoría y estado de reportes) son tablas de catálogo con PK,
referenciadas por FK; no hay listas de texto repetidas. Al registrarse,
el trigger `on_auth_user_created` crea el perfil, las preferencias y la racha.
Borrar una cuenta borra sus datos en cascada.

## Reportes de soporte

El botón **Enviar reporte** de Ayuda guarda el reporte en `support_tickets`.
Sin conexión queda pendiente y se envía en la próxima sincronización (el ID se
genera en el teléfono, así que reintentar no duplica).

Soporte trabaja desde el panel: **Table Editor → support_inbox** (vista con el
nombre y el correo de quien escribió). Para cambiar el estado, en
`support_tickets` poner `status = 'in_progress'` o `status = 'resolved'` (valores de `ticket_statuses`) y, si
es resuelto, `resolved_at = now()`. La app muestra ese estado en «Tus
reportes». La app solo puede crear reportes y leer los propios; no puede ver la
bandeja ni cambiar estados.

## Recuperar contraseña

La app usa un **código de 6 dígitos** (no un enlace). Hay que editar la
plantilla en **Authentication → Emails → Reset Password** para que incluya el
código, por ejemplo:

```html
<h2>Recuperar contraseña de SeñasGo</h2>
<p>Tu código es: <strong>{{ .Token }}</strong></p>
<p>Escribilo en la app junto con tu contraseña nueva. Vence en 1 hora.</p>
```

**Importante:** el correo que trae Supabase en el plan gratuito solo llega a
los miembros del equipo del proyecto y tiene un límite de pocos envíos por
hora. Para que el código le llegue a cualquier usuario hay que configurar un
SMTP propio en **Project Settings → Authentication → SMTP Settings** (por
ejemplo Gmail con una «contraseña de aplicación» de la cuenta de soporte).

## 4. Seguridad

Las políticas RLS permiten que cada usuario lea y modifique solo sus filas.
Los catálogos (`categories`, `lessons`, `signs`, `challenges`,
`challenge_periods`, `chests`, `chest_rarities`, `appearance_modes`,
`support_categories`, `ticket_statuses`) son de solo lectura para la app; el
administrador los edita desde el panel.

No se sincronizan:

- imágenes ni fotogramas de cámara;
- reportes de soporte;
- correo de contacto;
- diagnósticos del dispositivo.

## 5. Sin configuración

Si faltan `SUPABASE_URL` o `SUPABASE_ANON_KEY`, la app **no se puede usar**:
la pantalla de acceso muestra «Falta configurar el servidor». Toda versión
que se entregue (APK) tiene que compilarse con los dos valores.

Si Supabase pide confirmar el correo al registrarse (opción por defecto en
Authentication → Email), la app avisa y pasa a «Iniciar sesión».

## 6. Pruebas pendientes en un proyecto real

- Crear cuenta.
- Iniciar sesión en un segundo dispositivo.
- Practicar sin internet y sincronizar al reconectar.
- Reinstalar y recuperar progreso.
- Comprobar que un usuario no puede leer datos de otro.
