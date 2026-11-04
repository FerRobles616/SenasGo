"""Genera las animaciones del profesor y reescribe teacher.glb.

Uso:
    python -I tool/avatar/generate.py <glb_entrada> <glb_salida>

Cada seña se describe por intención (dónde va la palma, hacia dónde apuntan
los dedos, qué forma tiene la mano) y se anima con:
  - trayectorias en arco y curvas suaves de aceleración,
  - la forma de la mano armándose en el camino (antes de llegar),
  - la muñeca con un leve retraso respecto del brazo (movimiento encadenado),
  - un pequeño rebote al llegar y micro-movimiento al sostener,
  - respiración y gestos de cabeza y torso.
El brazo no dominante descansa siempre a un costado.

IMPORTANTE (riesgo R3): las señas son ilustrativas hasta que una persona
conocedora de LSPy las valide.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from rig import Glb, Rig, QI, add, mul, norm, qframes, qrot, qslerp, sub
from pose import (SHAPES, ArmPose, BodyPose, Poser,  # noqa: E402
                  apply_constraints, constraints_of)

FPS = 30

# ───────────────────── espacio de referencia ─────────────────────
# Las señas (y las capturas de retarget.py) están escritas en metros sobre
# el cuerpo del jaguar original. BodyMap las lleva al cuerpo del modelo que
# se esté animando, usando hombros y nariz como anclas.
REF_SH_MID = (0.0345, 1.5425, -0.038)
REF_SH_W = 0.399
REF_NOSE = (0.04, 1.74, 0.19)
# Frente del pecho del jaguar (z de la superficie, bajo los hombros).
REF_CHEST_FRONT = 0.2384


def chest_front(rig, sh_mid, k):
    """z de la superficie del pecho, medida en los vértices de reposo."""
    g = rig.glb
    best = None
    for m in g.json.get("meshes", []):
        for p in m["primitives"]:
            for v in g.read(p["attributes"]["POSITION"]):
                if sh_mid[1] - 0.20 * k < v[1] < sh_mid[1] - 0.06 * k and \
                        abs(v[0] - sh_mid[0]) < 0.08 * k:
                    best = v[2] if best is None else max(best, v[2])
    return best


class BodyMap:
    """Traduce puntos del espacio de referencia al cuerpo del modelo."""

    def __init__(self, rig):
        pos, _, _ = rig.world()
        la, ra = pos[rig.idx("LeftArm")], pos[rig.idx("RightArm")]
        self.sh_mid = mul(add(la, ra), 0.5)
        self.sh_w = math.dist(la, ra)
        head = pos[rig.idx("Head")]
        # Largo de la cabeza: hasta la punta (HeadTop_End o "…_end").
        top = None
        for c in rig.nodes[rig.idx("Head")].get("children", []):
            n = rig.nodes[c].get("name", "")
            if n.endswith("HeadTop_End") or n.endswith("_end"):
                top = pos[c]
        hl = math.dist(head, top) if top else self.sh_w * 0.55
        # Hocico del jaguar vs. cara chata de un humanoide.
        snout = 0.9 if rig.nodes[rig.idx("Hips")].get("name") and \
            "Profesor" not in [n.get("name") for n in rig.nodes] else 0.45
        self.nose = (head[0], head[1] + 0.19 * hl, head[2] + snout * hl)
        self.k = self.sh_w / REF_SH_W
        # El jaguar original es el espacio de referencia: queda intacto.
        self.identity = abs(self.k - 1) < 0.01 and \
            math.dist(self.sh_mid, REF_SH_MID) < 0.01
        # La profundidad del cuerpo no sigue al ancho de hombros (el jaguar
        # tiene el pecho muy profundo): lo que va frente al cuerpo se mide
        # desde la superficie del pecho de cada modelo.
        front = None if self.identity else chest_front(
            rig, self.sh_mid, self.k)
        self.chest_front = front if front is not None else \
            self.sh_mid[2] + (REF_CHEST_FRONT - REF_SH_MID[2]) * self.k

    def to_model(self, p):
        if self.identity:
            return p
        k = self.k
        up = (p[1] - REF_SH_MID[1]) / (REF_NOSE[1] - REF_SH_MID[1])
        if up > 0:
            y = self.sh_mid[1] + up * (self.nose[1] - self.sh_mid[1])
        else:
            y = self.sh_mid[1] + (p[1] - REF_SH_MID[1]) * k
        # Cerca de la cara, x y z se miden desde la nariz (así los
        # contactos con frente, mentón o boca se conservan).
        w = max(0.0, min(1.0, up))
        w = w * w * (3 - 2 * w)
        xb = self.sh_mid[0] + (p[0] - REF_SH_MID[0]) * k
        zb = self.chest_front + (p[2] - REF_CHEST_FRONT) * k
        xf = self.nose[0] + (p[0] - REF_NOSE[0]) * k
        zf = self.nose[2] + (p[2] - REF_NOSE[2]) * k
        return (xb + (xf - xb) * w, y, zb + (zf - zb) * w)

# ───────────────────────── curvas ─────────────────────────


def clamp01(x):
    return 0.0 if x < 0 else 1.0 if x > 1 else x


def smoother(u):
    u = clamp01(u)
    return u * u * u * (u * (u * 6 - 15) + 10)


def ease_out(u):
    u = clamp01(u)
    return 1 - (1 - u) ** 3


def bezier(a, c, b, u):
    return add(add(mul(a, (1 - u) ** 2), mul(c, 2 * u * (1 - u))),
               mul(b, u * u))


def frame_q(fingers, facing):
    return qframes((0, 1, 0), (0, 0, 1), fingers, facing)


# ───────────────────────── poses base ─────────────────────────

R_REST = dict(palm=(-0.20, 1.12, 0.12), fingers=(0.05, -1, 0.15),
              facing=(1, 0, 0.1), shape="relaxed")
L_REST = dict(palm=(0.27, 1.12, 0.12), fingers=(-0.05, -1, 0.15),
              facing=(-1, 0, 0.1), shape="relaxed")


class Key:
    """Estado del brazo dominante en un instante, con cómo se llega a él."""

    def __init__(self, t, palm, fingers, facing, shape, arc=(0, 0, 0),
                 lag=0.06, lead=0.75, settle=0.0, body=None, ease=smoother,
                 pole=None):
        self.t = t
        self.palm, self.fingers, self.facing = palm, fingers, facing
        self.shape = shape if isinstance(shape, str) else shape
        self.arc, self.lag, self.lead = arc, lag, lead
        self.settle, self.body, self.ease, self.pole = settle, body, ease, pole

    @classmethod
    def rest(cls, t, **kw):
        return cls(t, R_REST["palm"], R_REST["fingers"], R_REST["facing"],
                   R_REST["shape"], **kw)


def shape_of(s):
    return SHAPES[s] if isinstance(s, str) else s


def body_mix(a, b, u):
    a = a or {}
    b = b or {}
    keys = set(a) | set(b)
    return {k: a.get(k, 0.0) + (b.get(k, 0.0) - a.get(k, 0.0)) * u
            for k in keys}


class Timeline:
    def __init__(self, keys, duration, idle=False):
        self.keys = sorted(keys, key=lambda k: k.t)
        self.duration = duration
        self.idle = idle

    def _segment(self, t):
        ks = self.keys
        if t <= ks[0].t:
            return ks[0], ks[0], 1.0
        for a, b in zip(ks, ks[1:]):
            if t <= b.t:
                return a, b, (t - a.t) / max(1e-6, b.t - a.t)
        return ks[-1], ks[-1], 1.0

    def evaluate(self, t):
        a, b, u = self._segment(t)
        seg = max(1e-6, b.t - a.t)
        ue = b.ease(u)
        # Posición en arco.
        mid = mul(add(a.palm, b.palm), 0.5)
        ctrl = add(mid, b.arc)
        palm = bezier(a.palm, ctrl, b.palm, ue)
        # Rebote corto al llegar a b (se apaga en 0.3 s).
        if a is not b and b.settle:
            after = t - b.t
        else:
            after = -1
        prev_a, prev_b, _ = self._segment(t - 0.3) if t > 0.3 else (a, b, 0)
        if prev_b.settle and 0 <= t - prev_b.t <= 0.3 and prev_a is not prev_b:
            k = (t - prev_b.t) / 0.3
            d = norm(sub(prev_b.palm, prev_a.palm))
            palm = add(palm, mul(d, prev_b.settle * math.sin(k * math.pi) *
                                 (1 - k)))
        # La muñeca sigue al brazo con un leve retraso.
        ur = b.ease(clamp01((t - a.t - b.lag) / max(1e-6, seg - b.lag)))
        q = qslerp(frame_q(a.fingers, a.facing), frame_q(b.fingers, b.facing),
                   ur)
        fingers, facing = qrot(q, (0, 1, 0)), qrot(q, (0, 0, 1))
        # La forma de la mano se completa antes de llegar.
        us = smoother(u / b.lead) if b.lead > 0 else 1.0
        shape = shape_of(a.shape).mix(shape_of(b.shape), us)
        body = body_mix(a.body, b.body, ue)
        return palm, fingers, facing, shape, body, b.pole


def micro(t, seed, amp):
    """Micro-movimiento orgánico: suma de senos sin repetirse a la vista."""
    return (amp * (math.sin(t * 1.7 + seed) * 0.6 + math.sin(t * 2.9 + seed * 2) * 0.4),
            amp * (math.sin(t * 1.3 + seed * 3) * 0.6 + math.sin(t * 3.7 + seed) * 0.4),
            amp * 0.5 * math.sin(t * 2.3 + seed * 5))


def bake(poser, rig, timeline, joints):
    frames = max(2, int(round(timeline.duration * FPS)) + 1)
    times = [i / FPS for i in range(frames)]
    times[-1] = timeline.duration
    constraints = constraints_of(rig)
    joints = list(joints) + [c["node"] for c in constraints
                             if c["node"] not in joints]
    tracks = {j: [] for j in joints}
    for t in times:
        palm, fingers, facing, shape, body, pole = timeline.evaluate(t)
        # Respiración: período de 4 s (el idle hace un ciclo completo).
        breath = 1.1 * math.sin(2 * math.pi * t / 4.0)
        b = BodyPose(pitch=body.get("pitch", 0) + 0.8 * math.sin(2 * math.pi * t / 4.0 + 1.2),
                     yaw=body.get("yaw", 0) + 2.2 * math.sin(2 * math.pi * t / 4.0 + 0.4),
                     roll=body.get("roll", 0),
                     lean=body.get("lean", 0), breath=breath,
                     sway=body.get("sway", 0) + 0.6 * math.sin(2 * math.pi * t / 4.0 + 2.0))
        if timeline.idle:
            palm = add(palm, (0, 0.006 * math.sin(2 * math.pi * t / 4.0), 0))
        else:
            palm = add(palm, micro(t, 0.7, 0.0025))
        lpalm = add(L_REST["palm"],
                    (0, 0.006 * math.sin(2 * math.pi * t / 4.0 + 0.5), 0))
        body_map = getattr(poser, "body_map", None)
        if body_map is None:
            body_map = poser.body_map = BodyMap(rig)
        palm, lpalm = body_map.to_model(palm), body_map.to_model(lpalm)
        arms = {
            "Right": ArmPose(palm, fingers, facing, shape, pole),
            "Left": ArmPose(lpalm, L_REST["fingers"], L_REST["facing"],
                            SHAPES["relaxed"]),
        }
        local = poser.solve(b, arms)
        if constraints:
            apply_constraints(rig, local, constraints)
        for j in joints:
            tracks[j].append(local.get(j, rig.rest_r[j]))
    # Continuidad de signo entre cuadros (evita giros de 360°).
    for j, qs in tracks.items():
        for i in range(1, len(qs)):
            if sum(x * y for x, y in zip(qs[i - 1], qs[i])) < 0:
                qs[i] = tuple(-c for c in qs[i])
    return times, tracks


# ───────────────────────── señas ─────────────────────────
# Coordenadas en metros. x: derecha del profesor es negativa (se ve a la
# izquierda de la pantalla, como un espejo). y: arriba. z: hacia el alumno.

UP = (0, 1, 0)
TO_STUDENT = (0, 0, 1)
TO_SIGNER = (0, 0, -1)


def sign(palm, fingers, facing, shape):
    return dict(palm=palm, fingers=fingers, facing=facing, shape=shape)


SIGNS = {
    # "¡Hola!": mano abierta en alto, sostenida (la animación completa sale
    # de la captura de video; esto arma Forma y Lugar).
    "saludo_hola": dict(
        start=sign((-0.28, 1.50, 0.30), (0.03, 1, -0.1), TO_STUDENT, "open"),
        accent=True, body=dict(roll=3)),
    "saludo_saludos": dict(
        start=sign((-0.07, 1.82, 0.30), (0.35, 1, 0.1), (0, -0.15, 1), "flat"),
        moves=[sign((-0.25, 1.78, 0.46), (0.1, 1, 0.25), (-0.25, 0, 1),
                    "flat")],
        move_time=0.55, arc=(-0.02, 0.04, 0.06), contact=True,
        body=dict(pitch=-4)),
    "saludo_chau": dict(
        start=sign((-0.28, 1.70, 0.32), UP, TO_STUDENT, "open"),
        wave=True, body=dict(roll=4)),
    "numero_uno": dict(
        start=sign((-0.15, 1.56, 0.40), (0.05, 1, 0.08), TO_STUDENT, "one"),
        accent=True),
    "numero_dos": dict(
        start=sign((-0.15, 1.56, 0.40), (0.05, 1, 0.08), TO_STUDENT, "two"),
        accent=True),
    "numero_tres": dict(
        start=sign((-0.15, 1.56, 0.40), (0.05, 1, 0.08), TO_STUDENT, "three"),
        accent=True),
    # Las puntas de los dedos tocan el mentón (no la palma: si no, la mano
    # tapa la cara en personajes de cara chata).
    "basico_gracias": dict(
        start=sign((-0.03, 1.52, 0.37), (0.05, 1, 0.15), TO_SIGNER, "flat"),
        moves=[sign((-0.10, 1.44, 0.52), (0.05, 0.4, 1), (0, 1, -0.3),
                    "flat")],
        move_time=0.6, arc=(-0.02, 0.03, 0.04), contact=True,
        body=dict(pitch=8, lean=3)),
    "basico_si": dict(
        start=sign((-0.13, 1.47, 0.40), (0, 1, 0.25), TO_STUDENT, "fist"),
        nod=True, body=dict()),
    "basico_no": dict(
        start=sign((-0.16, 1.54, 0.40), (0.05, 1, 0.2), (1, 0, 0.15),
                   "no_open"),
        snap=True, body=dict()),
    "basico_por_favor": dict(
        start=sign((-0.04, 1.40, 0.30), (0.55, 0.85, 0), TO_SIGNER, "flat"),
        circle=True, contact=True, body=dict(roll=-5)),
}


def k(t, s, **kw):
    return Key(t, s["palm"], s["fingers"], s["facing"], s["shape"], **kw)


def raise_to(t0, t1, s, settle=0.012):
    """Desde el reposo hasta la posición inicial, en arco hacia adelante."""
    return k(t1, s, arc=(0.0, -0.03, 0.10), settle=settle,
             lead=0.7, lag=0.08)


def with_body(key, body):
    key.body = body
    return key


def movement_keys(spec, t, speed=1.0):
    """Claves del movimiento a partir del instante t. Devuelve (claves, fin)."""
    s = spec["start"]
    keys = []
    body = spec.get("body", {})
    if "moves" in spec:
        dt = spec["move_time"] / speed
        for m in spec["moves"]:
            t += dt
            keys.append(k(t, m, arc=spec.get("arc", (0, 0, 0)), settle=0.01,
                          body=body))
    elif spec.get("wave"):
        amp, per = 0.055, 0.34 / speed
        for i in range(6):
            t += per / 2
            side = -1 if i % 2 == 0 else 1
            p = add(s["palm"], (side * amp, 0.005, 0))
            ang = math.radians(side * -16)
            f = (math.sin(ang), math.cos(ang), 0)
            keys.append(Key(t, p, f, s["facing"], s["shape"], lag=0.05,
                            body=body, ease=smoother))
        t += per / 2
        keys.append(k(t, s, body=body))
    elif spec.get("nod"):
        per = 0.36 / speed
        for i in range(3):
            t += per / 2
            down = Key(t, add(s["palm"], (0, -0.025, 0.01)), (0, 0.55, 0.85),
                       s["facing"] if False else (0, -0.6, 0.8), s["shape"],
                       lag=0.03, body=dict(body, pitch=11))
            keys.append(down)
            t += per / 2
            keys.append(k(t, s, lag=0.03, body=dict(body, pitch=-2)))
    elif spec.get("snap"):
        per = 0.42 / speed
        for i in range(2):
            t += per / 2
            keys.append(Key(t, s["palm"], s["fingers"], s["facing"],
                            "no_closed", lead=0.5,
                            body=dict(body, yaw=14 if i % 2 == 0 else -14)))
            t += per / 2
            keys.append(Key(t, s["palm"], s["fingers"], s["facing"],
                            "no_open", lead=0.5,
                            body=dict(body, yaw=-14 if i % 2 == 0 else 14)))
        t += 0.2 / speed
        keys.append(k(t, s, body=dict(body, yaw=0)))
    elif spec.get("circle"):
        r, steps, per = 0.045, 8, 0.7 / speed
        for loop in range(2):
            for i in range(1, steps + 1):
                a = 2 * math.pi * i / steps
                t += per / steps
                p = add(s["palm"], (-r * math.sin(a), r * (math.cos(a) - 1), 0))
                keys.append(Key(t, p, s["fingers"], s["facing"], s["shape"],
                                lag=0.02, body=body, ease=lambda u: u))
    elif spec.get("accent"):
        t += 0.22 / speed
        keys.append(k(t, dict(s, palm=add(s["palm"], (0, 0.012, 0.03))),
                      body=body))
        t += 0.3 / speed
        keys.append(k(t, s, body=body))
    return keys, t


def contact_tap(spec, t):
    """Toque suave en el lugar de articulación (frente, mentón, pecho)."""
    s = spec["start"]
    back = mul(norm(s["facing"]), -0.02) if s["facing"] != TO_SIGNER else (0, 0, 0.025)
    keys = []
    for _ in range(2):
        t += 0.18
        keys.append(k(t, dict(s, palm=add(s["palm"], back))))
        t += 0.18
        keys.append(k(t, s))
    return keys, t


def default_names(sign_id, spec):
    """Clips de una seña: completa, forma, lugar y, si se mueve, movimiento."""
    names = {sign_id, sign_id + "_forma", sign_id + "_lugar"}
    if any(spec.get(k) for k in ("moves", "wave", "nod", "snap", "circle")):
        names.add(sign_id + "_movimiento")
    return names


def clips_for(sign_id, spec, names=None):
    out = {}
    s = spec["start"]
    body0 = {}
    # Seña completa: sube, articula, sostiene.
    keys = [Key.rest(0.0), with_body(raise_to(0.0, 0.7, s), {})]
    mk, t = movement_keys(spec, 0.9)
    keys += mk
    out[sign_id] = Timeline(keys, t + 0.7)
    # Forma: la mano llega relajada frente al pecho, se arma despacio y gira
    # para mostrar la forma de perfil y de nuevo de frente.
    show = dict(palm=(-0.14, 1.55, 0.44), fingers=(0.05, 1, 0.1),
                facing=TO_STUDENT, shape=s["shape"])
    if sign_id in ("basico_gracias", "basico_por_favor", "saludo_hola"):
        show["facing"] = TO_STUDENT
    relaxed = dict(show, shape="relaxed")
    turned = dict(show, fingers=(0.05, 1, 0.1), facing=norm((0.75, 0, 0.66)))
    keys = [Key.rest(0.0), k(0.65, relaxed, arc=(0, -0.03, 0.1), settle=0.01),
            k(1.45, show, lead=1.0), k(2.15, turned), k(2.85, show)]
    out[sign_id + "_forma"] = Timeline(keys, 3.3)
    # Lugar: va despacio al lugar de la seña ya con la forma, y si hay
    # contacto lo marca con dos toques suaves.
    keys = [Key.rest(0.0), k(1.0, s, arc=(0, -0.03, 0.12), settle=0.012,
                             lead=0.6, lag=0.1)]
    t = 1.2
    if spec.get("contact"):
        tk, t = contact_tap(spec, t)
        keys += tk
    out[sign_id + "_lugar"] = Timeline(keys, t + 0.8)
    # Movimiento: arranca en el lugar y lo repite más lento.
    keys = [k(0.0, s)]
    mk, t = movement_keys(spec, 0.35, speed=0.7)
    keys += mk
    if spec.get("moves"):
        # Vuelve y lo hace otra vez, para verlo dos veces.
        t += 0.35
        keys.append(k(t, s, arc=(0, 0.02, -0.04)))
        mk, t = movement_keys(spec, t + 0.25, speed=0.7)
        keys += mk
    out[sign_id + "_movimiento"] = Timeline(keys, t + 0.7)
    names = default_names(sign_id, spec) if names is None else names
    return {n: tl for n, tl in out.items() if n in names}


def idle_timeline():
    return Timeline([Key.rest(0.0), Key.rest(4.0)], 4.0, idle=True)


def main(src, dst):
    g = Glb(src)
    rig = Rig(g)
    poser = Poser(rig)
    names = {a["name"] for a in g.json.get("animations", [])}
    joints = [i for i, n in enumerate(rig.nodes)
              if n.get("name", "").startswith("mixamorig:")]
    timelines = {"idle": idle_timeline()}
    for sid, spec in SIGNS.items():
        timelines.update(clips_for(sid, spec))
    missing = names - set(timelines)
    extra = set(timelines) - names
    if missing or extra:
        print("quitadas:", sorted(missing), "nuevas:", sorted(extra))
    clips = []
    for name in sorted(timelines):
        times, tracks = bake(poser, rig, timelines[name], joints)
        clips.append((name, times, tracks))
        print(f"  {name:28s} {times[-1]:.2f}s")
    import glb_writer
    size = glb_writer.write(g, clips, dst)
    print(f"{len(clips)} animaciones -> {dst} ({size / 1e6:.1f} MB)")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
