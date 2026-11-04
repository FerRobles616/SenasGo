"""Renderiza el póster de respaldo del profesor con encuadre de torso.

Uso:
    blender --background --python tool/render_teacher_poster.py

El PNG se usa mientras carga el GLB o si el visor 3D no está disponible.
Se genera desde el mismo `teacher.glb` para que la ropa azul y la pose
coincidan con el modelo real.
"""

import math
import os

import bpy
from mathutils import Vector

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GLB = os.path.join(PROJECT, 'assets', 'models', 'teacher.glb')
OUT = os.path.join(PROJECT, 'assets', 'images', 'teacher_poster.png')

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)

scene = bpy.context.scene
# Eevee usa los materiales y texturas del GLB. Workbench solo pinta colores
# de viewport y producía un póster blanco sin texturas.
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = 720
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.view_settings.view_transform = 'Standard'

# Pose de saludo con la mano cerca de la frente: se lee como una bienvenida
# y muestra la mano que firma, sin depender de un fotograma de reposo.
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
action = bpy.data.actions.get('saludo_hola_lugar')
if action:
    arm.animation_data_create()
    arm.animation_data.action = action
    scene.frame_set(int(action.frame_range[1]))
    bpy.context.view_layer.update()

# Fondo transparente + luces suaves de estudio.
world = bpy.data.worlds.new('PosterWorld')
world.use_nodes = True
world.node_tree.nodes['Background'].inputs['Color'].default_value = (
    0.015, 0.035, 0.09, 1.0)
world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.35
scene.world = world

def area(name, location, energy, size, color):
    light = bpy.data.lights.new(name, 'AREA')
    light.energy = energy
    light.shape = 'DISK'
    light.size = size
    light.color = color
    obj = bpy.data.objects.new(name, light)
    obj.location = location
    direction = Vector((0, 0, 1.55)) - obj.location
    obj.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
    bpy.context.collection.objects.link(obj)

area('Key', (1.9, -3.0, 3.0), 260, 3.0, (0.78, 0.88, 1.0))
area('Fill', (-2.2, -1.8, 2.1), 140, 3.5, (0.55, 0.72, 1.0))
area('Rim', (0.0, 2.4, 3.2), 300, 2.4, (0.45, 0.7, 1.0))

camera_data = bpy.data.cameras.new('PosterCamera')
camera = bpy.data.objects.new('PosterCamera', camera_data)
bpy.context.collection.objects.link(camera)
camera.location = (0.0, -3.15, 1.55)
target = Vector((0.0, 0.0, 1.55))
camera.rotation_euler = (target - camera.location).to_track_quat(
    '-Z', 'Y').to_euler()
camera_data.lens = 58
camera_data.sensor_width = 36
camera_data.sensor_fit = 'VERTICAL'
scene.camera = camera

# Un poco de contraluz en la silueta; el póster se recorta con alpha.
scene.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print('POSTER', OUT, os.path.getsize(OUT))
