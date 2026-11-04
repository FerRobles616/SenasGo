"""Extrae cuerpo y manos de un tramo de video con MediaPipe Holistic.

Uso (con el entorno que tiene mediapipe y opencv):
    python extract.py <video> <inicio_s> <fin_s> <salida.json> [hoja.png]

Guarda, por cuadro, los puntos del cuerpo en metros (pose_world, 33) y de
cada mano (hand_world, 21, en metros y relativos a la mano) más su posición
en la imagen, para poder revisar y para el traspaso al jaguareté
(tool/avatar/retarget.py). "right" y "left" son las manos de la persona.

Si se pasa hoja.png, dibuja una hoja de control con el esqueleto encima de
algunos cuadros, para ver de un vistazo si la detección es buena.
"""
import json
import os
import sys

import cv2
import mediapipe as mp
from mediapipe.tasks import python as mpt
from mediapipe.tasks.python import vision

MODEL = os.environ.get(
    "HOLISTIC_MODEL",
    "C:/Users/BOX/develop/capture-models/holistic_landmarker.task")

# Conexiones para dibujar (brazos, hombros y dedos).
POSE_LINKS = [(11, 12), (11, 13), (13, 15), (12, 14), (14, 16), (11, 23),
              (12, 24), (23, 24)]
HAND_LINKS = [(0, 1), (1, 2), (2, 3), (3, 4), (0, 5), (5, 6), (6, 7),
              (7, 8), (5, 9), (9, 10), (10, 11), (11, 12), (9, 13), (13, 14),
              (14, 15), (15, 16), (13, 17), (17, 18), (18, 19), (19, 20),
              (0, 17)]


def pts(lms, world=False):
    if not lms:
        return None
    if world:
        return [[round(p.x, 5), round(p.y, 5), round(p.z, 5)] for p in lms]
    return [[round(p.x, 5), round(p.y, 5),
             round(getattr(p, "visibility", 1.0) or 0.0, 3)] for p in lms]


def draw(frame, r):
    h, w = frame.shape[:2]
    if r.pose_landmarks:
        p = r.pose_landmarks
        for a, b in POSE_LINKS:
            cv2.line(frame, (int(p[a].x * w), int(p[a].y * h)),
                     (int(p[b].x * w), int(p[b].y * h)), (255, 200, 0), 2)
    for hand, color in ((r.right_hand_landmarks, (0, 0, 255)),
                        (r.left_hand_landmarks, (0, 200, 0))):
        if not hand:
            continue
        for a, b in HAND_LINKS:
            cv2.line(frame, (int(hand[a].x * w), int(hand[a].y * h)),
                     (int(hand[b].x * w), int(hand[b].y * h)), color, 1)
        for q in hand:
            cv2.circle(frame, (int(q.x * w), int(q.y * h)), 2, color, -1)
    return frame


def main(video, start, end, out_json, sheet=None):
    opts = vision.HolisticLandmarkerOptions(
        base_options=mpt.BaseOptions(model_asset_path=MODEL),
        running_mode=vision.RunningMode.VIDEO)
    lm = vision.HolisticLandmarker.create_from_options(opts)
    cap = cv2.VideoCapture(video)
    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    cap.set(cv2.CAP_PROP_POS_MSEC, start * 1000)
    frames, thumbs = [], []
    i = 0
    while True:
        ok, frame = cap.read()
        if not ok:
            break
        t = start + i / fps
        if t > end:
            break
        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        r = lm.detect_for_video(
            mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb),
            int(t * 1000))
        frames.append({
            "t": round(t - start, 4),
            "pose_world": pts(r.pose_world_landmarks, True),
            "pose": pts(r.pose_landmarks),
            "right_world": pts(r.right_hand_world_landmarks, True),
            "right": pts(r.right_hand_landmarks),
            "left_world": pts(r.left_hand_world_landmarks, True),
            "left": pts(r.left_hand_landmarks),
        })
        if sheet and i % max(1, int(fps / 3)) == 0:
            thumbs.append((t, draw(frame.copy(), r)))
        i += 1
    size = (int(cap.get(cv2.CAP_PROP_FRAME_WIDTH)),
            int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT)))
    data = {"video": os.path.basename(video), "start": start, "end": end,
            "fps": fps, "size": size, "frames": frames}
    with open(out_json, "w", encoding="utf-8") as f:
        json.dump(data, f)
    det = sum(1 for f in frames if f["right_world"])
    print(f"{len(frames)} cuadros, mano derecha en {det} "
          f"({100 * det / max(1, len(frames)):.0f}%) -> {out_json}")
    if sheet and thumbs:
        cols = 6
        h, w = thumbs[0][1].shape[:2]
        rows = (len(thumbs) + cols - 1) // cols
        canvas = 255 * __import__("numpy").ones((rows * h, cols * w, 3),
                                                dtype="uint8")
        for k, (t, img) in enumerate(thumbs):
            y, x = (k // cols) * h, (k % cols) * w
            cv2.putText(img, f"{t - start:.1f}s", (6, 18),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 0), 2)
            canvas[y:y + h, x:x + w] = img
        cv2.imwrite(sheet, canvas)
        print("hoja de control ->", sheet)


if __name__ == "__main__":
    a = sys.argv
    main(a[1], float(a[2]), float(a[3]), a[4], a[5] if len(a) > 5 else None)
