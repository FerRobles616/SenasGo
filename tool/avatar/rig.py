"""Lectura del esqueleto de teacher.glb y matemática de rotaciones.

Sin dependencias externas: cuaterniones (x, y, z, w) y vectores como tuplas.
"""
import json
import math
import struct

# ───────────────────────── vectores ─────────────────────────


def add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def mul(a, s):
    return (a[0] * s, a[1] * s, a[2] * s)


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2],
            a[0] * b[1] - a[1] * b[0])


def length(a):
    return math.sqrt(dot(a, a))


def norm(a):
    n = length(a)
    return (0.0, 0.0, 0.0) if n < 1e-12 else mul(a, 1.0 / n)


def lerp(a, b, t):
    return add(a, mul(sub(b, a), t))


# ───────────────────────── cuaterniones ─────────────────────────

QI = (0.0, 0.0, 0.0, 1.0)


def qmul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return (aw * bx + ax * bw + ay * bz - az * by,
            aw * by - ax * bz + ay * bw + az * bx,
            aw * bz + ax * by - ay * bx + az * bw,
            aw * bw - ax * bx - ay * by - az * bz)


def qconj(q):
    return (-q[0], -q[1], -q[2], q[3])


def qnorm(q):
    n = math.sqrt(sum(c * c for c in q))
    return QI if n < 1e-12 else tuple(c / n for c in q)


def qrot(q, v):
    """Rota el vector v por q."""
    p = qmul(qmul(q, (v[0], v[1], v[2], 0.0)), qconj(q))
    return (p[0], p[1], p[2])


def qaxis(axis, deg):
    a = norm(axis)
    h = math.radians(deg) / 2
    s = math.sin(h)
    return (a[0] * s, a[1] * s, a[2] * s, math.cos(h))


def qslerp(a, b, t):
    d = sum(x * y for x, y in zip(a, b))
    if d < 0:
        b = tuple(-c for c in b)
        d = -d
    if d > 0.9995:
        return qnorm(tuple(x + (y - x) * t for x, y in zip(a, b)))
    th = math.acos(d)
    s = math.sin(th)
    wa = math.sin((1 - t) * th) / s
    wb = math.sin(t * th) / s
    return tuple(wa * x + wb * y for x, y in zip(a, b))


def qbetween_dirs(u, v):
    """Rotación mínima que lleva la dirección u a la dirección v."""
    u, v = norm(u), norm(v)
    d = dot(u, v)
    if d > 0.999999:
        return QI
    if d < -0.999999:
        ax = cross((1, 0, 0), u)
        if length(ax) < 1e-6:
            ax = cross((0, 1, 0), u)
        return qaxis(ax, 180)
    c = cross(u, v)
    return qnorm((c[0], c[1], c[2], 1 + d))


def qangle(q):
    return 2 * math.degrees(math.acos(min(1.0, abs(q[3]))))


def qfrom_matrix(m):
    """m: filas de una matriz de rotación 3x3."""
    (m00, m01, m02), (m10, m11, m12), (m20, m21, m22) = m
    tr = m00 + m11 + m22
    if tr > 0:
        s = math.sqrt(tr + 1.0) * 2
        return qnorm(((m21 - m12) / s, (m02 - m20) / s, (m10 - m01) / s,
                      0.25 * s))
    if m00 > m11 and m00 > m22:
        s = math.sqrt(1.0 + m00 - m11 - m22) * 2
        return qnorm((0.25 * s, (m01 + m10) / s, (m02 + m20) / s,
                      (m21 - m12) / s))
    if m11 > m22:
        s = math.sqrt(1.0 + m11 - m00 - m22) * 2
        return qnorm(((m01 + m10) / s, 0.25 * s, (m12 + m21) / s,
                      (m02 - m20) / s))
    s = math.sqrt(1.0 + m22 - m00 - m11) * 2
    return qnorm(((m02 + m20) / s, (m12 + m21) / s, 0.25 * s,
                  (m10 - m01) / s))


def basis(primary, secondary):
    """Base ortonormal (x=primary, y=secondary ortogonalizado, z=x×y)."""
    x = norm(primary)
    y = norm(sub(secondary, mul(x, dot(secondary, x))))
    z = cross(x, y)
    return x, y, z


def qframes(a1, a2, b1, b2):
    """Rotación que lleva la base (a1, a2) a la base (b1, b2)."""
    ax, ay, az = basis(a1, a2)
    bx, by, bz = basis(b1, b2)
    # R = B · Aᵀ
    m = [[bx[i] * ax[j] + by[i] * ay[j] + bz[i] * az[j] for j in range(3)]
         for i in range(3)]
    return qfrom_matrix(m)


def swing_twist(q, axis):
    """Separa q en (swing, twist) con twist alrededor de `axis` (local)."""
    p = mul(axis, dot((q[0], q[1], q[2]), axis))
    twist = qnorm((p[0], p[1], p[2], q[3]))
    swing = qmul(q, qconj(twist))
    return swing, twist


# ───────────────────────── GLB ─────────────────────────


class Glb:
    def __init__(self, path):
        data = open(path, "rb").read()
        jlen, _ = struct.unpack("<I4s", data[12:20])
        self.json = json.loads(data[20:20 + jlen])
        off = 20 + jlen
        blen, _ = struct.unpack("<I4s", data[off:off + 8])
        self.bin = bytes(data[off + 8:off + 8 + blen])

    def read(self, acc_index):
        a = self.json["accessors"][acc_index]
        bv = self.json["bufferViews"][a["bufferView"]]
        n = {"SCALAR": 1, "VEC3": 3, "VEC4": 4, "MAT4": 16}[a["type"]]
        start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        vals = struct.unpack_from("<%df" % (a["count"] * n), self.bin, start)
        return [vals[i * n:(i + 1) * n] for i in range(a["count"])]


class Rig:
    """Esqueleto en pose de reposo con jerarquía y transformaciones."""

    def __init__(self, glb):
        self.glb = glb
        nodes = glb.json["nodes"]
        self.nodes = nodes
        self.parent = {}
        for i, n in enumerate(nodes):
            for c in n.get("children", []):
                self.parent[c] = i
        self.by_name = {n.get("name", ""): i for i, n in enumerate(nodes)}
        self.rest_t = [tuple(n.get("translation", (0, 0, 0))) for n in nodes]
        self.rest_r = [tuple(n.get("rotation", QI)) for n in nodes]
        self.rest_s = [tuple(n.get("scale", (1, 1, 1))) for n in nodes]
        depth = {}
        for i in range(len(nodes)):
            d, j = 0, i
            while j in self.parent:
                j = self.parent[j]
                d += 1
            depth[i] = d
        self.order = sorted(range(len(nodes)), key=lambda i: depth[i])

    def idx(self, name):
        return self.by_name["mixamorig:" + name]

    def world(self, local_rot=None):
        """Posición, rotación y escala globales de cada nodo.

        local_rot: dict índice -> rotación local (si falta, la de reposo).
        """
        local_rot = local_rot or {}
        pos, rot, scl = {}, {}, {}
        for i in self.order:
            lr = local_rot.get(i, self.rest_r[i])
            lt = self.rest_t[i]
            ls = self.rest_s[i][0]
            p = self.parent.get(i)
            if p is None:
                pos[i], rot[i], scl[i] = lt, lr, ls
            else:
                pos[i] = add(pos[p], mul(qrot(rot[p], lt), scl[p]))
                rot[i] = qmul(rot[p], lr)
                scl[i] = scl[p] * ls
        return pos, rot, scl
