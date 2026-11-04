"""Reescribe un GLB reemplazando sus animaciones.

Conserva mallas, pieles, materiales e imágenes; descarta los datos de las
animaciones viejas (el binario queda compacto) y agrega las nuevas.
"""
import json
import struct


def _pad4(b, fill=b"\x00"):
    return b + fill * ((4 - len(b) % 4) % 4)


def write(glb, clips, out_path):
    """clips: lista de (nombre, tiempos, {índice_nodo: [cuaterniones]})."""
    j = json.loads(json.dumps(glb.json))
    old_acc, old_bv = j["accessors"], j["bufferViews"]

    # Accesores que siguen en uso (todo menos las animaciones).
    used = set()
    for m in j.get("meshes", []):
        for p in m["primitives"]:
            used.update(p["attributes"].values())
            if "indices" in p:
                used.add(p["indices"])
            for t in p.get("targets", []):
                used.update(t.values())
    for s in j.get("skins", []):
        if "inverseBindMatrices" in s:
            used.add(s["inverseBindMatrices"])
    used_bv = {old_acc[a]["bufferView"] for a in used
               if "bufferView" in old_acc[a]}
    # Los accesores dispersos (morph targets) guardan índices y valores en
    # bufferViews propios.
    for a in used:
        sp = old_acc[a].get("sparse")
        if sp:
            used_bv.add(sp["indices"]["bufferView"])
            used_bv.add(sp["values"]["bufferView"])
    for img in j.get("images", []):
        if "bufferView" in img:
            used_bv.add(img["bufferView"])

    # Copia compacta de los bufferViews en uso.
    new_bin = bytearray()
    bv_map, new_bvs = {}, []
    for i in sorted(used_bv):
        bv = old_bv[i]
        start = bv.get("byteOffset", 0)
        chunk = glb.bin[start:start + bv["byteLength"]]
        while len(new_bin) % 4:
            new_bin.append(0)
        nb = dict(bv)
        nb["byteOffset"] = len(new_bin)
        nb["buffer"] = 0
        new_bin += chunk
        bv_map[i] = len(new_bvs)
        new_bvs.append(nb)
    acc_map, new_accs = {}, []
    for i in sorted(used):
        a = json.loads(json.dumps(old_acc[i]))
        if "bufferView" in a:
            a["bufferView"] = bv_map[a["bufferView"]]
        if "sparse" in a:
            a["sparse"]["indices"]["bufferView"] = bv_map[
                a["sparse"]["indices"]["bufferView"]]
            a["sparse"]["values"]["bufferView"] = bv_map[
                a["sparse"]["values"]["bufferView"]]
        acc_map[i] = len(new_accs)
        new_accs.append(a)
    for m in j.get("meshes", []):
        for p in m["primitives"]:
            p["attributes"] = {k: acc_map[v] for k, v in p["attributes"].items()}
            if "indices" in p:
                p["indices"] = acc_map[p["indices"]]
            if "targets" in p:
                p["targets"] = [{k: acc_map[v] for k, v in t.items()}
                                for t in p["targets"]]
    for s in j.get("skins", []):
        if "inverseBindMatrices" in s:
            s["inverseBindMatrices"] = acc_map[s["inverseBindMatrices"]]
    for img in j.get("images", []):
        if "bufferView" in img:
            img["bufferView"] = bv_map[img["bufferView"]]

    # Animaciones nuevas en un único bufferView.
    anim_start = len(new_bin)
    while anim_start % 4:
        new_bin.append(0)
        anim_start += 1
    anim_bytes = bytearray()
    animations = []

    def add_acc(values, typ, with_minmax=False):
        off = len(anim_bytes)
        flat = [c for v in values for c in (v if isinstance(v, tuple) else (v,))]
        anim_bytes.extend(struct.pack("<%df" % len(flat), *flat))
        acc = {"bufferView": len(new_bvs), "byteOffset": off,
               "componentType": 5126, "count": len(values), "type": typ}
        if with_minmax:
            acc["min"] = [min(values)]
            acc["max"] = [max(values)]
        new_accs.append(acc)
        return len(new_accs) - 1

    for name, times, tracks in clips:
        t_full = add_acc(times, "SCALAR", True)
        t_one = add_acc([0.0], "SCALAR", True)
        samplers, channels = [], []
        for node, quats in sorted(tracks.items()):
            constant = all(max(abs(x - y) for x, y in zip(q, quats[0])) < 1e-5
                           for q in quats)
            vals = [tuple(quats[0])] if constant else [tuple(q) for q in quats]
            out = add_acc(vals, "VEC4")
            samplers.append({"input": t_one if constant else t_full,
                             "output": out, "interpolation": "LINEAR"})
            channels.append({"sampler": len(samplers) - 1,
                             "target": {"node": node, "path": "rotation"}})
        animations.append({"name": name, "samplers": samplers,
                           "channels": channels})

    new_bvs.append({"buffer": 0, "byteOffset": anim_start,
                    "byteLength": len(anim_bytes)})
    new_bin += anim_bytes
    j["bufferViews"] = new_bvs
    j["accessors"] = new_accs
    j["animations"] = animations
    j["buffers"] = [{"byteLength": len(new_bin)}]

    js = _pad4(json.dumps(j, separators=(",", ":")).encode("utf-8"), b" ")
    bn = _pad4(bytes(new_bin))
    total = 12 + 8 + len(js) + 8 + len(bn)
    with open(out_path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, total))
        f.write(struct.pack("<I4s", len(js), b"JSON"))
        f.write(js)
        f.write(struct.pack("<I4s", len(bn), b"BIN\x00"))
        f.write(bn)
    return total
