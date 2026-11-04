import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:senasgo/core/constants/app_constants.dart';

/// Resultado del chequeo de entorno previo a validar la seña.
enum LightingStatus { ok, tooDark, backlit, overexposed }

/// Copia "enviable" a un Isolate de un [CameraImage].
///
/// Los buffers del plugin de cámara se reciclan apenas termina el callback,
/// por eso se copian antes de procesar en segundo plano.
class FrameData {
  FrameData({
    required this.width,
    required this.height,
    required this.isBgra,
    required this.planes,
    required this.rowStrides,
    required this.pixelStrides,
    required this.rotationDeg,
    required this.mirror,
  });

  factory FrameData.fromCameraImage(
    CameraImage image, {
    required int rotationDeg,
    required bool mirror,
  }) {
    return FrameData(
      width: image.width,
      height: image.height,
      isBgra: image.format.group == ImageFormatGroup.bgra8888,
      planes: [for (final p in image.planes) Uint8List.fromList(p.bytes)],
      rowStrides: [for (final p in image.planes) p.bytesPerRow],
      pixelStrides: [for (final p in image.planes) p.bytesPerPixel ?? 1],
      rotationDeg: rotationDeg,
      mirror: mirror,
    );
  }

  final int width;
  final int height;
  final bool isBgra;
  final List<Uint8List> planes;
  final List<int> rowStrides;
  final List<int> pixelStrides;

  /// Rotación horaria necesaria para ver la imagen derecha (sensorOrientation).
  final int rotationDeg;

  /// Cámara frontal: se espeja para coincidir con la vista previa.
  final bool mirror;
}

class ProcessedFrame {
  const ProcessedFrame({
    required this.lighting,
    required this.centerLuma,
    required this.borderLuma,
    this.modelInput,
  });

  final LightingStatus lighting;
  final double centerLuma;
  final double borderLuma;

  /// Recorte del recuadro guía en RGB normalizado [0,1], NHWC.
  /// Null si no se pidió entrada para el modelo.
  final Float32List? modelInput;
}

/// Pide al procesador la entrada del modelo solo si hay modelo cargado.
class FrameRequest {
  const FrameRequest(this.frame, {this.inputSize});

  final FrameData frame;
  final int? inputSize;
}

/// Función pura pensada para `Isolate.run`: analiza iluminación y recorta
/// el recuadro guía para el modelo, sin bloquear la UI.
ProcessedFrame processFrame(FrameRequest request) {
  final f = request.frame;
  final sampler = _PixelSampler(f);

  // ── 1. Iluminación: luma dentro del recuadro vs. fondo ──
  final upW = sampler.uprightWidth;
  final upH = sampler.uprightHeight;
  final box = _guideBox(upW, upH);

  var centerSum = 0.0, centerN = 0, borderSum = 0.0, borderN = 0;
  const step = 8; // submuestreo: ~1/64 de los píxeles alcanza
  for (var y = 0; y < upH; y += step) {
    for (var x = 0; x < upW; x += step) {
      final luma = sampler.luma(x, y);
      if (x >= box.left && x < box.right && y >= box.top && y < box.bottom) {
        centerSum += luma;
        centerN++;
      } else {
        borderSum += luma;
        borderN++;
      }
    }
  }
  final center = centerN == 0 ? 0.0 : centerSum / centerN;
  final border = borderN == 0 ? center : borderSum / borderN;

  final LightingStatus lighting;
  if (center < AppConstants.minCenterLuma) {
    lighting = LightingStatus.tooDark;
  } else if (border > AppConstants.backlightMinBorderLuma &&
      border - center > AppConstants.backlightMinDelta) {
    lighting = LightingStatus.backlit;
  } else if (center > AppConstants.maxCenterLuma) {
    lighting = LightingStatus.overexposed;
  } else {
    lighting = LightingStatus.ok;
  }

  // ── 2. Recorte del recuadro guía para el modelo de landmarks ──
  Float32List? input;
  final size = request.inputSize;
  if (size != null && lighting == LightingStatus.ok) {
    input = Float32List(size * size * 3);
    final scale = box.width / size;
    var i = 0;
    for (var v = 0; v < size; v++) {
      final y = (box.top + v * scale).toInt();
      for (var u = 0; u < size; u++) {
        final x = (box.left + u * scale).toInt();
        sampler.rgbInto(x, y, input, i);
        i += 3;
      }
    }
  }

  return ProcessedFrame(
    lighting: lighting,
    centerLuma: center,
    borderLuma: border,
    modelInput: input,
  );
}

class _Box {
  const _Box(this.left, this.top, this.width);
  final int left;
  final int top;
  final int width;
  int get right => left + width;
  int get bottom => top + width;
}

/// Recuadro cuadrado centrado, igual al que dibuja la UI sobre la vista previa.
_Box _guideBox(int w, int h) {
  final side = (w * AppConstants.guideBoxFraction).toInt().clamp(1, h);
  return _Box((w - side) ~/ 2, (h - side) ~/ 2, side);
}

/// Lee píxeles en coordenadas "derechas" (ya rotadas y espejadas) desde
/// YUV420 (Android, 3 planos; iOS NV12, 2 planos) o BGRA8888 (iOS).
class _PixelSampler {
  _PixelSampler(this.f);

  final FrameData f;

  bool get _swap => f.rotationDeg == 90 || f.rotationDeg == 270;
  int get uprightWidth => _swap ? f.height : f.width;
  int get uprightHeight => _swap ? f.width : f.height;

  /// Coordenada derecha (x, y) -> coordenada cruda del sensor.
  (int, int) _raw(int x, int y) {
    if (f.mirror) x = uprightWidth - 1 - x;
    switch (f.rotationDeg) {
      case 90:
        return (y, f.height - 1 - x);
      case 180:
        return (f.width - 1 - x, f.height - 1 - y);
      case 270:
        return (f.width - 1 - y, x);
      default:
        return (x, y);
    }
  }

  double luma(int x, int y) {
    final (rx, ry) = _raw(x, y);
    if (f.isBgra) {
      final o = ry * f.rowStrides[0] + rx * 4;
      final p = f.planes[0];
      return 0.114 * p[o] + 0.587 * p[o + 1] + 0.299 * p[o + 2];
    }
    return f.planes[0][ry * f.rowStrides[0] + rx].toDouble();
  }

  void rgbInto(int x, int y, Float32List out, int i) {
    final (rx, ry) = _raw(x, y);
    double r, g, b;
    if (f.isBgra) {
      final o = ry * f.rowStrides[0] + rx * 4;
      final p = f.planes[0];
      b = p[o].toDouble();
      g = p[o + 1].toDouble();
      r = p[o + 2].toDouble();
    } else {
      final yy = f.planes[0][ry * f.rowStrides[0] + rx].toDouble();
      final double u, v;
      if (f.planes.length == 2) {
        // NV12 (iOS): plano UV intercalado
        final o = (ry >> 1) * f.rowStrides[1] + (rx >> 1) * 2;
        u = f.planes[1][o] - 128.0;
        v = f.planes[1][o + 1] - 128.0;
      } else {
        final o = (ry >> 1) * f.rowStrides[1] + (rx >> 1) * f.pixelStrides[1];
        u = f.planes[1][o] - 128.0;
        v = f.planes[2][o] - 128.0;
      }
      r = yy + 1.402 * v;
      g = yy - 0.344 * u - 0.714 * v;
      b = yy + 1.772 * u;
    }
    out[i] = r.clamp(0, 255) / 255;
    out[i + 1] = g.clamp(0, 255) / 255;
    out[i + 2] = b.clamp(0, 255) / 255;
  }
}
