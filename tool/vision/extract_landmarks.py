"""Extrae puntos de manos y pose con los MISMOS modelos que usa la app.

Sirve para calibrar y probar el evaluador de señas con imágenes reales:
la salida tiene el mismo formato que devuelve el canal nativo de Android
(`senasgo/vision`), así que las pruebas de Dart la leen directamente.

Las imágenes se espejan antes de detectar, igual que la cámara frontal de la
app (vista "selfie").

Uso (con el entorno de captura, que tiene mediapipe):
    python -I tool/vision/extract_landmarks.py video <video.mp4> <inicio_s> <fin_s> <fps> <salida.json>
    python -I tool/vision/extract_landmarks.py images "<carpeta>/<prefijo>__*.png" <fps> <salida.json>
"""
import glob
import json
import os
import sys

import cv2
import mediapipe as mp
import numpy as np
from mediapipe.tasks import python as mp_python
from mediapipe.tasks.python import vision

MODELS = os.environ.get("SENASGO_MODELS", r"C:\Users\BOX\develop\capture-models")
BACKGROUND = (204, 212, 217)  # BGR, fondo neutro para PNG transparentes


def make_detectors():
    hands = vision.HandLandmarker.create_from_options(
        vision.HandLandmarkerOptions(
            base_options=mp_python.BaseOptions(
                model_asset_path=os.path.join(MODELS, "hand_landmarker.task")),
            running_mode=vision.RunningMode.VIDEO,
            num_hands=2,
            min_hand_detection_confidence=0.5,
            min_hand_presence_confidence=0.5,
            min_tracking_confidence=0.5,
        ))
    pose = vision.PoseLandmarker.create_from_options(
        vision.PoseLandmarkerOptions(
            base_options=mp_python.BaseOptions(
                model_asset_path=os.path.join(MODELS, "pose_landmarker_lite.task")),
            running_mode=vision.RunningMode.VIDEO,
            num_poses=1,
            min_pose_detection_confidence=0.5,
            min_pose_presence_confidence=0.5,
            min_tracking_confidence=0.5,
        ))
    return hands, pose


def r4(v):
    return round(float(v), 4)


def detect(hands, pose, bgr, ts_ms):
    mirrored = cv2.flip(bgr, 1)
    rgb = cv2.cvtColor(mirrored, cv2.COLOR_BGR2RGB)
    image = mp.Image(image_format=mp.ImageFormat.SRGB, data=np.ascontiguousarray(rgb))
    hr = hands.detect_for_video(image, ts_ms)
    out_hands = []
    for i, lm in enumerate(hr.hand_landmarks):
        world = hr.hand_world_landmarks[i] if i < len(hr.hand_world_landmarks) else []
        cat = hr.handedness[i][0] if i < len(hr.handedness) and hr.handedness[i] else None
        out_hands.append({
            "points": [r4(c) for p in lm for c in (p.x, p.y, p.z)],
            "world": [r4(c) for p in world for c in (p.x, p.y, p.z)],
            # Con imagen espejada, MediaPipe llama "Left" a la mano derecha real.
            "right": bool(cat and cat.category_name == "Left"),
            "score": r4(cat.score) if cat else 0.0,
        })
    pr = pose.detect_for_video(image, ts_ms)
    body = None
    if pr.pose_landmarks:
        body = [r4(c) for p in pr.pose_landmarks[0]
                for c in (p.x, p.y, p.z, p.visibility or 0.0)]
    h, w = bgr.shape[:2]
    return {"t": ts_ms, "hands": out_hands, "pose": body, "aspect": w / h}


def from_video(path, start, end, fps):
    cap = cv2.VideoCapture(path)
    hands, pose = make_detectors()
    frames = []
    t = start
    while t <= end:
        cap.set(cv2.CAP_PROP_POS_MSEC, t * 1000)
        ok, frame = cap.read()
        if not ok:
            break
        frames.append(detect(hands, pose, frame, int(round(t * 1000))))
        t += 1.0 / fps
    return frames


def from_images(pattern, fps):
    hands, pose = make_detectors()
    frames = []
    for i, path in enumerate(sorted(glob.glob(pattern))):
        img = cv2.imread(path, cv2.IMREAD_UNCHANGED)
        if img is None:
            continue
        if img.ndim == 3 and img.shape[2] == 4:  # PNG con transparencia
            alpha = img[:, :, 3:4].astype(np.float32) / 255.0
            bg = np.empty_like(img[:, :, :3])
            bg[:] = BACKGROUND
            img = (img[:, :, :3] * alpha + bg * (1 - alpha)).astype(np.uint8)
        frames.append(detect(hands, pose, img, int(round(i * 1000 / fps))))
    return frames


def main(argv):
    if argv[1] == "video":
        frames = from_video(argv[2], float(argv[3]), float(argv[4]), float(argv[5]))
        out, source = argv[6], f"{os.path.basename(argv[2])} {argv[3]}-{argv[4]}s"
    elif argv[1] == "images":
        frames = from_images(argv[2], float(argv[3]))
        out, source = argv[4], os.path.basename(argv[2])
    else:
        raise SystemExit(__doc__)
    with open(out, "w", encoding="utf-8") as f:
        aspect = frames[0].pop("aspect") if frames else 0.75
        for fr in frames:
            fr.pop("aspect", None)
        json.dump({"source": source, "aspect": round(aspect, 4), "frames": frames},
                  f, separators=(",", ":"))
    seen = sum(1 for fr in frames if fr["hands"])
    print(f"{out}: {len(frames)} cuadros, {seen} con mano")


if __name__ == "__main__":
    main(sys.argv)
