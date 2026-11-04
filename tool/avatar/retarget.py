"""Traspasa una captura de MediaPipe (tool/capture/extract.py) al jaguareté.

Uso:
    python -I tool/avatar/retarget.py <glb_entrada> <glb_salida> \
        nombre=captura.json:inicio:fin [nombre=...]

Cada clip toma el tramo [inicio, fin] (segundos dentro de la captura) y se
agrega a las animaciones que arma generate.py, con ese nombre.

Ideas del traspaso:
  - Ejes: MediaPipe usa x a la derecha de la imagen, y hacia abajo y z hacia
    la cámara negativa; el jaguar usa y arriba y z hacia el alumno. Es un giro
    de 180° sobre x (no espeja: la mano derecha sigue siendo derecha).
  - Escala: la posición de la mano se mide desde el centro de los hombros de
    la persona y se lleva al centro de los hombros del jaguar, escalada por
    el ancho de hombros. Así "la mano en la frente" sigue en la frente.
  - Orientación de la mano y flexión de cada dedo salen de los 21 puntos de
    la mano; el codo lo resuelve la cinemática inversa de pose.py.
  - Cuadros sin mano detectada: se interpola entre vecinos; en los extremos
    (mano en reposo, fuera del cuadro) se vuelve a la pose de reposo.
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import generate as G  # noqa: E402
from pose import HandShape  # noqa: E402
from rig import add, cross, dot, length, lerp, mul, norm, sub  # noqa: E402

# Hombros del jaguar (huesos LeftArm / RightArm en reposo).
AV_SH_L = (0.233, 1.532, -0.018)
AV_SH_R = (-0.164, 1.553, -0.058)
AV_SH_MID = mul(add(AV_SH_L, AV_SH_R), 0.5)
AV_SH_W = length(sub(AV_SH_L, AV_SH_R))
# Nariz del jaguar (punta del hocico), medida en el modelo.
AV_NOSE = (0.04, 1.74, 0.19)
# Ancho de la cabeza del jaguar a la altura de las orejas (aprox.).
AV_HEAD_W = 0.19

FINGER_CHAINS = {"Index": (5, 6, 7, 8), "Middle": (9, 10, 11, 12),
                 "Ring": (13, 14, 15, 16), "Pinky": (17, 18, 19, 20)}


def mp2av(v):
    return (v[0], -v[1], -v[2])


def bend(a, b, c):
    """Ángulo de flexión (grados) en b entre los segmentos a→b y b→c."""
    u, w = norm(sub(b, a)), norm(sub(c, b))
    return math.degrees(math.acos(max(-1.0, min(1.0, dot(u, w)))))


def clamp(x, lo=0.0, hi=1.0):
    return lo if x < lo else hi if x > hi else x


def hand_params(h):
    """Forma de la mano a partir de los 21 puntos (metros, ejes de cámara)."""
    curls, mcp_only = [], []
    for name, (m, p, d, tip) in FINGER_CHAINS.items():
        b1, b2, b3 = bend(h[0], h[m], h[p]), bend(h[m], h[p], h[d]),             bend(h[p], h[d], h[tip])
        # Nudillo y falanges por separado: una mano plana marca ~15° en el
        # nudillo y ~20° entre las otras dos (ángulo natural y ruido).
        k_mcp = clamp((b1 - 15) / 85, 0, 1.05)
        k_rest = clamp((b2 + b3 - 20) / 165, 0, 1.05)
        curls.append(max(k_mcp, k_rest))
        # Si se dobla sobre todo el nudillo (saludo, "No"), las falanges
        # quedan rectas.
        mcp_only.append(clamp((k_mcp - k_rest) * 1.8))
    spread_deg = math.degrees(math.acos(max(-1, min(1, dot(
        norm(sub(h[8], h[5])), norm(sub(h[20], h[17])))))))
    spread = clamp(spread_deg / 2.9, 0, 14) * (1 - min(curls[0], curls[3]))
    ts = norm(sub(h[5], h[17]))
    width = max(1e-4, length(sub(h[5], h[17])))
    across = dot(sub(h[4], h[0]), ts) / width
    opp = clamp(1.25 - across, -0.1, 1.0)
    tflex = clamp((bend(h[1], h[2], h[3]) + bend(h[2], h[3], h[4])) / 100)
    return HandShape(curls, spread, opp, tflex, mcp_only=mcp_only)


def frame_values(fr, side, size):
    """(palma, dedos, palma_mira, forma) en coordenadas del jaguar, o None.

    La posición sale de la imagen (en píxeles, mucho más estable que los
    metros estimados con una sola cámara): x e y en unidades de ancho de
    hombros; arriba de los hombros se escala para que la nariz de la persona
    caiga en la nariz del jaguar. La profundidad sale de los metros, medida
    respecto de la nariz y atenuada, porque es lo menos confiable.
    """
    pi, pw = fr.get("pose"), fr.get("pose_world")
    if not pi or not pw:
        return None
    W, H = size

    def px(q):
        return (q[0] * W, q[1] * H)
    sl, sr, nose = px(pi[11]), px(pi[12]), px(pi[0])
    ear_l, ear_r = px(pi[7]), px(pi[8])
    head_unit = max(1.0, math.hypot(ear_l[0] - ear_r[0], ear_l[1] - ear_r[1]))
    mid = ((sl[0] + sr[0]) / 2, (sl[1] + sr[1]) / 2)
    unit = max(1.0, math.hypot(sl[0] - sr[0], sl[1] - sr[1]))
    nose_up = max(0.2, (mid[1] - nose[1]) / unit)
    av_nose_up = AV_NOSE[1] - AV_SH_MID[1]
    s_world = AV_SH_W / max(1e-4, length(sub(pw[11], pw[12])))

    def place(img_pt, world_pt):
        dx = (img_pt[0] - mid[0]) / unit
        up = (mid[1] - img_pt[1]) / unit
        # Cerca de la cara, lo horizontal se mide respecto de la nariz y en
        # anchos de cabeza: así la palma en la frente sigue en la frente
        # aunque el jaguar tenga hombros anchos y cabeza más chica.
        x_body = AV_SH_MID[0] + dx * AV_SH_W
        x_face = AV_NOSE[0] + (img_pt[0] - nose[0]) / head_unit * AV_HEAD_W
        k = clamp(up / nose_up)
        k = k * k * (3 - 2 * k)
        y = (AV_SH_MID[1] + up / nose_up * av_nose_up if up > 0
             else AV_SH_MID[1] + up * AV_SH_W)
        dz = -(world_pt[2] - pw[0][2]) * s_world * 0.6
        return (x_body + (x_face - x_body) * k, y, AV_NOSE[2] + dz)

    wi = pi[16] if side == "right" else pi[15]
    ww = pw[16] if side == "right" else pw[15]
    hi, hw = fr.get(side), fr.get(f"{side}_world")
    if not hi or not hw:
        return {"palm": place(px(wi), ww)}
    mcp_i = [sum(hi[k][c] for k in (5, 9, 13, 17)) / 4 for c in (0, 1)]
    palm_img = px((hi[0][0] + 0.65 * (mcp_i[0] - hi[0][0]),
                   hi[0][1] + 0.65 * (mcp_i[1] - hi[0][1])))
    palm = place(palm_img, ww)
    fingers = norm(mp2av(sub(hw[9], hw[0])))
    thumb_side = norm(mp2av(sub(hw[5], hw[17])))
    c = norm(cross(fingers, thumb_side))
    facing = mul(c, -1) if side == "right" else c
    return {"palm": palm, "fingers": fingers, "facing": facing,
            "shape": hand_params(hw)}


def smooth(values, sigma):
    """Suavizado gaussiano de una lista de tuplas (o floats)."""
    n = len(values)
    r = max(1, int(3 * sigma))
    w = [math.exp(-0.5 * (k / sigma) ** 2) for k in range(-r, r + 1)]
    out = []
    for i in range(n):
        acc, tot = None, 0.0
        for k, wk in zip(range(-r, r + 1), w):
            j = min(n - 1, max(0, i + k))
            v = values[j]
            acc = (tuple(a + wk * b for a, b in zip(acc, v))
                   if acc is not None else tuple(wk * b for b in v))
            tot += wk
        out.append(tuple(a / tot for a in acc))
    return out


def shape_vec(s):
    return (*s.curl, s.spread, s.thumb_opp, s.thumb_flex, *s.mcp_only)


def vec_shape(v):
    return HandShape(v[0:4], v[4], v[5], v[6], mcp_only=v[7:11])


class Capture:
    """Clip de captura, con la misma interfaz que generate.Timeline."""

    idle = False

    def __init__(self, path, start, end, side="right", fade=0.35):
        data = json.load(open(path, encoding="utf-8"))
        frames = [f for f in data["frames"] if start <= f["t"] <= end]
        self.times = [f["t"] - start for f in frames]
        self.duration = self.times[-1]
        size = data.get("size", (640, 350))
        vals = [frame_values(f, side, size) for f in frames]
        rest = dict(palm=G.R_REST["palm"], fingers=norm(G.R_REST["fingers"]),
                    facing=norm(G.R_REST["facing"]),
                    shape=G.SHAPES[G.R_REST["shape"]])
        has = [v is not None and "shape" in v for v in vals]
        det = [i for i, h in enumerate(has) if h]
        if not det:
            raise SystemExit(f"sin mano detectada en {path} {start}-{end}")
        n = len(vals)
        palm, fing, face, shp = [], [], [], []
        for i in range(n):
            v = vals[i]
            if has[i]:
                palm.append(v["palm"])
                fing.append(v["fingers"])
                face.append(v["facing"])
                shp.append(shape_vec(v["shape"]))
                continue
            prev = max((j for j in det if j < i), default=None)
            nxt = min((j for j in det if j > i), default=None)
            if prev is not None and nxt is not None:
                u = (i - prev) / (nxt - prev)
                a, b = vals[prev], vals[nxt]
                palm.append(lerp(a["palm"], b["palm"], u))
                fing.append(norm(lerp(a["fingers"], b["fingers"], u)))
                face.append(norm(lerp(a["facing"], b["facing"], u)))
                sa, sb = shape_vec(a["shape"]), shape_vec(b["shape"])
                shp.append(tuple(x + (y - x) * u for x, y in zip(sa, sb)))
                continue
            # Extremo sin mano: de la pose de reposo a la primera/última
            # detección, en `fade` segundos.
            ref = vals[det[0] if prev is None else det[-1]]
            gap = abs(self.times[i] - self.times[det[0] if prev is None
                                                   else det[-1]])
            u = clamp(gap / fade)
            u = u * u * (3 - 2 * u)
            palm.append(lerp(ref["palm"], rest["palm"], u))
            fing.append(norm(lerp(ref["fingers"], rest["fingers"], u)))
            face.append(norm(lerp(ref["facing"], rest["facing"], u)))
            sa, sb = shape_vec(ref["shape"]), shape_vec(rest["shape"])
            shp.append(tuple(x + (y - x) * u for x, y in zip(sa, sb)))
        fps = data.get("fps", 30)
        sig = 1.6 * fps / 30
        self.palm = smooth(palm, sig)
        self.fing = [norm(v) for v in smooth(fing, sig)]
        self.face = [norm(v) for v in smooth(face, sig)]
        self.shp = smooth(shp, sig * 1.2)

    def evaluate(self, t):
        ts = self.times
        if t <= ts[0]:
            i, u = 0, 0.0
        elif t >= ts[-1]:
            i, u = len(ts) - 2, 1.0
        else:
            i = max(k for k in range(len(ts) - 1) if ts[k] <= t)
            u = (t - ts[i]) / max(1e-6, ts[i + 1] - ts[i])
        j = i + 1

        def mix(arr):
            return tuple(a + (b - a) * u for a, b in zip(arr[i], arr[j]))
        return (mix(self.palm), norm(mix(self.fing)), norm(mix(self.face)),
                vec_shape(mix(self.shp)), {}, None)


def main(src, dst, specs):
    from rig import Glb, Rig
    from pose import Poser
    import glb_writer
    g = Glb(src)
    rig = Rig(g)
    poser = Poser(rig)
    joints = [i for i, n in enumerate(rig.nodes)
              if n.get("name", "").startswith("mixamorig:")]
    timelines = {"idle": G.idle_timeline()}
    for sid, spec in G.SIGNS.items():
        timelines.update(G.clips_for(sid, spec))
    for spec in specs:
        name, rest = spec.split("=", 1)
        path, a, b = rest.rsplit(":", 2)
        timelines[name] = Capture(path, float(a), float(b))
    clips = []
    for name in sorted(timelines):
        times, tracks = G.bake(poser, rig, timelines[name], joints)
        clips.append((name, times, tracks))
    size = glb_writer.write(g, clips, dst)
    print(f"{len(clips)} animaciones -> {dst} ({size / 1e6:.1f} MB)")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3:])
