# Progreso en la nube (Supabase/PostgreSQL)

SeñasGo funciona offline con Hive. La nube es opcional y sirve para recuperar
el progreso en otro dispositivo o después de reinstalar.

## 1. Crear el proyecto

1. Crear un proyecto en Supabase.
2. Abrir **SQL Editor**.
3. Ejecutar `supabase/migrations/202611090001_init.sql`.
4. Ejecutar `supabase/seed.sql`.
5. En **Authentication**, habilitar Email/Password.
6. Para Android, agregar la huella SHA-1 del build en la configuración de Auth.

## 2. Configurar la app

La app lee la configuración por compilación. No se guardan claves privadas en
el repositorio.

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

## 3. Tablas

El esquema normalizado incluye:

- `profiles`
- `lessons`
- `signs`
- `user_signs`
- `attempts`
- `game_state`
- `challenges`
- `user_challenges`
- `chests`
- `preferences`
- `sync_events`

Cada tabla tiene PK; las relaciones usan FK. `user_signs` y
`user_challenges` usan PK compuestas para evitar duplicados. `chests` tiene
una restricción única por usuario/fuente.

## 4. Seguridad

Las políticas RLS permiten que cada usuario lea y modifique solo sus filas.
El catálogo (`lessons`, `signs`, `challenges`) es de solo lectura.

No se sincronizan:

- imágenes ni fotogramas de cámara;
- reportes de soporte;
- correo de contacto;
- diagnósticos del dispositivo.

## 5. Sin configuración

Si faltan `SUPABASE_URL` o `SUPABASE_ANON_KEY`, la app:

- no intenta conectarse;
- sigue funcionando con Hive;
- oculta la sección de nube en release;
- muestra una pista de configuración solo en modo debug.

## 6. Pruebas pendientes en un proyecto real

- Crear cuenta.
- Iniciar sesión en un segundo dispositivo.
- Practicar sin internet y sincronizar al reconectar.
- Reinstalar y recuperar progreso.
- Comprobar que un usuario no puede leer datos de otro.
