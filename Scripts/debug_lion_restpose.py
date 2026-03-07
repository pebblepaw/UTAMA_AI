"""
Diagnose Lion armature rest pose mismatch between base and animation FBX.
Compare bone head/tail positions, rest matrices, etc.
"""
import bpy
import os
from mathutils import Matrix, Vector

BASE_FBX = '/Users/pebblepaw/Documents/CODING_PROJECTS/UTAMA_AI/LIONASSETS/uploads_files_6678807_Lion@Bite/SK_Lion.FBX'
ANIM_FBX = '/Users/pebblepaw/Documents/CODING_PROJECTS/UTAMA_AI/LIONASSETS/uploads_files_6678807_Lion@Bite/Lion@Roar.FBX'

bpy.ops.wm.read_factory_settings(use_empty=True)

# Import base
bpy.ops.import_scene.fbx(filepath=BASE_FBX, use_anim=False, ignore_leaf_bones=False, automatic_bone_orientation=False)
base_arm = None
for obj in bpy.data.objects:
    if obj.type == 'ARMATURE':
        base_arm = obj
        break

print(f'=== BASE ARMATURE: {base_arm.name} ===')
print(f'Location: {base_arm.location}')
print(f'Rotation: {base_arm.rotation_euler}')
print(f'Scale: {base_arm.scale}')
print(f'Matrix world:\n{base_arm.matrix_world}')

base_bone_data = {}
for bone in base_arm.data.bones:
    base_bone_data[bone.name] = {
        'head': bone.head_local.copy(),
        'tail': bone.tail_local.copy(),
        'matrix': bone.matrix_local.copy(),
    }

# Print first few bones
print('\nBase bones (first 10):')
for i, (name, data) in enumerate(base_bone_data.items()):
    if i >= 10:
        break
    print(f'  {name}: head={data["head"]}, tail={data["tail"]}')

# Import animation
bpy.ops.import_scene.fbx(filepath=ANIM_FBX, use_anim=True, ignore_leaf_bones=False, automatic_bone_orientation=False)
anim_arm = None
for obj in bpy.data.objects:
    if obj.type == 'ARMATURE' and obj != base_arm:
        anim_arm = obj
        break

print(f'\n=== ANIM ARMATURE: {anim_arm.name} ===')
print(f'Location: {anim_arm.location}')
print(f'Rotation: {anim_arm.rotation_euler}')
print(f'Scale: {anim_arm.scale}')
print(f'Matrix world:\n{anim_arm.matrix_world}')

anim_bone_data = {}
for bone in anim_arm.data.bones:
    anim_bone_data[bone.name] = {
        'head': bone.head_local.copy(),
        'tail': bone.tail_local.copy(),
        'matrix': bone.matrix_local.copy(),
    }

print('\nAnim bones (first 10):')
for i, (name, data) in enumerate(anim_bone_data.items()):
    if i >= 10:
        break
    print(f'  {name}: head={data["head"]}, tail={data["tail"]}')

# Compare
print('\n=== COMPARISON ===')
mismatches = 0
for name in base_bone_data:
    if name not in anim_bone_data:
        print(f'  MISSING in anim: {name}')
        continue
    b = base_bone_data[name]
    a = anim_bone_data[name]
    head_diff = (b['head'] - a['head']).length
    tail_diff = (b['tail'] - a['tail']).length
    if head_diff > 0.001 or tail_diff > 0.001:
        mismatches += 1
        print(f'  MISMATCH {name}: head_diff={head_diff:.6f}, tail_diff={tail_diff:.6f}')
        print(f'    base head={b["head"]}, anim head={a["head"]}')

print(f'\nTotal mismatches: {mismatches} / {len(base_bone_data)}')

# Also check mesh parenting in base
print('\n=== MESH PARENT INFO ===')
for obj in bpy.data.objects:
    if obj.type == 'MESH':
        print(f'{obj.name}: parent={obj.parent.name if obj.parent else None}, loc={obj.location}, scale={obj.scale}')
        for mod in obj.modifiers:
            if mod.type == 'ARMATURE':
                print(f'  Armature mod: {mod.object.name if mod.object else None}')
