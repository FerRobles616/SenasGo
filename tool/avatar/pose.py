"""Solucionador de pose del profesor: cuerpo, brazos (IK) y formas de mano.

Una `Pose` describe la intención ("palma frente al pecho, dedos hacia
arriba, mano en forma de 1") y `Poser.solve` la traduce a rotaciones locales
de cada hueso del esqueleto Mixamo de teacher.glb.
"""
import math

from rig import (QI, add, basis, cross, dot, length, lerp, mul, norm,
                 qaxis, qconj, qframes, qmul, qnorm, qrot, qslerp, sub,
                 swing_twist)

FINGERS = ("Index", "Middle", "Ring", "Pinky")
SIDES = ("Right", "Left")


class HandShape:
    """Forma de mano: flexión 0..1 por dedo, separación y pulgar.

    curl: (índice, medio, anular, meñique); 1 = cerrado (MCP 85°, PIP 95°,
    DIP 70°). spread: grados de apertura entre dedos. thumb_opp: 0 pulgar al
    costado, 1 cruzado delante de la palma. thumb_flex: flexión de sus
    falanges. mcp_only: dedos que se doblan solo en el nudillo (mano "pico").
    """

    def __init__(self, curl, spread=3.0, thumb_opp=0.2, thumb_flex=0.2,
                 thumb_abd=0.0, mcp_only=(0, 0, 0, 0)):
        self.curl = tuple(curl)
        self.spread = spread
        self.thumb_opp = thumb_opp
        self.thumb_flex = thumb_flex
        self.thumb_abd = thumb_abd
        self.mcp_only = tuple(mcp_only)

    def mix(self, other, t):
        def m(a, b):
            return a + (b - a) * t
        return HandShape(
            [m(a, b) for a, b in zip(self.curl, other.curl)],
            m(self.spread, other.spread), m(self.thumb_opp, other.thumb_opp),
            m(self.thumb_flex, other.thumb_flex),
            m(self.thumb_abd, other.thumb_abd),
            [m(a, b) for a, b in zip(self.mcp_only, other.mcp_only)])


SHAPES = {
    # Mano en reposo: cada dedo un poco más curvado que el anterior.
    "relaxed": HandShape((0.22, 0.28, 0.34, 0.40), 3, 0.25, 0.25),
    # Mano plana con dedos juntos (B).
    "flat": HandShape((0.02, 0.02, 0.03, 0.05), 0.5, 0.05, 0.10),
    # Mano abierta con dedos separados (5).
    "open": HandShape((0.0, 0.0, 0.02, 0.04), 11, -0.10, 0.0, 0.35),
    # Números: el pulgar sujeta los dedos que quedan doblados.
    "one": HandShape((0.0, 1.0, 1.0, 1.0), 2, 0.95, 0.65),
    "two": HandShape((0.0, 0.0, 1.0, 1.0), 9, 0.95, 0.65),
    "three": HandShape((0.0, 0.0, 0.0, 1.0), 6, 0.95, 0.75),
    # Puño (S): pulgar cruzado por delante de los dedos.
    "fist": HandShape((1.05, 1.05, 1.05, 1.05), 0, 0.85, 0.55),
    # "No": índice y medio juntos y estirados, listos para cerrarse.
    "no_open": HandShape((0.0, 0.0, 1.0, 1.0), 1, 0.35, 0.10, 0.2),
    "no_closed": HandShape((0.62, 0.62, 1.0, 1.0), 1, 0.45, 0.25, 0.0,
                           (1, 1, 0, 0)),
}


class ArmPose:
    """Intención para un brazo: dónde va el centro de la palma y cómo mira.

    palm: punto del espacio (m). fingers: hacia dónde apuntan los dedos.
    facing: hacia dónde mira la palma. pole: hacia dónde cae el codo.
    """

    def __init__(self, palm, fingers, facing, shape, pole=None):
        self.palm = tuple(palm)
        self.fingers = norm(fingers)
        self.facing = norm(facing)
        self.shape = shape
        self.pole = pole


class BodyPose:
    def __init__(self, pitch=0.0, yaw=0.0, roll=0.0, lean=0.0, breath=0.0,
                 sway=0.0):
        self.pitch, self.yaw, self.roll = pitch, yaw, roll
        self.lean, self.breath, self.sway = lean, breath, sway


