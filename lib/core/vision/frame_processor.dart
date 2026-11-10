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
    this.rgba,
    this.width = 0,
    this.height = 0,
  });

  final LightingStatus lighting;
  final double centerLuma;
  final double borderLuma;

  /// Imagen derecha y espejada (como la ve la persona), reducida, en RGBA.
  /// Null si no se pidió o si la luz no alcanza para detectar.
  final Uint8List? rgba;
  final int width;
  final int height;

  double get aspect => height == 0 ? 0.75 : width / height;
}

/// [maxSide]: lado mayor de la imagen para el detector; null = solo luz.
class FrameRequest {
  const FrameRequest(this.frame, {this.maxSide});

  final FrameData frame;
  final int? maxSide;
}

/// Función pura pensada para `compute`: mide la luz y prepara la imagen para
/// MediaPipe sin bloquear la UI.
///
/// La luz se mide en la zona central (donde está la persona: cara, torso y
/// manos) contra los bordes, para detectar contraluz (ventana detrás).
ProcessedFrame processFrame(FrameRequest request) {
  final f = request.frame;
  final sampler = _PixelSampler(f);
  final upW = sampler.uprightWidth;
  final upH = sampler.uprightHeight;

  // ── 1. Iluminación ──
  final left = (upW * 0.2).toInt(), right = (upW * 0.8).toInt();
  final top = (upH * 0.1).toInt(), bottom = (upH * 0.9).toInt();
  var centerSum = 0.0, centerN = 0, borderSum = 0.0, borderN = 0;
  const step = 8; // submuestreo: ~1/64 de los píxeles alcanza
  for (var y = 0; y < upH; y += step) {
    for (var x = 0; x < upW; x += step) {
      final luma = sampler.luma(x, y);
      if (x >= left && x < right && y >= top && y < bottom) {
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
  final lighting = classifyLighting(center, border);

  // ── 2. Imagen para el detector ──
  final maxSide = request.maxSide;
  if (maxSide == null || lighting != LightingStatus.ok) {
    return ProcessedFrame(
        lighting: lighting, centerLuma: center, borderLuma: border);
  }
  final long = upW > upH ? upW : upH;
  final scale = long > maxSide ? long / maxSide : 1.0;
  final outW = (upW / scale).floor(), outH = (upH / scale).floor();
  final rgba = Uint8List(outW * outH * 4);
  var i = 0;
  for (var v = 0; v < outH; v++) {
    final y = ((v + 0.5) * scale).toInt().clamp(0, upH - 1);
    for (var u = 0; u < outW; u++) {
      final x = ((u + 0.5) * scale).toInt().clamp(0, upW - 1);
      sampler.rgbaInto(x, y, rgba, i);
      i += 4;
    }
  }
  return ProcessedFrame(
    lighting: lighting,
    centerLuma: center,
    borderLuma: border,
    rgba: rgba,
    width: outW,
    height: outH,
  );
}

/// Umbrales de luz (luma 0-255) de la zona central y de los bordes.
LightingStatus classifyLighting(double center, double border) {
  if (center < AppConstants.minCenterLuma) return LightingStatus.tooDark;
  if (border > AppConstants.backlightMinBorderLuma &&
      border - center > AppConstants.backlightMinDelta) {
    return LightingStatus.backlit;
  }
  if (center > AppConstants.maxCenterLuma) return LightingStatus.overexposed;
  return LightingStatus.ok;
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

  void rgbaInto(int x, int y, Uint8List out, int i) {
    final (rx, ry) = _raw(x, y);
    int r, g, b;
    if (f.isBgra) {
      final o = ry * f.rowStrides[0] + rx * 4;
      final p = f.planes[0];
      b = p[o];
      g = p[o + 1];
      r = p[o + 2];
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
      r = (yy + 1.402 * v).round().clamp(0, 255);
      g = (yy - 0.344 * u - 0.714 * v).round().clamp(0, 255);
      b = (yy + 1.772 * u).round().clamp(0, 255);
    }
    out[i] = r;
    out[i + 1] = g;
    out[i + 2] = b;
    out[i + 3] = 255;
  }
}
