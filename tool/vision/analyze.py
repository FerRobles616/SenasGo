"""Resume los rasgos de cada archivo de puntos (para calibrar el evaluador).

Uso: python -I tool/vision/analyze.py test/fixtures/vision/*.json
"""
import json
import math
import sys


def v(p, i):
    return (p[i * 3], p[i * 3 + 1], p[i * 3 + 2])


def sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def norm(a):
    return math.sqrt(sum(x * x for x in a))


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2],
            a[0] * b[1] - a[1] * b[0])


def unit(a):
    n = norm(a) or 1
    return tuple(x / n for x in a)


FINGERS = [(5, 6, 7, 8), (9, 10, 11, 12), (13, 14, 15, 16), (17, 18, 19, 20)]


def straightness(w, chain):
    mcp, pip, dip, tip = (v(w, i) for i in chain)
    seg = norm(sub(pip, mcp)) + norm(sub(dip, pip)) + norm(sub(tip, dip))
    return norm(sub(tip, mcp)) / (seg or 1)


def thumb(w):
    width = norm(sub(v(w, 5), v(w, 17))) or 1
    return norm(sub(v(w, 4), v(w, 5))) / width, norm(sub(v(w, 4), v(w, 9))) / width


def palm_normal(w, right):
    n = unit(cross(sub(v(w, 5), v(w, 0)), sub(v(w, 17), v(w, 0))))
    return tuple(-x for x in n) if right else n


def active(hands):
    return min(hands, key=lambda h: h["points"][9 * 3 + 1]) if hands else None


def pose_pt(p, i):
    return (p[i * 4], p[i * 4 + 1])


for path in sys.argv[1:]:
    data = json.load(open(path, encoding="utf-8"))
    rows = []
    for fr in data["frames"]:
        h = active(fr["hands"])
        if not h or not h["world"]:
            continue
        w = h["world"]
        st = [straightness(w, c) for c in FINGERS]
        tb = thumb(w)
        n = palm_normal(w, h["right"])
        loc = ""
        if fr["pose"]:
            p = fr["pose"]
            ls, rs = pose_pt(p, 11), pose_pt(p, 12)
            sw = math.dist(ls, rs) or 1
            nose = pose_pt(p, 0)
            mouth = tuple((a + b) / 2 for a, b in zip(pose_pt(p, 9), pose_pt(p, 10)))
            shy = (ls[1] + rs[1]) / 2
            pts = h["points"]
            tip = (pts[12 * 3], pts[12 * 3 + 1])
            idx = (pts[8 * 3], pts[8 * 3 + 1])
            pc = (sum(pts[i * 3] for i in (0, 5, 9, 17)) / 4,
                  sum(pts[i * 3 + 1] for i in (0, 5, 9, 17)) / 4)
            loc = (f"palm(dx={(pc[0]-nose[0])/sw:+.2f},dyS={(pc[1]-shy)/sw:+.2f}) "
                   f"tip(dyNose={(min(tip[1],idx[1])-nose[1])/sw:+.2f},dMouth={math.dist(idx,mouth)/sw:.2f})")
        rows.append((st, tb, n, loc, len(fr["hands"]), h["right"]))
    print(f"\n== {path.split('/')[-1]}  ({len(rows)} cuadros con mano)")
    for k, (st, tb, n, loc, nh, right) in enumerate(rows):
        if k % max(1, len(rows) // 6) == 0:
            print(f"  dedos[{' '.join(f'{x:.2f}' for x in st)}] pulgar[{tb[0]:.2f},{tb[1]:.2f}] "
                  f"normal[{n[0]:+.2f},{n[1]:+.2f},{n[2]:+.2f}] {'D' if right else 'I'}{nh} {loc}")