class Poser:
    def __init__(self, rig):
        self.rig = rig
        r = rig
        pos, rot, _ = r.world()
        self.rest_pos, self.rest_rot = pos, rot
        self.j = {}
        for name in ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head"]:
            # Algunos modelos (VRM sin pecho superior) tienen menos vértebras.
            if "mixamorig:" + name in r.by_name:
                self.j[name] = r.idx(name)
        self.arm = {}
        for side in SIDES:
            a = {k: r.idx(side + k) for k in
                 ["Shoulder", "Arm", "ForeArm", "Hand"]}
            for f in FINGERS + ("Thumb",):
                for n in (1, 2, 3, 4):
                    a[f + str(n)] = r.idx(f"{side}Hand{f}{n}")
            self.arm[side] = a
        self._calibrate()

    # ───────────────────── calibración en reposo ─────────────────────

    def _hand_frame(self, side, pos):
        a = self.arm[side]
        fingers = norm(sub(pos[a["Middle1"]], pos[a["Hand"]]))
        thumb_side = norm(sub(pos[a["Index1"]], pos[a["Pinky1"]]))
        c = norm(cross(fingers, thumb_side))
        facing = mul(c, -1) if side == "Right" else c
        return fingers, facing, thumb_side

    def _calibrate(self):
        r, pos, rot = self.rig, self.rest_pos, self.rest_rot
        self.cal = {}
        for side in SIDES:
            a = self.arm[side]
            c = {}
            S, E, W = pos[a["Arm"]], pos[a["ForeArm"]], pos[a["Hand"]]
            c["l1"], c["l2"] = length(sub(E, S)), length(sub(W, E))
            c["u0"] = norm(sub(E, S))
            c["f0"] = norm(sub(W, E))
            bend = cross(c["u0"], c["f0"])
            if length(bend) < 1e-3:
                # Brazo recto en reposo (pose en T de VRoid): el codo se
                # dobla llevando el antebrazo hacia adelante.
                bend = cross(c["u0"], (0.0, 0.0, 1.0))
            c["b0"] = norm(bend)
            # Eje del antebrazo en su espacio local: +Y en Mixamo, pero en
            # VRoid los huesos no tienen rotación y apuntan por X.
            c["fore_axis"] = norm(qrot(qconj(rot[a["ForeArm"]]), c["f0"]))
            fh, fc, ts = self._hand_frame(side, pos)
            c["fh0"], c["fc0"], c["ts0"] = fh, fc, ts
            pc = mul(add(add(pos[a["Index1"]], pos[a["Middle1"]]),
                         add(pos[a["Ring1"]], pos[a["Pinky1"]])), 0.25)
            c["palm_off0"] = sub(lerp(pos[a["Hand"]], pc, 0.65), pos[a["Hand"]])
            # Ejes de flexión de cada falange, en el espacio local del hueso.
            c["flex"], c["spread"] = {}, {}
            for f in FINGERS + ("Thumb",):
                for n in (1, 2, 3):
                    j, child = a[f + str(n)], a[f + str(n + 1)]
                    seg = norm(sub(pos[child], pos[j]))
                    axis_w = norm(cross(seg, fc))
                    axis_l = qrot(qconj(rot[j]), axis_w)
                    # Confirmar que +ángulo lleva la punta hacia la palma.
                    test = qmul(rot[j], qaxis(axis_l, 10))
                    moved = qrot(qmul(test, qconj(rot[j])), seg)
                    if dot(sub(moved, seg), fc) < 0:
                        axis_l = mul(axis_l, -1)
                    c["flex"][f + str(n)] = axis_l
                j = a[f + "1"]
                seg = norm(sub(pos[a[f + "2"]], pos[j]))
                axis_l = qrot(qconj(rot[j]), fc)
                test = qmul(rot[j], qaxis(axis_l, 10))
                moved = qrot(qmul(test, qconj(rot[j])), seg)
                if dot(sub(moved, seg), ts) < 0:
                    axis_l = mul(axis_l, -1)
                c["spread"][f] = axis_l  # + = hacia el lado del pulgar
            # Oposición del pulgar: gira alrededor de la dirección de los
            # dedos; + = la punta pasa por delante de la palma.
            j = a["Thumb1"]
            tip_seg = sub(pos[a["Thumb4"]], pos[j])
            axis_l = qrot(qconj(rot[j]), fh)
            test = qmul(rot[j], qaxis(axis_l, 10))
            moved = qrot(qmul(test, qconj(rot[j])), tip_seg)
            if dot(sub(moved, tip_seg), fc) < 0:
                axis_l = mul(axis_l, -1)
            c["opp"] = axis_l
            self.cal[side] = c
        # Ejes del cuerpo (mundo): x lateral, y arriba, z adelante.
        self.shoulder_up_axis = {}
        for side in SIDES:
            j = self.arm[side]["Shoulder"]
            bone = norm(sub(pos[self.arm[side]["Arm"]], pos[j]))
            axis_w = norm(cross(bone, (0, 1, 0)))
            axis_l = qrot(qconj(rot[j]), axis_w)
            test = qmul(rot[j], qaxis(axis_l, 10))
            moved = qrot(qmul(test, qconj(rot[j])), bone)
            if moved[1] < bone[1]:
                axis_l = mul(axis_l, -1)
            self.shoulder_up_axis[side] = axis_l

    # ───────────────────────── resolución ─────────────────────────

    def _world_delta(self, local, idx, parent_global, delta_world):
        """Rotación local que aplica `delta_world` (eje en el mundo)."""
        rest = self.rig.rest_r[idx]
        return qmul(qmul(qmul(qconj(parent_global), delta_world),
                         parent_global), local.get(idx, rest))

    def solve(self, body, arms):
        r = self.rig
        local = {}
        # Cuerpo: respiración y gestos repartidos en la columna y el cuello.
        _, rot, _ = r.world(local)
        X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)
        spine = [(self.j[n], w) for n, w in
                 (("Spine", 0.3), ("Spine1", 0.35), ("Spine2", 0.35))
                 if n in self.j]
        tot = sum(w for _, w in spine) or 1.0
        spine = [(i, w / tot) for i, w in spine]
        for idx, w in spine:
            _, rot, _ = r.world(local)
            d = qmul(qaxis(X, (body.lean + body.breath) * w),
                     qaxis(Z, body.sway * w))
            local[idx] = self._world_delta(local, idx, rot[r.parent[idx]], d)
        for idx, w in [(self.j["Neck"], 0.4), (self.j["Head"], 0.6)]:
            _, rot, _ = r.world(local)
            d = qmul(qmul(qaxis(Y, body.yaw * w), qaxis(X, body.pitch * w)),
                     qaxis(Z, body.roll * w))
            local[idx] = self._world_delta(local, idx, rot[r.parent[idx]], d)
        for side in SIDES:
            self._solve_arm(side, arms[side], local)
        return local

    def _solve_arm(self, side, ap, local):
        r, a, c = self.rig, self.arm[side], self.cal[side]
        sgn = -1 if side == "Right" else 1
        fingers, facing = basis(ap.fingers, ap.facing)[:2]
        # Hombro: se eleva un poco cuando la mano sube por encima del pecho.
        _, rot, _ = r.world(local)
        lift = max(0.0, min(1.0, (ap.palm[1] - 1.42) / 0.40)) * 14
        sh = a["Shoulder"]
        local[sh] = qmul(r.rest_r[sh], qaxis(self.shoulder_up_axis[side], lift))
        pos, rot, _ = r.world(local)
        S = pos[a["Arm"]]
        # Rotación de la mano y posición de la muñeca a partir de la palma.
        hand_delta = qframes(c["fh0"], c["fc0"], fingers, facing)
        G_h = qmul(hand_delta, self.rest_rot[a["Hand"]])
        W = sub(ap.palm, qrot(hand_delta, c["palm_off0"]))
        # IK de dos huesos con el codo hacia `pole`.
        l1, l2 = c["l1"], c["l2"]
        to_w = sub(W, S)
        d = max(abs(l1 - l2) + 1e-3, min(l1 + l2 - 1e-3, length(to_w)))
        dirv = norm(to_w)
        pole = ap.pole or (0.35 * sgn, -1.0, -0.35)
        pperp = norm(sub(pole, mul(dirv, dot(pole, dirv))))
        ca = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
        h = math.sqrt(max(0.0, l1 * l1 - ca * ca))
        E = add(add(S, mul(dirv, ca)), mul(pperp, h))
        W = add(S, mul(dirv, d))
        u1, f1 = norm(sub(E, S)), norm(sub(W, E))
        b1 = norm(cross(u1, f1))
        if length(cross(u1, f1)) < 1e-4:
            b1 = c["b0"]
        G_u = qmul(qframes(c["u0"], c["b0"], u1, b1), self.rest_rot[a["Arm"]])
        G_f = qmul(qframes(c["f0"], c["b0"], f1, b1),
                   self.rest_rot[a["ForeArm"]])
        # Reparto del giro: el antebrazo hace la pronación/supinación, no
        # solo la muñeca (evita la piel retorcida tipo "caramelo").
        L = qmul(qconj(G_f), G_h)
        bone_axis = c["fore_axis"]
        _, tw = swing_twist(L, bone_axis)
        part = qslerp(QI, tw, 0.7)
        G_f = qmul(G_f, part)
        # Locales: cada uno relativo a su padre ya resuelto.
        _, rot, _ = r.world(local)
        G_sh = rot[sh]
        local[a["Arm"]] = qmul(qconj(G_sh), G_u)
        local[a["ForeArm"]] = qmul(qconj(G_u), G_f)
        local[a["Hand"]] = qmul(qconj(G_f), G_h)
        self._solve_fingers(side, ap.shape, local)

    def _solve_fingers(self, side, s, local):
        r, a, c = self.rig, self.arm[side], self.cal[side]
        full = (85.0, 95.0, 70.0)
        spread_mult = {"Index": 1.0, "Middle": 0.0, "Ring": -0.9,
                       "Pinky": -1.9}
        for k, f in enumerate(FINGERS):
            cu = s.curl[k]
            mcp_only = s.mcp_only[k]
            for n in (1, 2, 3):
                j = a[f + str(n)]
                deg = full[n - 1] * cu
                if n > 1:
                    deg *= (1 - mcp_only * 0.85)
                q = qmul(r.rest_r[j], qaxis(c["flex"][f + str(n)], deg))
                if n == 1:
                    q = qmul(q, qaxis(c["spread"][f],
                                      s.spread * spread_mult[f] *
                                      (1 - min(1.0, cu))))
                local[j] = qnorm(q)
        t1 = a["Thumb1"]
        q = qmul(r.rest_r[t1], qaxis(c["opp"], 55 * s.thumb_opp))
        q = qmul(q, qaxis(c["flex"]["Thumb1"],
                          20 * s.thumb_flex - 25 * s.thumb_abd))
        local[t1] = qnorm(q)
        for n, deg in ((2, 45), (3, 55)):
            j = a["Thumb" + str(n)]
            local[j] = qnorm(qmul(r.rest_r[j],
                                  qaxis(c["flex"]["Thumb" + str(n)],
                                        deg * s.thumb_flex)))


