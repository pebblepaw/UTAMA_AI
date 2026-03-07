"""
Diagnostic: Compare Sultan vs Lion USD export structure.
Check if mesh has proper armature modifier and why SkelRoot is missing.
"""
import bpy
import os
import sys

BASE_LION = '/Users/pebblepaw/Documents/CODING_PROJECTS/UTAMA_AI/LIONASSETS'
LION_DIR = os.path.join(BASE_LION, 'uploads_files_6678807_Lion@Bite')
BASE_FBX = os.path.join(LION_DIR, 'SK_Lion.FBX')
ANIM_FBX = os.path.join(LION_DIR, 'Lion@Roar.FBX')
OUT = os.path.join(BASE_LION, 'usdz_output')

SULTAN_BASE = '/Users/pebblepaw/Documents/CODING_PROJECTS/UTAMA_AI/SULTANASSETS'
SULTAN_FBX = os.path.join(SULTAN_BASE, 'Sultan_Idle.fbx')


def check_scene(label):
    """Print complete scene info for debugging."""
    print(f'\n===== {label} =====')
    for obj in bpy.data.objects:
        print(f'  Object: {obj.name} | type={obj.type} | parent={obj.parent.name if obj.parent else None} | parent_type={obj.parent_type}')
        if obj.type == 'MESH':
            print(f'    Vertex Groups: {len(obj.vertex_groups)}')
            print(f'    Modifiers: {[(m.name, m.type) for m in obj.modifiers]}')
            for m in obj.modifiers:
                if m.type == 'ARMATURE':
                    print(f'    Armature modifier object: {m.object.name if m.object else "NONE"}')
            if obj.parent and obj.parent.type == 'ARMATURE':
                print(f'    Parent bone: {obj.parent_bone}')
        if obj.type == 'ARMATURE':
            print(f'    Bones: {len(obj.data.bones)}')
            if obj.animation_data:
                print(f'    Action: {obj.animation_data.action.name if obj.animation_data.action else "NONE"}')
                print(f'    Slot handle: {obj.animation_data.action_slot_handle}')
            else:
                print(f'    No animation_data')


# ===== TEST 1: Sultan (known working) =====
print('\n' + '='*80)
print('TEST 1: Sultan - direct FBX import (known working)')
print('='*80)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=SULTAN_FBX, use_anim=True, ignore_leaf_bones=False, automatic_bone_orientation=False)
check_scene('Sultan after import')

# Export as USDA
sultan_usda = os.path.join(OUT, 'TEST_sultan.usda')
bpy.ops.wm.usd_export(filepath=sultan_usda, selected_objects_only=False, export_animation=True, generate_preview_surface=True)
print(f'\nSultan USDA exported: {os.path.getsize(sultan_usda)} bytes')


# ===== TEST 2: Lion base only (no animation) =====
print('\n' + '='*80)
print('TEST 2: Lion base only (no animation)')
print('='*80)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=BASE_FBX, use_anim=False, ignore_leaf_bones=False, automatic_bone_orientation=False)

# Keep only highest LOD mesh
mesh_objects = [o for o in bpy.data.objects if o.type == 'MESH']
mesh_objects.sort(key=lambda o: len(o.data.vertices), reverse=True)
for m in mesh_objects[1:]:
    bpy.data.objects.remove(m, do_unlink=True)

check_scene('Lion base import (use_anim=False)')

lion_base_usda = os.path.join(OUT, 'TEST_lion_base.usda')
bpy.ops.wm.usd_export(filepath=lion_base_usda, selected_objects_only=False, export_animation=False, generate_preview_surface=True)
print(f'\nLion base USDA exported: {os.path.getsize(lion_base_usda)} bytes')


# ===== TEST 3: Lion base + anim transfer (current approach) =====
print('\n' + '='*80)
print('TEST 3: Lion base + animation transfer')
print('='*80)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=BASE_FBX, use_anim=False, ignore_leaf_bones=False, automatic_bone_orientation=False)

mesh_objects = [o for o in bpy.data.objects if o.type == 'MESH']
mesh_objects.sort(key=lambda o: len(o.data.vertices), reverse=True)
for m in mesh_objects[1:]:
    bpy.data.objects.remove(m, do_unlink=True)

base_arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]

bpy.ops.import_scene.fbx(filepath=ANIM_FBX, use_anim=True, ignore_leaf_bones=False, automatic_bone_orientation=False)

anim_arm = None
for obj in bpy.data.objects:
    if obj.type == 'ARMATURE' and obj != base_arm:
        anim_arm = obj
        break

anim_action = anim_arm.animation_data.action
print(f'  Anim action: {anim_action.name}')

# Transfer action
cb_slot_handle = None
for layer in anim_action.layers:
    for strip in layer.strips:
        for cb in strip.channelbags:
            cb_slot_handle = cb.slot_handle
            break

if not base_arm.animation_data:
    base_arm.animation_data_create()
base_arm.animation_data.action = anim_action
if cb_slot_handle:
    base_arm.animation_data.action_slot_handle = cb_slot_handle

bpy.data.objects.remove(anim_arm, do_unlink=True)

check_scene('Lion after transfer + delete anim arm')

lion_transfer_usda = os.path.join(OUT, 'TEST_lion_transfer2.usda')
bpy.ops.wm.usd_export(filepath=lion_transfer_usda, selected_objects_only=False, export_animation=True, generate_preview_surface=True)
print(f'\nLion transfer USDA exported: {os.path.getsize(lion_transfer_usda)} bytes')


# ===== TEST 4: Lion anim FBX directly (with animation, mesh will warp but let's check structure) =====
print('\n' + '='*80)
print('TEST 4: Lion anim FBX directly (to check SkelRoot)')
print('='*80)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=ANIM_FBX, use_anim=True, ignore_leaf_bones=False, automatic_bone_orientation=False)
check_scene('Lion anim FBX direct import')

lion_direct_usda = os.path.join(OUT, 'TEST_lion_direct.usda')
bpy.ops.wm.usd_export(filepath=lion_direct_usda, selected_objects_only=False, export_animation=True, generate_preview_surface=True)
print(f'\nLion direct USDA exported: {os.path.getsize(lion_direct_usda)} bytes')


# ===== Summary: grep for SkelRoot in all exports =====
print('\n' + '='*80)
print('SUMMARY: Checking for SkelRoot in each USDA')
print('='*80)

import subprocess
for label, path in [
    ('Sultan', sultan_usda),
    ('Lion base', lion_base_usda),
    ('Lion transfer', lion_transfer_usda),
    ('Lion direct', lion_direct_usda),
]:
    result = subprocess.run(['grep', '-c', 'SkelRoot', path], capture_output=True, text=True)
    count = result.stdout.strip()
    result2 = subprocess.run(['grep', '-c', 'skel:skeleton', path], capture_output=True, text=True)
    count2 = result2.stdout.strip()
    result3 = subprocess.run(['grep', '-c', 'SkelAnimation', path], capture_output=True, text=True)
    count3 = result3.stdout.strip()
    print(f'  {label:20s}: SkelRoot={count}, skel:skeleton={count2}, SkelAnimation={count3}')
