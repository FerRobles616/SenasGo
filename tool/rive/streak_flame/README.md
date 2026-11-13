# Llama Rive de la racha

Fuente editable de `assets/rive/streak_flame.riv`.

- Artboard: `Streak Flame`
- Máquina de estados: `State Machine 1`
- Disparador: `celebrate` (lo activa un toque en la llama)

La escena se compila y firma con el CLI de Rive:

```bash
cd tool/rive/streak_flame
rive . --verify
rive . --publish
cp build/rive_senasgo.riv ../../../assets/rive/streak_flame.riv
```

El archivo publicado queda con la marca de agua del plan actual de Rive; la
app no muestra ningún cartel adicional. La llama tiene respaldo Lottie y PNG
si el archivo no se puede cargar en el dispositivo.
