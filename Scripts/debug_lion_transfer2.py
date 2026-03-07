"""
Test: Transfer animation action from anim armature to base armature in Blender 5.0.
Uses correct Blender 5.0 slot API (identifier, name_display, handle).
"""
import bpy

BASE_FBX = '/Users/pebblepaw/Documents/CODING_PROJECTS/UTAMA_AI/LIONASSETS/uploads_files_6678807_Lion@Bite/SK_Lion.FBX'
ANIM_FBX = '/Users/pebblepaw/Documents/CODING_PROJECTS/UTAMA_AI/LIONASSETS/uploads_files_6678807_Lion@Bite/Lion@Roar.FBX'

bpy.ops.wm.read_factory_settings(use_empty=True)

# Import base model
print('=== Importing base ===')
bpy.ops.import_scene.fbx(filepath=BASE_FBX, use_anim=False, ignore_leaf_bones=False, automatic_bone_orientation=False)

base_arm = None
for obj in bpy.data.objects:
    if obj.type == 'ARMATURE':
        base_arm = obj
        break
print(f'Base: {base_arm.name}, bones={len(base_arm.data.bones)}')

# Import animation
print('=== Importing animation ===')
bpy.ops.import_scene.fbx(filepath=ANIM_FBX, use_anim=True, ignore_leaf_bones=False, automatic_bone_orientation=False)

anim_arm = None
for obj in bpy.data.objects:
    if obj.type == 'ARMATURE' and obj != base_arm:
        anim_arm = obj
        break

anim_action = anim_arm.animation_data.action
print(f'Anim: {anim_arm.name}, action={anim_action.name}')

# Show slot info
for s in anim_action.slots:
    print(f'  Slot: identifier={s.identifier}, display={s.name_display}, handle={s.handle}, type={s.target_id_type}')

# Get fcurve count from channelbag
for layer in anim_action.layers:
    for strip in layer.strips:
        for cb in strip.channelbags:
            fcs = list(cb.fcurves)
            print(f'  Channelbag: slot_handle={cb.slot_handle}, fcurves={len(fcs)}')

# Assign action to base armature
print('\n=== Transferring action ===')
if not base_arm.animation_data:
    base_arm.animation_data_create()

base_arm.animation_data.action = anim_action

# Check what slot was auto-assigned
print(f'Base action_slot_handle: {base_arm.animation_data.action_slot_handle}')

# List slots after assignment
print('Slots now:')
for s in anim_action.slots:
    print(f'  identifier={s.identifier}, handle={s.handle}, users={s.users}')

# If handle is 0 or doesn't match any channelbag, we need to create/bind a slot
cb_handles = set()
for layer in anim_action.layers:
    for strip in layer.strips:
        for cb in strip.channelbags:
            cb_handles.add(cb.slot_handle)

base_handle = base_arm.animation_data.action_slot_handle
if base_handle not in cb_handles:
    print(f'Base handle {base_handle} not in channelbag handles {cb_handles}')
    # The existing slot from anim is for the anim armature
    # We need to either rebind or create a new slot
    # Try: just set the handle to the existing channelbag's slot
    for h in cb_handles:
        base_arm.animation_data.action_slot_handle = h
        print(f'Force-set handle to {h}')
        break
else:
    print(f'Handle {base_handle} matches channelbag - good!')

# Verify animation works by checking pose at different frames
print('\n=== Pose verification ===')
for frame in [1, 25, 50]:
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()
    pb = base_arm.pose.bones.get('LION_ Head')
    if pb:
        print(f'  Frame {frame}: Head loc={pb.location}, rot_q={pb.rotation_quaternion}')
    pb2 = base_arm.pose.bones.get('LION_ Pelvis')
    if pb2:
        print(f'  Frame {frame}: Pelvis loc={pb2.location}, rot_q={pb2.rotation_quaternion}')

# Compare with anim armature
print('\n=== Anim armature comparison ===')
# Temporarily re-assign action to anim armature for comparison
anim_arm.animation_data.action = anim_action
for s in anim_action.slots:
    if s.handle in cb_handles:
        anim_arm.animation_data.action_slot_handle = s.handle
        break

for frame in [1, 25, 50]:
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()
    pb = anim_arm.pose.bones.get('LION_ Head')
    if pb:
        print(f'  Frame {frame}: Head loc={pb.location}, rot_q={pb.rotation_quaternion}')
