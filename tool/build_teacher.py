"""Genera el profesor 3D de SeñasGo a partir de modelo-Jaguarete.glb.

Uso:
    blender --background --python tool/build_teacher.py

El GLB resultante incluye:
- una seña completa por cada seña del vocabulario (termina sosteniendo la pose);
- clips `_forma`, `_lugar` y `_movimiento` para la demostración paso a paso;
- `idle` para el reposo.

Los clips de paso son los que usa `GuidedTeacher`. Si se agrega una seña hay
que agregar sus clips acá y su especificación en
`lib/features/avatar/domain/teacher_step.dart`.
"""

import bpy
import math
import os
import sys
from mathutils import Euler, Matrix, Quaternion, Vector

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.environ.get(
    'JAGUAR_GLB',
    '/home/fernandojrl/Documentos/proyectos/modelo-Jaguarete.glb',
)
OUT = os.environ.get(
    'TEACHER_GLB',
    os.path.join(PROJECT, 'assets', 'models', 'teacher.glb'),
)
FPS = 30

# ---------------------------------------------------------------- import
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
arm.name = 'JaguarTeacher'
arm.data.name = 'JaguarTeacherRig'

if arm.animation_data:
    arm.animation_data.action = None
    for track in list(arm.animation_data.nla_tracks):
        arm.animation_data.nla_tracks.remove(track)
for action in list(bpy.data.actions):
    bpy.data.actions.remove(action)

# ---------------------------------------------------------------- look
# Teacher look: keep the chest plate, hip/leg armour and long purple robe;
# remove combat pieces that hide the hands and make the silhouette bulky.
HIDE = [
    'Shield', 'Wrists', 'Wrists_Leather', 'Icosphere', 'Shirt',
    'Shoulders', 'Biceps',
]
for name in HIDE:
    obj = bpy.data.objects.get(name)
    if obj:
        bpy.data.objects.remove(obj, do_unlink=True)

