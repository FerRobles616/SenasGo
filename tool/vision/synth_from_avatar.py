"""Puntos de manos y pose sacados del esqueleto del profesor 3D.

El detector de manos de MediaPipe está entrenado con manos reales y no
siempre reconoce las manos estilizadas del avatar. Para tener ejemplos
exactos de las 10 señas, este script toma las articulaciones del esqueleto en
cada cuadro de la animación y las escribe con el MISMO formato que devuelve el
canal nativo de la app (21 puntos por mano en imagen y en 3D, 33 de pose).

Convenciones (iguales a MediaPipe con imagen espejada, como la app):
  imagen: x a la derecha, y hacia abajo, en [0,1]; mundo de la mano: metros,
  centrado en la mano, mismos ejes; z negativo = hacia la cámara.

Uso: python -I tool/vision/synth_from_avatar.py <teacher.glb> <carpeta_salida>
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "avatar"))
from rig import Glb, Rig, qmul, qrot, qconj, qslerp, sub, add  # noqa: E402

FPS = 8
# Cámara como el render de prueba: frente al avatar, encuadre cabeza-cadera.
CAM = (0.0, 1.42, 1.80)
TARGET = (0.0, 1.30, 0.05)
VFOV = math.radians(40)
ASPECT = 480 / 640  # ancho / alto

HAND = {  # índice MediaPipe -> hueso Mixamo (sin lado)
    0: "Hand",
    1: "HandThumb1", 2: "HandThumb2", 3: "HandThumb3", 4: "HandThumb4",
    5: "HandIndex1", 6: "HandIndex2", 7: "HandIndex3", 8: "HandIndex4",
    9: "HandMiddle1", 10: "HandMiddle2", 11: "HandMiddle3", 12: "HandMiddle4",
    13: "HandRing1", 14: "HandRing2", 15: "HandRing3", 16: "HandRing4",
    17: "HandPinky1", 18: "HandPinky2", 19: "HandPinky3", 20: "HandPinky4",
}


def sample(glb, anim, t):
    """Rotaciones locales de cada nodo animado en el tiempo t (lineal)."""
    local = {}
    for ch in anim["channels"]:
        if ch["target"].get("path") != "rotation":
            continue
        s = anim["samplers"][ch["sampler"]]
        times = [x[0] for x in glb.read(s["input"])]
        vals = glb.read(s["output"])
        if t <= times[0]:
            q = vals[0]
        elif t >= times[-1]:
            q = vals[-1]
        else:
            k = max(i for i in range(len(times)) if times[i] <= t)
            a = (t - times[k]) / max(times[k + 1] - times[k], 1e-9)
            q = qslerp(vals[k], vals[k + 1], a)
        local[ch["target"]["node"]] = tuple(q)
    return local


def to_cam(p):
    """Mundo del avatar -> cámara (x der, y arriba, z hacia atrás)."""
    fwd = sub(TARGET, CAM)
    n = math.sqrt(sum(c * c for c in fwd))
    fwd = tuple(c / n for c in fwd)
    right = (fwd[1] * 0 - fwd[2] * 1, fwd[2] * 0 - fwd[0] * 0, fwd[0] * 1 - fwd[1] * 0)
    rn = math.sqrt(sum(c * c for c in right))
    right = tuple(c / rn for c in right)
    up = (right[1] * fwd[2] - right[2] * fwd[1], right[2] * fwd[0] - right[0] * fwd[2],
          right[0] * fwd[1] - right[1] * fwd[0])
    d = sub(p, CAM)
    return (sum(a * b for a, b in zip(d, right)), sum(a * b for a, b in zip(d, up)),
            sum(a * b for a, b in zip(d, fwd)))


def project(p):
    """Mundo -> imagen normalizada ESPEJADA (como la cámara frontal)."""
    x, y, z = to_cam(p)
    f = 0.5 / math.tan(VFOV / 2)
    u = 0.5 + (x / z) * f / ASPECT
    v = 0.5 - (y / z) * f
    return 1 - u, v, z


def hand_points(pos, rig, side):
    img, world = [], []
    joints = [pos[rig.idx(side + HAND[i])] for i in range(21)]
    center = tuple(sum(j[k] for j in joints) / 21 for k in range(3))
    wrist_depth = to_cam(joints[0])[2]
    for j in joints:
        u, v, z = project(j)
        img += [u, v, (z - wrist_depth) * 0.9]
        # Ejes de MediaPipe con imagen espejada: x=-cam_x, y=-cam_y, z=cam_z.
        cx, cy, cz = to_cam(j)
        ox, oy, oz = to_cam(center)
        world += [-(cx - ox), -(cy - oy), (cz - oz)]
    return [round(c, 4) for c in img], [round(c, 4) for c in world]


def pose_points(pos, rot, rig, nose_local):
    head = rig.idx("Head")
    nose = add(pos[head], qrot(rot[head], nose_local))
    up = qrot(rot[head], (0, 1, 0))
    right = qrot(rot[head], (-1, 0, 0))  # derecha del avatar
    sw = math.dist(pos[rig.idx("LeftArm")], pos[rig.idx("RightArm")])
    k = sw / 0.36

    def off(base, r, u):
        return add(base, add(tuple(c * r * k for c in right), tuple(c * u * k for c in up)))

    pts = [None] * 33
    pts[0] = nose
    pts[2] = off(nose, -0.032, 0.035)   # ojo izquierdo
    pts[5] = off(nose, 0.032, 0.035)    # ojo derecho
    pts[1], pts[3] = off(nose, -0.02, 0.035), off(nose, -0.045, 0.035)
    pts[4], pts[6] = off(nose, 0.02, 0.035), off(nose, 0.045, 0.035)
    pts[7], pts[8] = off(nose, -0.075, 0.02), off(nose, 0.075, 0.02)
    pts[9], pts[10] = off(nose, -0.022, -0.04), off(nose, 0.022, -0.04)
    names = {11: "LeftArm", 12: "RightArm", 13: "LeftForeArm", 14: "RightForeArm",
             15: "LeftHand", 16: "RightHand", 23: "LeftUpLeg", 24: "RightUpLeg"}
    for i, n in names.items():
        try:
            pts[i] = pos[rig.idx(n)]
        except KeyError:
            pts[i] = pos[rig.idx("Hips")]
    out = []
    for i in range(33):
        p = pts[i] or pts[0]
        u, v, z = project(p)
        out += [round(u, 4), round(v, 4), 0.0, 1.0 if pts[i] else 0.0]
    return out


def main(glb_path, out_dir):
    glb = Glb(glb_path)
    rig = Rig(glb)
    pos0, rot0, _ = rig.world()
    head = rig.idx("Head")
    # Nariz: delante y un poco arriba del hueso de la cabeza (en reposo).
    sw = math.dist(pos0[rig.idx("LeftArm")], pos0[rig.idx("RightArm")])
    nose_world = add(pos0[head], (0, 0.09 * sw / 0.3, 0.10 * sw / 0.3))
    nose_local = qrot(qconj(rot0[head]), sub(nose_world, pos0[head]))
    os.makedirs(out_dir, exist_ok=True)
    names = [a["name"] for a in glb.json["animations"]]
    wanted = sys.argv[3:] or [n for n in names if "_" in n and not n.endswith(
        ("_forma", "_lugar", "_movimiento"))] + ["idle"]
    for anim in glb.json["animations"]:
        if anim["name"] not in wanted:
            continue
        dur = max(glb.read(anim["samplers"][c["sampler"]]["input"])[-1][0]
                  for c in anim["channels"])
        frames = []
        n = max(2, round(dur * FPS))
        for i in range(n):
            t = i / FPS
            pos, rot, _ = rig.world(sample(glb, anim, t))
            hands = []
            for side, right in (("Right", True), ("Left", False)):
                img, world = hand_points(pos, rig, side)
                hands.append({"points": img, "world": world, "right": right,
                              "score": 0.98})
            frames.append({"t": int(t * 1000), "hands": hands,
                           "pose": pose_points(pos, rot, rig, nose_local)})
        path = os.path.join(out_dir, f"synth_{anim['name']}.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump({"source": f"esqueleto del profesor: {anim['name']}",
                       "aspect": ASPECT, "frames": frames}, f, separators=(",", ":"))
        print(path, len(frames))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
