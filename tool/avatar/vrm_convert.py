"""Convierte un personaje VRM (VRoid Studio) en un GLB para el profesor.

Uso:
    python -I tool/avatar/vrm_convert.py <entrada.vrm> <salida.glb>

Qué hace:
  - Renombra los huesos humanoides del VRM a los nombres Mixamo que usan
    rig.py / pose.py / generate.py (`mixamorig:Hips`, `...RightHandIndex1`).
  - Agrega las puntas de dedo (…4) si el modelo no las trae.
  - VRM 0.x mira hacia -Z: lo gira para que mire al alumno (+Z), como el
    resto del circuito.
  - Quita las extensiones propias de VRM (física de pelo, restricciones); los
    materiales quedan con su versión sin luz (KHR_materials_unlit), que da el
    aspecto de dibujo animado y el visor de la app sí entiende.
  - Guarda las expresiones disponibles en `extras.expressions` del nodo raíz
    (para animar cejas y boca más adelante).
"""
import json
import math
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from rig import Glb  # noqa: E402

SIDE = {"left": "Left", "right": "Right"}
FINGERS = {"Index": "Index", "Middle": "Middle", "Ring": "Ring",
           "Little": "Pinky"}


def mixamo_map(vrm1):
    """Nombre humanoide VRM -> nombre Mixamo (sin el prefijo)."""
    m = {"hips": "Hips", "spine": "Spine", "chest": "Spine1",
         "upperChest": "Spine2", "neck": "Neck", "head": "Head"}
    for s, S in SIDE.items():
        m[f"{s}Shoulder"] = f"{S}Shoulder"
        m[f"{s}UpperArm"] = f"{S}Arm"
        m[f"{s}LowerArm"] = f"{S}ForeArm"
        m[f"{s}Hand"] = f"{S}Hand"
        for f, F in FINGERS.items():
            m[f"{s}{f}Proximal"] = f"{S}Hand{F}1"
            m[f"{s}{f}Intermediate"] = f"{S}Hand{F}2"
            m[f"{s}{f}Distal"] = f"{S}Hand{F}3"
        if vrm1:
            m[f"{s}ThumbMetacarpal"] = f"{S}HandThumb1"
            m[f"{s}ThumbProximal"] = f"{S}HandThumb2"
            m[f"{s}ThumbDistal"] = f"{S}HandThumb3"
        else:
            m[f"{s}ThumbProximal"] = f"{S}HandThumb1"
            m[f"{s}ThumbIntermediate"] = f"{S}HandThumb2"
            m[f"{s}ThumbDistal"] = f"{S}HandThumb3"
    return m


def human_bones(j):
    ext = j.get("extensions", {})
    if "VRMC_vrm" in ext:
        hb = ext["VRMC_vrm"]["humanoid"]["humanBones"]
        bones = {k: v["node"] for k, v in hb.items()}
        expr = ext["VRMC_vrm"].get("expressions", {})
        names = list(expr.get("preset", {})) + list(expr.get("custom", {}))
        return True, bones, names
    if "VRM" in ext:
        hb = ext["VRM"]["humanoid"]["humanBones"]
        bones = {b["bone"]: b["node"] for b in hb}
        groups = ext["VRM"].get("blendShapeMaster", {}).get(
            "blendShapeGroups", [])
        names = [g.get("presetName") or g.get("name") for g in groups]
        return False, bones, names
    raise SystemExit("No es un VRM (falta la extensión VRMC_vrm o VRM)")


def main(src, dst):
    g = Glb(src)
    j = g.json
    vrm1, bones, expressions = human_bones(j)
    mapping = mixamo_map(vrm1)
    missing = [k for k in ("upperChest",) if k not in bones]
    nodes = j["nodes"]
    for vrm_name, node in bones.items():
        if vrm_name in mapping:
            nodes[node]["name"] = "mixamorig:" + mapping[vrm_name]
    # Sin pecho superior: Spine2 = chest (se usa el mismo hueso).
    if "upperChest" not in bones and "chest" in bones:
        pass  # pose.py tolera la columna con menos huesos.

    # Puntas de dedo: hijo "_end" si existe; si no, se crea un nodo.
    added = 0
    for s, S in SIDE.items():
        for f, F in list(FINGERS.items()) + [("Thumb", "Thumb")]:
            distal = bones.get(f"{s}{f}Distal")
            if distal is None:
                continue
            kids = nodes[distal].get("children", [])
            if kids:
                nodes[kids[0]]["name"] = f"mixamorig:{S}Hand{F}4"
                continue
            t = nodes[distal].get("translation", [0, 0.02, 0])
            nodes.append({"name": f"mixamorig:{S}Hand{F}4",
                          "translation": [c * 0.8 for c in t]})
            nodes[distal].setdefault("children", []).append(len(nodes) - 1)
            added += 1

    # VRM 0.x mira a -Z: un nodo raíz girado 180° lo pone de frente.
    scene = j["scenes"][j.get("scene", 0)]
    if not vrm1:
        nodes.append({"name": "Profesor", "children": scene["nodes"],
                      "rotation": [0, 1, 0, 0]})
    else:
        nodes.append({"name": "Profesor", "children": scene["nodes"]})
    scene["nodes"] = [len(nodes) - 1]
    # Restricciones de VRM 1.0 (mangas, giros de antebrazo): se guardan para
    # que generate.py las aplique en cada cuadro.
    constraints = []
    for i, n in enumerate(nodes):
        c = n.get("extensions", {}).get("VRMC_node_constraint")
        if not c:
            continue
        kind, d = next(iter(c["constraint"].items()))
        constraints.append({"node": i, "kind": kind, "source": d["source"],
                            "axis": d.get("rollAxis") or d.get("aimAxis"),
                            "weight": d.get("weight", 1.0)})
    nodes[-1]["extras"] = {"expressions": expressions,
                           "source": os.path.basename(src),
                           "constraints": constraints}

    # Fuera las extensiones de VRM (el visor no las usa).
    vrm_ext = ("VRM", "VRMC_vrm", "VRMC_springBone", "VRMC_node_constraint",
               "VRMC_materials_mtoon", "VRMC_springBone_extended_collider")
    j.get("extensions", {}).clear()
    for m in j.get("materials", []):
        for e in list(m.get("extensions", {})):
            if e in vrm_ext:
                del m["extensions"][e]
        if not m.get("extensions"):
            m.pop("extensions", None)
    for n in nodes:
        for e in list(n.get("extensions", {})):
            if e in vrm_ext:
                del n["extensions"][e]
        if not n.get("extensions"):
            n.pop("extensions", None)
    for key in ("extensionsUsed", "extensionsRequired"):
        if key in j:
            j[key] = [e for e in j[key] if e not in vrm_ext]
            if not j[key]:
                del j[key]
    j.pop("extensions", None)

    js = json.dumps(j, separators=(",", ":")).encode("utf-8")
    js += b" " * ((4 - len(js) % 4) % 4)
    bn = bytes(g.bin) + b"\x00" * ((4 - len(g.bin) % 4) % 4)
    with open(dst, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(js) + 8 + len(bn)))
        f.write(struct.pack("<I4s", len(js), b"JSON"))
        f.write(js)
        f.write(struct.pack("<I4s", len(bn), b"BIN\x00"))
        f.write(bn)
    print(f"VRM {'1.0' if vrm1 else '0.x'}: {len(bones)} huesos, "
          f"{added} puntas agregadas, sin {missing or 'faltantes'}; "
          f"{len(constraints)} restricciones; "
          f"expresiones: {', '.join(expressions)} -> {dst}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