# Paleta azul de SeñasGo: túnica azul, placas celestes y cuero marino.
# Mantener el modelo dentro de la identidad visual evita que el profesor
# parezca pertenecer a otra app cuando aparece junto a la interfaz.
for mat in bpy.data.materials:
    if not mat.use_nodes:
        continue
    bsdf = next((n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    if not bsdf:
        continue
    if 'Red_Cloth' in mat.name:
        bsdf.inputs['Base Color'].default_value = (0.035, 0.16, 0.48, 1.0)
        bsdf.inputs['Metallic'].default_value = 0.0
        bsdf.inputs['Roughness'].default_value = 0.88
    elif mat.name == 'M_Metal':
        bsdf.inputs['Base Color'].default_value = (0.43, 0.62, 0.82, 1.0)
        bsdf.inputs['Metallic'].default_value = 0.45
        bsdf.inputs['Roughness'].default_value = 0.38
    elif mat.name in ('M_Leather', 'M_Dark_Leather', 'M_Leather.001'):
        bsdf.inputs['Base Color'].default_value = (0.035, 0.09, 0.18, 1.0)
        bsdf.inputs['Metallic'].default_value = 0.0
        bsdf.inputs['Roughness'].default_value = 0.75

# ---------------------------------------------------------------- helpers
SIDES = ('Right', 'Left')
FINGERS = ('Index', 'Middle', 'Ring', 'Pinky')

SHAPES = {
    # curl per finger segment; thumb rotations are (X, Y, Z) on Thumb1..3.
    # El pulgar se pliega sobre la palma con X negativo; Z solo lo gira.
    'relaxed': dict(curl=(12, 16, 20, 24), thumb=(0, 0, 0)),
    'open': dict(curl=(0, 0, 0, 0), thumb=(0, 0, 0)),
    'flat': dict(curl=(0, 0, 0, 0), thumb=(-15, 0, 0)),
    'fist': dict(curl=(72, 74, 74, 30), thumb=(-80, 0, 0)),
    'index': dict(curl=(0, 74, 74, 30), thumb=(-55, 0, 0)),
    'v': dict(curl=(0, 0, 74, 30), thumb=(-55, 0, 0)),
    'three': dict(curl=(0, 0, 0, 30), thumb=(-50, 0, 0)),
    'pinch': dict(curl=(38, 74, 74, 30), thumb=(-60, 0, 0)),
}

# All bones we keyframe. The arms are solved analytically; fingers and body
# are keyed directly.
# Importante: los dedos también llevan el prefijo `mixamorig:`. Si se omite,
# `set_hand_shape` los mueve en la pose actual pero `key_pose` no encuentra los
# huesos y el GLB termina exportando todas las manos abiertas.
ANIMATED = [
    'mixamorig:Hips', 'mixamorig:Spine', 'mixamorig:Spine1',
    'mixamorig:Spine2', 'mixamorig:Neck', 'mixamorig:Head',
    'mixamorig:RightArm', 'mixamorig:RightForeArm', 'mixamorig:RightHand',
    'mixamorig:LeftArm', 'mixamorig:LeftForeArm', 'mixamorig:LeftHand',
]
for side in SIDES:
    for finger in FINGERS:
        for seg in (1, 2, 3, 4):
            ANIMATED.append(f'mixamorig:{side}Hand{finger}{seg}')
    for seg in (1, 2, 3, 4):
        ANIMATED.append(f'mixamorig:{side}HandThumb{seg}')


def reset_pose():
    for pb in arm.pose.bones:
        pb.rotation_mode = 'QUATERNION'
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
        pb.scale = (1, 1, 1)


def set_body(body):
    """Apply torso/head/hips pose. Angles are degrees in bone-local space."""
    lean = math.radians(body.get('lean', 0.0))
    twist = math.radians(body.get('twist', 0.0))
    side = math.radians(body.get('side', 0.0))
    for name, factor in (
        ('mixamorig:Spine', 0.30),
        ('mixamorig:Spine1', 0.35),
        ('mixamorig:Spine2', 0.35),
    ):
        pb = arm.pose.bones[name]
        pb.rotation_mode = 'QUATERNION'
        pb.rotation_quaternion = Euler(
            (lean * factor, twist * factor, side * factor), 'XYZ').to_quaternion()
    neck = arm.pose.bones['mixamorig:Neck']
    neck.rotation_mode = 'QUATERNION'
    neck.rotation_quaternion = Euler((
        math.radians(body.get('headPitch', 0.0)) * 0.35,
        math.radians(body.get('headYaw', 0.0)) * 0.35,
        math.radians(body.get('headRoll', 0.0)) * 0.35,
    ), 'XYZ').to_quaternion()
    head = arm.pose.bones['mixamorig:Head']
    head.rotation_mode = 'QUATERNION'
    head.rotation_quaternion = Euler((
        math.radians(body.get('headPitch', 0.0)) * 0.65,
        math.radians(body.get('headYaw', 0.0)) * 0.65,
        math.radians(body.get('headRoll', 0.0)) * 0.65,
    ), 'XYZ').to_quaternion()
    hips = arm.pose.bones['mixamorig:Hips']
    hips.location = (0, body.get('hipsY', 0.0), 0)


def two_bone_ik(side, wrist, pole, fingers, palm, roll=0.0):
    """Analytic two-bone IK in armature space, written as FK quaternions."""
    upper = arm.pose.bones[f'mixamorig:{side}Arm']
    lower = arm.pose.bones[f'mixamorig:{side}ForeArm']
    hand = arm.pose.bones[f'mixamorig:{side}Hand']
    for b in (upper, lower, hand):
        b.rotation_mode = 'QUATERNION'

    S = upper.head.copy()
    W = Vector(wrist)
    L1, L2 = upper.length, lower.length
    d = W - S
    dist = d.length
    if dist < 1e-5:
        d = Vector((0, 0, 1))
        dist = 1e-5
    d.normalize()
    dist = min(max(dist, abs(L1 - L2) + 1e-4), L1 + L2 - 1e-4)

    cos_a = max(-1.0, min(1.0, (L1 * L1 + dist * dist - L2 * L2) / (2 * L1 * dist)))
    a = math.acos(cos_a)
    p = Vector(pole) - S
    p = p - d * p.dot(d)
    if p.length < 1e-5:
        p = Vector((0, 0, 1)) - d * d.z
    p.normalize()
    E = S + d * (L1 * cos_a) + p * (L1 * math.sin(a))
    n = d.cross(p).normalized()

    def matrix(head, y, z):
        y = y.normalized()
        z = z.normalized()
        x = y.cross(z).normalized()
        z = x.cross(y).normalized()
        m = Matrix((x, y, z)).transposed().to_4x4()
        m.translation = head
        return m

    upper.matrix = matrix(S, E - S, n)
    bpy.context.view_layer.update()
    lower.matrix = matrix(E, W - E, n)
    bpy.context.view_layer.update()

    fdir = Vector(fingers).normalized()
    pdir = Vector(palm).normalized()
    if abs(roll) > 1e-6:
        pdir = Quaternion(fdir, math.radians(roll)) @ pdir
    hand.matrix = matrix(W, fdir, pdir)
    bpy.context.view_layer.update()


def set_hand_shape(side, shape_name):
    shape = SHAPES[shape_name]
    curl = shape['curl']
    thumb = shape['thumb']
    # Mirror thumb across the palm for the left hand.
    thumb_sign = 1 if side == 'Right' else -1
    # `key_pose` guarda rotation_quaternion. Hay que convertir el Euler a
    # quaternion; si se deja rotation_euler, el keyframe queda en identidad.
    for i, finger in enumerate(FINGERS):
        for seg in (1, 2, 3):
            bn = arm.pose.bones.get(f'mixamorig:{side}Hand{finger}{seg}')
            if bn:
                bn.rotation_mode = 'QUATERNION'
                bn.rotation_quaternion = Euler(
                    (math.radians(curl[i]), 0, 0), 'XYZ').to_quaternion()
        bn = arm.pose.bones.get(f'mixamorig:{side}Hand{finger}4')
        if bn:
            bn.rotation_mode = 'QUATERNION'
            bn.rotation_quaternion = Euler(
                (math.radians(curl[3] * 0.35), 0, 0), 'XYZ').to_quaternion()
    thumb_x, thumb_y, thumb_z = thumb
    for seg in (1, 2, 3):
        bn = arm.pose.bones.get(f'mixamorig:{side}HandThumb{seg}')
        if bn:
            bn.rotation_mode = 'QUATERNION'
            bn.rotation_quaternion = Euler((
                math.radians(thumb_x),
                math.radians(thumb_y),
                math.radians(thumb_z * thumb_sign),
            ), 'XYZ').to_quaternion()


def apply_pose(pose):
    reset_pose()
    set_body(pose.get('body', {}))
    bpy.context.view_layer.update()
    for side in SIDES:
        key = side.lower()
        hand = pose.get(key, {})
        two_bone_ik(
            side,
            hand.get('wrist', REST[side]['wrist']),
            hand.get('pole', REST[side]['pole']),
            hand.get('fingers', REST[side]['fingers']),
            hand.get('palm', REST[side]['palm']),
            hand.get('roll', 0.0),
        )
        set_hand_shape(side, hand.get('shape', 'relaxed'))
    bpy.context.view_layer.update()


def key_pose(frame):
    for name in ANIMATED:
        pb = arm.pose.bones.get(name)
        if not pb:
            continue
        pb.keyframe_insert('rotation_quaternion', frame=frame, group=name)
        if name == 'mixamorig:Hips':
            pb.keyframe_insert('location', frame=frame, group=name)


def smooth_action(action):
    for layer in action.layers:
        for strip in layer.strips:
            for slot in action.slots:
                bag = strip.channelbag(slot)
                if not bag:
                    continue
                for fcurve in bag.fcurves:
                    for kp in fcurve.keyframe_points:
                        kp.interpolation = 'BEZIER'
                        kp.handle_left_type = 'AUTO_CLAMPED'
                        kp.handle_right_type = 'AUTO_CLAMPED'


# ---------------------------------------------------------------- poses
REST = {
    'Right': dict(
        wrist=(-0.24, 0.73, 0.06),
        pole=(-0.80, 0.35, 0.0),
        fingers=(0, -1, 0),
        palm=(1, 0, 0),
        shape='relaxed',
    ),
    'Left': dict(
        wrist=(0.33, 0.72, 0.06),
        pole=(0.80, 0.35, 0.0),
        fingers=(0, -1, 0),
        palm=(-1, 0, 0),
        shape='relaxed',
    ),
}


def hand(wrist, shape='open', fingers=(0, 1, 0), palm=(0, 0, 1), roll=0.0, pole=None):
    return dict(
        wrist=wrist,
        pole=pole or (-0.80, 0.35, 0.0),
        fingers=fingers,
        palm=palm,
        shape=shape,
        roll=roll,
    )


def left_rest():
    return dict(REST['Left'])


def pose(body=None, right=None, left=None):
    return dict(
        body=body or {},
        right=right or dict(REST['Right']),
        left=left or left_rest(),
    )


SIGNS = {}

# HOLA: open hand at the forehead, then outward.
# Se agrega una pequeña pausa en la frente y un arco intermedio para que el
# movimiento no parezca un salto lineal. La mano sostiene la pose final.
SIGNS['saludo_hola'] = dict(
    duration=2.8,
    keys=[
        (0.00, pose()),
        (0.12, pose(
            body=dict(headPitch=-2),
            right=hand((-0.26, 0.95, 0.14), 'open'),
        )),
        (0.30, pose(
            body=dict(headPitch=-4),
            right=hand((-0.16, 0.99, 0.12), 'open'),
        )),
        (0.38, pose(
            body=dict(headPitch=-4, side=-1),
            right=hand((-0.17, 1.00, 0.12), 'open', roll=-4),
        )),
        (0.52, pose(
            body=dict(headPitch=-4, side=-2),
            right=hand((-0.24, 1.01, 0.15), 'open', roll=-8),
        )),
        (0.64, pose(
            body=dict(headPitch=-3, side=-2),
            right=hand((-0.30, 0.99, 0.18), 'open', roll=-12),
        )),
        (0.82, pose(
            body=dict(headPitch=-3, side=-2),
            right=hand((-0.30, 0.99, 0.18), 'open', roll=-12),
        )),
        (1.00, pose()),
    ],
)

# CHAU: open hand at shoulder height, waving side to side.
wave_keys = []
for i, (t, x, roll) in enumerate([
    (0.15, -0.30, 0), (0.30, -0.40, 14), (0.43, -0.24, -14),
    (0.56, -0.40, 14), (0.69, -0.24, -14), (0.82, -0.34, 8),
]):
    wave_keys.append((t, pose(
        body=dict(headRoll=3 if i % 2 else -2),
        right=hand((x, 1.10, 0.06), 'open', roll=roll),
    )))
SIGNS['saludo_chau'] = dict(
    duration=2.4,
    keys=[(0.0, pose())] + wave_keys + [(1.0, pose())],
)

# NUMBERS: static handshape in front of the chest.
for sign_id, shape in (
    ('numero_uno', 'index'),
    ('numero_dos', 'v'),
    ('numero_tres', 'three'),
):
    SIGNS[sign_id] = dict(
        duration=1.8,
        keys=[
            (0.00, pose()),
            (0.25, pose(
                body=dict(headPitch=2),
                right=hand((-0.20, 0.78, 0.20), shape),
            )),
            (0.76, pose(
                body=dict(headPitch=2),
                right=hand((-0.20, 0.78, 0.20), shape),
            )),
            (1.00, pose()),
        ],
    )

# GRACIAS: flat hand at the chin, then forward with the palm up.
# La pausa breve en el mentón marca el punto de contacto; el descenso final
# termina con la palma abierta y una inclinación de cabeza.
SIGNS['basico_gracias'] = dict(
    duration=2.4,
    keys=[
        (0.00, pose()),
        (0.24, pose(
            body=dict(headPitch=3),
            right=hand((-0.14, 1.03, 0.08), 'flat', palm=(0, 0, -1)),
        )),
        (0.34, pose(
            body=dict(headPitch=4),
            right=hand((-0.14, 1.03, 0.09), 'flat', palm=(0, 0, -1)),
        )),
        (0.62, pose(
            body=dict(headPitch=8, lean=3),
            right=hand((-0.20, 0.98, 0.22), 'flat',
                       fingers=(0, 0, 1), palm=(0, 1, 0)),
        )),
        (0.84, pose(
            body=dict(headPitch=5, lean=2),
            right=hand((-0.20, 0.98, 0.22), 'flat',
                       fingers=(0, 0, 1), palm=(0, 1, 0)),
        )),
        (1.00, pose()),
    ],
)

# SÍ: fist at the chest, nodding with the head.
si_keys = [(0.0, pose()), (0.20, pose(
    body=dict(headPitch=2),
    right=hand((-0.20, 0.90, 0.14), 'fist', palm=(1, 0, 0)),
))]
for i, (t, dy, pitch) in enumerate([
    (0.34, -0.05, 12), (0.45, 0.01, -3), (0.56, -0.05, 12),
    (0.67, 0.01, -3), (0.76, -0.03, 7),
]):
    si_keys.append((t, pose(
        body=dict(headPitch=pitch),
        right=hand((-0.20, 0.90 + dy, 0.14), 'fist', palm=(1, 0, 0)),
    )))
SIGNS['basico_si'] = dict(
    duration=2.2,
    keys=si_keys + [(1.0, pose())],
)

# NO: V hand closes and opens while the head shakes.
no_keys = [(0.0, pose()), (0.20, pose(
    body=dict(headPitch=1),
    right=hand((-0.20, 0.90, 0.16), 'v', palm=(1, 0, 0)),
))]
for i, (t, shape, yaw) in enumerate([
    (0.31, 'pinch', 13), (0.41, 'v', -13), (0.51, 'pinch', 13),
    (0.61, 'v', -13), (0.72, 'pinch', 8),
]):
    no_keys.append((t, pose(
        body=dict(headYaw=yaw),
        right=hand((-0.20, 0.90, 0.16), shape, palm=(1, 0, 0)),
    )))
SIGNS['basico_no'] = dict(
    duration=2.3,
    keys=no_keys + [(1.0, pose())],
)

# POR FAVOR: flat hand on the chest, small circle.
pf_keys = [(0.0, pose()), (0.16, pose(
    body=dict(headRoll=-4),
    right=hand((-0.13, 0.89, 0.12), 'flat', palm=(0, 0, -1)),
))]
for i in range(6):
    ang = math.radians(60 * i)
    x = -0.13 + 0.045 * math.cos(ang)
    y = 0.89 + 0.045 * math.sin(ang)
    pf_keys.append((0.24 + i * 0.09, pose(
        body=dict(headRoll=-5),
        right=hand((x, y, 0.12), 'flat', palm=(0, 0, -1)),
    )))
SIGNS['basico_por_favor'] = dict(
    duration=2.6,
    keys=pf_keys + [(1.0, pose())],
)

# IDLE: breathing loop, used while the teacher waits.
idle_keys = []
for i in range(5):
    t = i / 4
    breath = math.sin(t * 2 * math.pi)
    idle_keys.append((t, pose(
        body=dict(
            lean=0.8 * breath,
            headPitch=1.5 * breath,
            headRoll=0.6 * math.sin(t * 2 * math.pi + 0.8),
            hipsY=0.004 * breath,
        ),
        right=dict(REST['Right'], wrist=(
            REST['Right']['wrist'][0],
            REST['Right']['wrist'][1] + 0.006 * breath,
            REST['Right']['wrist'][2],
        )),
        left=dict(REST['Left'], wrist=(
            REST['Left']['wrist'][0],
            REST['Left']['wrist'][1] + 0.006 * breath,
            REST['Left']['wrist'][2],
        )),
    )))
SIGNS['idle'] = dict(duration=4.0, keys=idle_keys)

# ---------------------------------------------------------------- build
scene = bpy.context.scene
scene.render.fps = FPS
scene.render.fps_base = 1.0

# Índices dentro de SIGNS[id]['keys']:
# (último key de preparación, primer key del movimiento, último key del movimiento).
# Los números no tienen fase de movimiento: son una forma estática.
SPLITS = {
    'saludo_hola': (2, 2, 6),
    'saludo_chau': (1, 1, 6),
    'numero_uno': (2, None, None),
    'numero_dos': (2, None, None),
    'numero_tres': (2, None, None),
    'basico_gracias': (1, 1, 4),
    'basico_si': (1, 1, 6),
    'basico_no': (1, 1, 6),
    'basico_por_favor': (1, 1, 7),
}


def rebase(keys, end=0.85):
    """Reajusta los tiempos de un subconjunto de keys a 0..end y agrega hold."""
    t0 = keys[0][0]
    span = max(keys[-1][0] - t0, 1e-6)
    out = [((t - t0) / span * end, pose_) for t, pose_ in keys]
    if out[-1][0] < 1.0:
        out.append((1.0, out[-1][1]))
    return out


def build_action(name, keys, duration):
    reset_pose()
    action = bpy.data.actions.new(name)
    arm.animation_data_create()
    arm.animation_data.action = action
    last_frame = max(2, round(duration * FPS) + 1)
    for t, pose_ in keys:
        frame = 1 + round(t * (last_frame - 1))
        apply_pose(pose_)
        key_pose(frame)
    action.use_frame_range = True
    action.frame_start = 1
    action.frame_end = last_frame
    smooth_action(action)
    print(f'ACTION {name} frames=1..{last_frame} keys={len(keys)}')


for sign_id, spec in SIGNS.items():
    if sign_id == 'idle':
        build_action('idle', spec['keys'], spec['duration'])
        continue

    keys = spec['keys']
    # El último key de cada seña vuelve a la pose de reposo. Para enseñar,
    # la demostración debe terminar sosteniendo la pose final, no regresar.
    keys = keys[:-1]
    # Un poco más de tiempo que el original: las manos del jaguareté son
    # grandes y la seña se lee mejor con una cadencia pausada.
    duration = spec['duration'] * 1.18

    # Seña completa: preparación -> ubicación -> movimiento -> hold.
    build_action(sign_id, rebase(keys, 0.85), duration)

    forma_end, move_start, move_end = SPLITS[sign_id]
    target_pose = keys[forma_end][1]

    # Paso 1: llegar a la forma/ubicación inicial y sostener.
    forma_duration = 1.6 if move_start is None else 2.0
    build_action(f'{sign_id}_forma', rebase(keys[:forma_end + 1], 0.8),
                 forma_duration)

    # Paso 2: mirar la ubicación sin movimiento, para entender dónde va la mano.
    build_action(f'{sign_id}_lugar', [(0.0, target_pose), (1.0, target_pose)],
                 1.4)

    # Paso 3: ejecutar solo el movimiento, desde la pose inicial hasta el hold.
    if move_start is not None:
        cycle = sign_id in ('saludo_chau', 'basico_si', 'basico_no',
                            'basico_por_favor')
        build_action(f'{sign_id}_movimiento',
                     rebase(keys[move_start:move_end + 1], 0.85),
                     2.6 if cycle else 2.2)

# Leave the armature in the idle action for a sensible default.
arm.animation_data.action = bpy.data.actions.get('idle')
reset_pose()
scene.frame_set(1)
bpy.context.view_layer.update()

# ---------------------------------------------------------------- export
bpy.ops.export_scene.gltf(
    filepath=OUT,
    export_format='GLB',
    use_selection=False,
    export_yup=True,
    export_apply=False,
    export_animations=True,
    export_animation_mode='ACTIONS',
    export_nla_strips=False,
    export_anim_single_armature=True,
    export_optimize_animation_size=True,
    export_optimize_animation_keep_anim_armature=True,
    export_anim_slide_to_zero=True,
    export_image_format='AUTO',
    export_image_quality=82,
    export_cameras=False,
    export_lights=False,
    export_extras=False,
)
print('EXPORTED', OUT, os.path.getsize(OUT))
