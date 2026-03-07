"""
Deep diagnostic: Verify animation is working in Blender AND check USDZ export.
Tests multiple approaches to ensure animation data reaches the USDZ.
"""
import bpy
import os

BASE_FBX = '/Users/pebblepaw/Documents/CODING_PROJECTS/UTAMA_AI/LIONASSETS/uploads_files_6678807_Lion@Bite/SK_Lion.FBX'
ANIM_FBX = '/Users/pebblepaw/Documents/CODING_PROJECTS/UTAMA_AI/LIONASSETS/uploads_files_6678807_Lion@Bite/Lion@Roar.FBX'
OUT_DIR = '/Users/pebblepaw/Documents/CODING_PROJECTS/UTAMA_AI/LIONASSETS/usdz_output'

# ============================================================
# TEST 1: Does animation work in Blender with the transfer approach?
# ============================================================
print('\n' + '='*70)
print('TEST 1: Animation transfer to base armature - pose sampling')
print('='*70)

bpy.ops.wm.read_factory_settings(use_empty=True)

bpy.ops.import_scene.fbx(filepath=BASE_FBX, use_anim=False, ignore_leaf_bones=False, automatic_bone_orientation=False)
base_arm = None
for obj in bpy.data.objects:
    if obj.type == 'ARMATURE':
        base_arm = obj
        break

bpy.ops.import_scene.fbx(filepath=ANIM_FBX, use_anim=True, ignore_leaf_bones=False, automatic_bone_orientation=False)
anim_arm = None
for obj in bpy.data.objects:
    if obj.type == 'ARMATURE' and obj != base_arm:
        anim_arm = obj
        break

anim_action = anim_arm.animation_data.action
print(f'Action: {anim_action.name}')

cb_slot_handle = None
for layer in anim_action.layers:
    for strip in layer.strips:
        for cb in strip.channelbags:
            cb_slot_handle = cb.slot_handle

if not base_arm.animation_data:
    base_arm.animation_data_create()
base_arm.animation_data.action = anim_action
base_arm.animation_data.action_slot_handle = cb_slot_handle

bpy.data.objects.remove(anim_arm, do_unlink=True)

bpy.context.scene.frame_start = 1
bpy.context.scene.frame_end = 51

for frame in [1, 10, 25, 40, 51]:
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()
    head = base_arm.pose.bones.get('LION_ Head')
    jaw = base_arm.pose.bones.get('LION_ Jaw')
    root = base_arm.pose.bones.get('root')
    if head:
        print(f'  Frame {frame}: Head rot_q={head.rotation_quaternion}')
    if jaw:
        print(f'  Frame {frame}: Jaw rot_q={jaw.rotation_quaternion}')

print(f'\nSlot binding:')
print(f'  action_slot_handle: {base_arm.animation_data.action_slot_handle}')
for slot in anim_action.slots:
    print(f'  Slot: id={slot.identifier}, handle={slot.handle}, type={slot.target_id_type}')

# ============================================================
# TEST 2: Export USDA from anim FBX directly (no base mesh)
# ============================================================
print('\n' + '='*70)
print('TEST 2: Direct export of anim FBX as USDA')
print('='*70)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=ANIM_FBX, use_anim=True, ignore_leaf_bones=False, automatic_bone_orientation=False)

bpy.context.scene.frame_start = 1
bpy.context.scene.frame_end = 51

test2_path = os.path.join(OUT_DIR, 'TEST_direct.usda')
bpy.ops.wm.usd_export(
    filepath=test2_path,
    selected_objects_only=False,
    export_animation=True,
    export_textures_mode='NEW',
    generate_preview_surface=True,
)
print(f'Exported: {test2_path} ({os.path.getsize(test2_path)} bytes)')

# ============================================================
# TEST 3: Full pipeline (transfer) exported as USDA
# ============================================================
print('\n' + '='*70)
print('TEST 3: Transfer pipeline as USDA')
print('='*70)

bpy.ops.wm.read_factory_settings(use_empty=True)

bpy.ops.import_scene.fbx(filepath=BASE_FBX, use_anim=False, ignore_leaf_bones=False, automatic_bone_orientation=False)
base_arm = None
meshes = []
for obj in bpy.data.objects:
    if obj.type == 'ARMATURE':
        base_arm = obj
    elif obj.type == 'MESH':
        meshes.append(obj)
meshes.sort(key=lambda o: len(o.data.vertices), reverse=True)
for m in meshes[1:]:
    bpy.data.objects.remove(m, do_unlink=True)

bpy.ops.import_scene.fbx(filepath=ANIM_FBX, use_anim=True, ignore_leaf_bones=False, automatic_bone_orientation=False)
anim_arm = None
for obj in bpy.data.objects:
    if obj.type == 'ARMATURE' and obj != base_arm:
        anim_arm = obj
        break

anim_action = anim_arm.animation_data.action
if not base_arm.animation_data:
    base_arm.animation_data_create()
base_arm.animation_data.action = anim_action
for layer in anim_action.layers:
    for strip in layer.strips:
        for cb in strip.channelbags:
            base_arm.animation_data.action_slot_handle = cb.slot_handle

bpy.data.objects.remove(anim_arm, do_unlink=True)

bpy.context.scene.frame_start = 1
bpy.context.scene.frame_end = 51

test3_path = os.path.join(OUT_DIR, 'TEST_transfer.usda')
bpy.ops.wm.usd_export(
    filepath=test3_path,
    selected_objects_only=False,
    export_animation=True,
    export_textures_mode='NEW',
    generate_preview_surface=True,
)
print(f'Exported: {test3_path} ({os.path.getsize(test3_path)} bytes)')

print('\n=== ALL TESTS COMPLETE ===')
