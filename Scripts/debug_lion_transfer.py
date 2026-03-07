"""
Test: Transfer animation from anim armature to base armature in Blender 5.0
This keeps the base rest pose (which matches the mesh skinning) and applies
the animation data on top.
"""
import bpy
import os

BASE_FBX = '/Users/pebblepaw/Documents/CODING_PROJECTS/UTAMA_AI/LIONASSETS/uploads_files_6678807_Lion@Bite/SK_Lion.FBX'
ANIM_FBX = '/Users/pebblepaw/Documents/CODING_PROJECTS/UTAMA_AI/LIONASSETS/uploads_files_6678807_Lion@Bite/Lion@Roar.FBX'
OUT_DIR = '/Users/pebblepaw/Documents/CODING_PROJECTS/UTAMA_AI/LIONASSETS/usdz_output'

bpy.ops.wm.read_factory_settings(use_empty=True)

# Step 1: Import base model (mesh + armature with correct rest pose)
print('=== Importing base model ===')
bpy.ops.import_scene.fbx(filepath=BASE_FBX, use_anim=False, ignore_leaf_bones=False, automatic_bone_orientation=False)

base_arm = None
base_meshes = []
for obj in bpy.data.objects:
    if obj.type == 'ARMATURE':
        base_arm = obj
    elif obj.type == 'MESH':
        base_meshes.append(obj)

print(f'Base armature: {base_arm.name}, bones: {len(base_arm.data.bones)}')
print(f'Meshes: {[m.name for m in base_meshes]}')

# Step 2: Import animation FBX
print('\n=== Importing animation ===')
bpy.ops.import_scene.fbx(filepath=ANIM_FBX, use_anim=True, ignore_leaf_bones=False, automatic_bone_orientation=False)

anim_arm = None
for obj in bpy.data.objects:
    if obj.type == 'ARMATURE' and obj != base_arm:
        anim_arm = obj
        break

print(f'Anim armature: {anim_arm.name}')
anim_action = anim_arm.animation_data.action
print(f'Anim action: {anim_action.name}')

# Inspect action structure
for layer in anim_action.layers:
    for strip in layer.strips:
        for cb in strip.channelbags:
            fcs = list(cb.fcurves)
            print(f'  Slot: {cb.slot.name}, handle: {cb.slot.handle}, fcurves: {len(fcs)}')
            # Show a few
            for fc in fcs[:3]:
                print(f'    {fc.data_path}[{fc.array_index}]: {len(fc.keyframe_points)} keys')

# Step 3: Try to assign the action to the base armature
print('\n=== Assigning action to base armature ===')
if not base_arm.animation_data:
    base_arm.animation_data_create()

# Method A: Direct assignment - let Blender handle slot binding
base_arm.animation_data.action = anim_action

# Check if it bound correctly
print(f'Base arm action: {base_arm.animation_data.action.name if base_arm.animation_data.action else None}')
print(f'Base arm slot handle: {base_arm.animation_data.action_slot_handle}')

# List all slots in the action now
print('Action slots:')
for slot in anim_action.slots:
    print(f'  {slot.name}: handle={slot.handle}')

# Check if base armature found a valid slot
# We may need to create a slot for the base armature
active_slot = None
for slot in anim_action.slots:
    if slot.handle == base_arm.animation_data.action_slot_handle:
        active_slot = slot
        break

if active_slot:
    print(f'Active slot: {active_slot.name}')
else:
    print('No active slot found! Trying to find or create one...')
    # Try to create a new slot for the base armature
    new_slot = anim_action.slots.new(for_id=base_arm)
    print(f'Created slot: {new_slot.name}, handle={new_slot.handle}')
    base_arm.animation_data.action_slot_handle = new_slot.handle
    print(f'Assigned slot handle: {base_arm.animation_data.action_slot_handle}')

# Step 4: Check if the base armature now has animation working
# Set to a mid-frame and check a pose bone
bpy.context.scene.frame_set(25)
bpy.context.view_layer.update()

print('\n=== Pose check at frame 25 ===')
for bname in ['root', 'LION_ Pelvis', 'LION_ Head', 'LION_ Spine']:
    if bname in base_arm.pose.bones:
        pb = base_arm.pose.bones[bname]
        print(f'  {bname}: loc={pb.location}, rot_q={pb.rotation_quaternion}')

# Also check anim armature at same frame for comparison
for bname in ['root', 'LION_ Pelvis', 'LION_ Head', 'LION_ Spine']:
    if bname in anim_arm.pose.bones:
        pb = anim_arm.pose.bones[bname]
        print(f'  [anim] {bname}: loc={pb.location}, rot_q={pb.rotation_quaternion}')
