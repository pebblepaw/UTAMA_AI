"""
Quick test: Add Armature modifier to Lion mesh and check if SkelRoot appears in export.
"""
import bpy
import os
import subprocess

BASE_LION = '/Users/pebblepaw/Documents/CODING_PROJECTS/UTAMA_AI/LIONASSETS'
LION_DIR = os.path.join(BASE_LION, 'uploads_files_6678807_Lion@Bite')
BASE_FBX = os.path.join(LION_DIR, 'SK_Lion.FBX')
ANIM_FBX = os.path.join(LION_DIR, 'Lion@Roar.FBX')
OUT = os.path.join(BASE_LION, 'usdz_output')

# Clean scene
bpy.ops.wm.read_factory_settings(use_empty=True)

# Import base
bpy.ops.import_scene.fbx(filepath=BASE_FBX, use_anim=False, ignore_leaf_bones=False, automatic_bone_orientation=False)

# Keep only LOD0
mesh_objects = [o for o in bpy.data.objects if o.type == 'MESH']
mesh_objects.sort(key=lambda o: len(o.data.vertices), reverse=True)
keep_mesh = mesh_objects[0]
for m in mesh_objects[1:]:
    bpy.data.objects.remove(m, do_unlink=True)

base_arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]

# Import animation
bpy.ops.import_scene.fbx(filepath=ANIM_FBX, use_anim=True, ignore_leaf_bones=False, automatic_bone_orientation=False)

anim_arm = None
for obj in bpy.data.objects:
    if obj.type == 'ARMATURE' and obj != base_arm:
        anim_arm = obj
        break

anim_action = anim_arm.animation_data.action

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

# ===== THE FIX: Add Armature modifier to mesh =====
print('\n=== APPLYING FIX: Adding Armature modifier ===')
for obj in bpy.data.objects:
    if obj.type == 'MESH':
        # Check if it already has an Armature modifier
        has_arm_mod = any(m.type == 'ARMATURE' for m in obj.modifiers)
        if not has_arm_mod:
            arm_mod = obj.modifiers.new(name='Armature', type='ARMATURE')
            arm_mod.object = base_arm
            print(f'  Added Armature modifier to {obj.name} → {base_arm.name}')
        else:
            print(f'  {obj.name} already has Armature modifier')
        
        # Verify
        print(f'  Modifiers now: {[(m.name, m.type, m.object.name if hasattr(m, "object") and m.object else "N/A") for m in obj.modifiers]}')
        print(f'  Vertex Groups: {len(obj.vertex_groups)}')
        print(f'  Parent: {obj.parent.name if obj.parent else None} (type={obj.parent_type})')

# Set frame range
frame_start = float('inf')
frame_end = float('-inf')
for layer in anim_action.layers:
    for strip in layer.strips:
        for cb in strip.channelbags:
            for fc in cb.fcurves:
                for kf in fc.keyframe_points:
                    frame_start = min(frame_start, kf.co[0])
                    frame_end = max(frame_end, kf.co[0])
bpy.context.scene.frame_start = int(frame_start)
bpy.context.scene.frame_end = int(frame_end)

# Export USDA to check structure
out_usda = os.path.join(OUT, 'TEST_fix_skelroot.usda')
bpy.ops.wm.usd_export(filepath=out_usda, selected_objects_only=False, export_animation=True, generate_preview_surface=True)
print(f'\nExported: {os.path.getsize(out_usda)} bytes')

# Check for SkelRoot etc.
for pattern in ['SkelRoot', 'skel:skeleton', 'SkelAnimation', 'skel:animationSource']:
    result = subprocess.run(['grep', '-c', pattern, out_usda], capture_output=True, text=True)
    print(f'  {pattern}: {result.stdout.strip()}')

# Also export USDZ to test
out_usdz = os.path.join(OUT, 'TEST_fix_skelroot.usdz')
bpy.ops.wm.usd_export(
    filepath=out_usdz,
    selected_objects_only=False,
    export_animation=True,
    generate_preview_surface=True,
    export_materials=True,
    export_textures_mode='NEW',
    overwrite_textures=True,
)
print(f'USDZ: {os.path.getsize(out_usdz) / (1024*1024):.1f} MB')
print('\nDone! Open TEST_fix_skelroot.usdz in Finder to test animation.')
