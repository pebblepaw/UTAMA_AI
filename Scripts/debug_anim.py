import bpy
import os

BASE = '/Users/pebblepaw/Documents/CODING_PROJECTS/UTAMA_AI/LIONASSETS/uploads_files_6678807_Lion@Bite'
bpy.ops.import_scene.fbx(
    filepath=os.path.join(BASE, 'Lion@Roar.FBX'),
    use_anim=True,
    ignore_leaf_bones=False,
    automatic_bone_orientation=False,
)

for obj in bpy.data.objects:
    if obj.type != 'ARMATURE':
        continue
    if not obj.animation_data or not obj.animation_data.action:
        continue
    
    act = obj.animation_data.action
    print("Action:", act.name)
    print("Frame range:", act.frame_range)
    
    # Blender 5.0 layered action system
    if hasattr(act, 'layers'):
        print("Layers:", len(act.layers))
        for li, layer in enumerate(act.layers):
            print("  Layer", li, ":", layer.name)
            if hasattr(layer, 'strips'):
                print("    Strips:", len(layer.strips))
                for si, strip in enumerate(layer.strips):
                    print("    Strip", si, ": type=", strip.type)
                    if hasattr(strip, 'frame_start'):
                        print("      frame_start:", strip.frame_start)
                        print("      frame_end:", strip.frame_end)
                    if hasattr(strip, 'channelbags'):
                        for cbi, cb in enumerate(strip.channelbags):
                            chans = list(cb.channels)
                            print("      Channelbag", cbi, ": channels=", len(chans))
                            for ch in chans[:5]:
                                kcount = len(ch.keys) if hasattr(ch, 'keys') else '?'
                                print("        path:", ch.data_path, "idx:", ch.array_index, "keys:", kcount)
    
    if hasattr(act, 'slots'):
        print("Slots:", len(act.slots))
        for slot in act.slots:
            print("  Slot:", slot.name, "handle:", slot.handle)
    
    # Check bone name match
    print("Armature bones (first 5):")
    for b in list(obj.data.bones)[:5]:
        print(" ", b.name)
    
    # Check slot assignment
    if obj.animation_data:
        print("Animation data action_slot:", getattr(obj.animation_data, 'action_slot', 'N/A'))
        print("Animation data action_slot_handle:", getattr(obj.animation_data, 'action_slot_handle', 'N/A'))
