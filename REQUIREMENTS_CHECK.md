# Requisitos y fixes del entorno

> **Nota histórica:** este documento registra el entorno Windows donde se
> inició el proyecto. La versión actual se desarrolla y verifica en Linux
> (Nobara 44) con Flutter 3.47.7; los pasos de Windows se conservan como
> referencia y no describen la máquina actual.

## Entorno verificado (máquina de trabajo)

| Componente | Estado |
|------------|--------|
| Flutter | 3.47.7 stable ✅ |
| Windows | 11 (25H2) ✅ |
| Android SDK | 36 ✅ |
| Java | 17 ✅ |
| NDK | 28.2.13676358 (r28c) ✅ *instalado manualmente* |
| Emulador | Medium_Phone_API_37.0 ✅ (`emulator-5554`) |
| Chrome / Edge / Windows desktop | ✅ |

## Problemas encontrados al ejecutar y cómo se resolvieron

### 1. `flutter pub get` fallaba
- `tflite_flutter_helper ^0.0.2` no existe → **eliminado**.
- `json_annotation ^5.0.2` no existe → **^4.9.0**.
- Conflicto `freezed` + `hive_generator` por el sistema `macros` del SDK
  nuevo → **se quitó freezed** (los modelos usan Hive, no Freezed).
- `very_good_analysis` forzaba un analyzer viejo que hacía crashear el
  análisis → **se usa `flutter_lints` + `analyzer ^6.4.1`**.

### 2. `dart analyze` / errores de compilación
- Imports con `\` (ruta Windows) en `practice_view.dart` → **corregidos a `/`**.
- Falta import de `UserModel` en `main.dart` → **agregado**.

### 3. Falta la estructura nativa
- `flutter create . --project-name senasgo --org py.com.senasgo --platforms android,ios`
  (genera `build.gradle.kts`, `MainActivity.kt`, wrapper de Gradle, Xcode).

### 4. Build de Gradle: "path contains non-ASCII characters"
- La carpeta `SeñasGo` tiene "ñ" → AGP se niega a compilar.
- **Fix (oficial de Android):** en `android/gradle.properties`:
  ```properties
  android.overridePathCheck=true
  ```
  *(Alternativa limpia: clonar el proyecto en una ruta solo-ASCII.)*

### 5. Build: "Android sdkmanager did not install NDK 28.2.13676358"
- El nuevo CLI `android` falló al instalar el NDK desde Gradle.
- **Fix:** instalación manual del NDK:
  ```powershell
  $sdk="$env:LOCALAPPDATA\Android\Sdk"
  cmd /c "echo y | `"$sdk\cmdline-tools\latest\bin\sdkmanager.bat`" --sdk_root=$sdk --install `"ndk;28.2.13676358`""
  ```
  Verificación: `$sdk\ndk\28.2.13676358\source.properties` debe existir.

### 6. Emulador "offline" para siempre
- Se reinició limpio:
  ```powershell
  Get-Process | Where-Object { $_.ProcessName -match 'qemu|emulator' } | Stop-Process -Force
  Start-Process "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe" `
    -ArgumentList '-avd','Medium_Phone_API_37.0','-no-snapshot','-no-audio','-no-boot-anim','-gpu','swiftshader_indirect'
  ```
- Verificación: `adb shell getprop sys.boot_completed` → `1`.

### 7. "Host desconocido (repo.maven.apache.org)" al bajar AARs
- Fallo de red transitorio: Gradle quedó sin `tensorflow-lite-2.11.0.aar`,
  `tensorflow-lite-gpu-2.11.0.aar` y `relinker-1.4.5.aar` (los `.pom` sí).
- **Fix:** verificar que la red resuelve y reintentar `flutter run`
  (Gradle retoma la descarga). Comprobación rápida:
  ```powershell
  Invoke-WebRequest -Uri "https://repo.maven.apache.org/maven2/org/tensorflow/tensorflow-lite/2.11.0/tensorflow-lite-2.11.0.aar" -Method Head
  ```
- Si la caché quedó incompleta: borrar el módulo en
  `%USERPROFILE%\.gradle\caches\modules-2\files-2.1\<grupo>\<artefacto>` y reintentar.

### 8. `:camera_android_camerax:compileDebugJavaWithJavac` →
`class file for androidx.concurrent.futures.CallbackToFutureAdapter not found`
- `camera-core 1.5.x` expone `androidx.concurrent` solo en runtime, pero javac
  necesita esa clase al procesar las anotaciones de `SurfaceRequest`.
