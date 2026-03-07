import bpy

bpy.ops.wm.read_factory_settings(use_empty=True)

# Import base
bpy.ops.import_scene.fbx(filepath='/Users/pebblepaw/Documents/CODING_PROJECTS/UTAMA_AI/LIONASSETS/uploads_files_6678807_Lion@Bite/SK_Lion.FBX', use_anim=True, ignore_leaf_bones=False, automatic_bone_orientation=False)
base_bones = set()
for obj in bpy.data.objects:
    if obj.type == 'ARMATURE':
        base_bones = set(b.name for b in obj.data.bones)
        print(f'Base armature: {obj.name}, bones: {len(base_bones)}')
        break

# Import an animation
bpy.ops.import_scene.fbx(filepath='/Users/pebblepaw/Documents/CODING_PROJECTS/UTAMA_AI/LIONASSETS/uploads_files_6678807_Lion@Bite/Lion@Roar.FBX', use_anim=True, ignore_leaf_bones=False, automatic_bone_orientation=False)

for obj in bpy.data.objects:
    if obj.type == 'ARMATURE' and obj.name != 'Armature':
        anim_bones = set(b.name for b in obj.data.bones)
        print(f'Anim armature: {obj.name}, bones: {len(anim_bones)}')
        print(f'Bones match: {base_bones == anim_bones}')
        print(f'In base not anim: {base_bones - anim_bones}')
        print(f'In anim not base: {anim_bones - base_bones}')
        
        # Check action slot info
        if obj.animation_data and obj.animation_data.action:
            act = obj.animation_data.action
            print(f'Action: {act.name}')
            for slot in act.slots:
                print(f'  Slot: {slot.name}, handle={slot.handle}')