# ───────────────────── restricciones (VRM 1.0) ─────────────────────

_AXES = {"X": (1, 0, 0), "Y": (0, 1, 0), "Z": (0, 0, 1),
         "PositiveX": (1, 0, 0), "NegativeX": (-1, 0, 0),
         "PositiveY": (0, 1, 0), "NegativeY": (0, -1, 0),
         "PositiveZ": (0, 0, 1), "NegativeZ": (0, 0, -1)}


def constraints_of(rig):
    for n in rig.nodes:
        c = n.get("extras", {}).get("constraints")
        if c:
            return c
    return []


def apply_constraints(rig, local, constraints):
    """Giros y "apuntar" de huesos de apoyo (mangas, torsión del brazo)."""
    from rig import qbetween_dirs  # noqa: F401  (definida abajo en rig)
    for c in sorted(constraints, key=lambda c: c["kind"] != "roll"):
        dst, src, w = c["node"], c["source"], c["weight"]
        rest_d, rest_s = rig.rest_r[dst], rig.rest_r[src]
        if c["kind"] == "roll":
            cur_s = local.get(src, rest_s)
            delta = qmul(qconj(rest_s), cur_s)
            # Delta del origen expresado en el marco de reposo del destino.
            in_parent = qmul(qmul(rest_s, delta), qconj(rest_s))
            in_dst = qmul(qmul(qconj(rest_d), in_parent), rest_d)
            _, twist = swing_twist(in_dst, _AXES[c["axis"]])
            local[dst] = qnorm(qmul(rest_d, qslerp(QI, twist, w)))
        elif c["kind"] == "aim":
            pos, rot, _ = rig.world(local)
            parent = rig.parent.get(dst)
            pw = rot[parent] if parent is not None else QI
            r_world = qmul(pw, rest_d)
            a0 = qrot(r_world, _AXES[c["axis"]])
            target = norm(sub(pos[src], pos[dst]))
            delta = qslerp(QI, qbetween_dirs(a0, target), w)
            local[dst] = qnorm(qmul(qconj(pw), qmul(delta, r_world)))
    return local