- **Fix** aplicado en `android/build.gradle.kts` (bloque `subprojects`):
  agregar `implementation "androidx.concurrent:concurrent-futures:1.1.0"`
  a los proyectos `camera_android*`.

### 9. Platforms 35 / 34 / 31
- Se instalan automáticamente en el primer build (licencias aceptadas por AGP).

### 10. `:tflite_flutter:compileDebugKotlin` → Inconsistent JVM Target
(Java 1.8 vs Kotlin 25, porque el JDK del sistema es 25)
- **Fix** aplicado en `android/gradle.properties`:
  ```properties
  kotlin.jvm.target.validation.mode=warning
  ```
  (Alternativa más estricta: forzar `jvmTarget = JVM_17` en todos los
  subproyectos para igualarlos con `compileOptions` de la app.)

### 11. Manifest merger: namespace `org.tensorflow.lite` duplicado (AGP 9)
- `tflite_flutter 0.11.0` trae `org.tensorflow:tensorflow-lite:2.11.0`,
  `tensorflow-lite-gpu` y `tensorflow-lite-api`: los 3 AARs declaran
  `package="org.tensorflow.lite"` y AGP 9 lo trata como **error**.
- **Fix:** subir a `tflite_flutter: ^0.12.1`, que usa los AARs **LiteRT**
  (`com.google.ai.edge.litert:litert:1.4.0` + `litert-gpu`), cuyos
  namespaces son únicos (`org.tensorflow.lite` y `org.tensorflow.lite.gpu`).
- La API Dart (`Interpreter`, `InterpreterOptions`, `IsolateInterpreter`)
  no cambia; `dart analyze` sigue limpio.

### 12. `:app:compileFlutterBuildDebug` → NPE
`Cannot invoke "java.io.File.exists()" because "parent" is null`
- Causa: `build/app/intermediates/flutter/debug/flutter_build.d` quedó **corrupto**
  tras un build interrumpido (contenía rutas truncadas tipo `S:\build\...` en vez
  de `C:\Users\...\SeñasGo\build\...`). Gradle 9 lo usa como `@OutputFiles` y
  al pre-crear directorios recibe una ruta sin unidad → `parent == null`.
- **Fix:** borrar el depfile y regenerarlo:
  ```powershell
  Remove-Item build\app\intermediates\flutter\debug\flutter_build.d -Force
  flutter assemble --no-version-check --depfile build\app\intermediates\flutter\debug\flutter_build.d --output build\app\intermediates\flutter\debug "-dTargetFile=lib/main.dart" -dTargetPlatform=android -dBuildMode=debug -dTrackWidgetCreation=true "-dAndroidArchs=android-arm android-arm64 android-x64" -dMinSdkVersion=21 debug_android_application
  ```
  (Ojo: al invocarlo desde PowerShell hay que **citar** los `-d...=...`; si no,
  el argumento se parte y Dart busca `lib/main` sin extensión.)

### 13. `:jni:configureCMakeDebug[arm64-v8a]` → falla instalación de `cmake;3.22.1`
- El plugin transitivo `jni` compila C++ con CMake. La carpeta
  `%LOCALAPPDATA%\Android\Sdk\cmake\3.22.1` existía **incompleta**
  (sin `package.xml` ni `source.properties`), así que AGP intentaba
  instalarla y fallaba.
- **Fix:** reinstalar con sdkmanager, escapando el `;` para cmd:
  ```powershell
  cmd /c "echo y| `"$env:LOCALAPPDATA\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat`" --sdk_root=`"$env:LOCALAPPDATA\Android\Sdk`" `"cmake;3.22.1`""
  ```
  Verificar `cmake\3.22.1\package.xml` y `bin\cmake.exe`.
- `flutter.ndkVersion` = 28.2.13676358 (ya instalado).

## Comandos finales

```powershell
cd "C:\Users\BOX\Music\SeñasGo"
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze        # -> No issues found!
flutter test           # -> All tests passed!
flutter build apk --debug
flutter run -d emulator-5554
```

## Nota sobre el modelo de IA
`assets/models/gesture_model.tflite` es opcional en esta fase: sin él, la app
corre en modo conceptual (evalúa los 5 parámetros de forma simulada), tal como
describe la documentación v3_04 (IA como Trabajo Futuro / Fase 2).
