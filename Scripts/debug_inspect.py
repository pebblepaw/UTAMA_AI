"""
Debug script: Inspect what Blender imports from FBX files and how textures
are embedded in the USDZ output. This helps diagnose:
1. Pink/magenta textures (missing or broken texture references)
2. Static Lion animations (animation data not being applied)
"""

import bpy
import os
import zipfile
import struct

BASE = "/Users/pebblepaw/Documents/CODING_PROJECTS/UTAMA_AI"


def clear_all():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for coll in [bpy.data.meshes, bpy.data.materials, bpy.data.images,
                 bpy.data.armatures, bpy.data.actions, bpy.data.textures]:
        for block in list(coll):
            coll.remove(block)


def inspect_tga(path):
    """Read TGA header to check format."""
    with open(path, 'rb') as f:
        header = f.read(18)
    id_len, cmap_type, img_type = struct.unpack('<BBB', header[:3])
    width, height, bpp = struct.unpack('<HHB', header[12:17])
    print(f"    TGA: {width}x{height}, {bpp}bpp, type={img_type}")
    return width, height, bpp


def inspect_tif(path):
    """Check TIF dimensions using Blender's image loader."""
    try:
        img = bpy.data.images.load(path)
        w, h = img.size[0], img.size[1]
        channels = img.channels
        cs = img.colorspace_settings.name
        print(f"    TIF: {w}x{h}, {channels}ch, colorspace={cs}")
        # Check if the image actually has pixel data
        if w == 0 or h == 0:
            print(f"    WARNING: Image has zero dimensions!")
        bpy.data.images.remove(img)
        return w, h
    except Exception as e:
        print(f"    ERROR loading: {e}")
        return 0, 0


def inspect_material_nodes(mat):
    """Print the node tree of a material."""
    if not mat.use_nodes:
        print(f"    (no node tree)")
        return
    for node in mat.node_tree.nodes:
        print(f"    Node: {node.type} ({node.name})")
        if node.type == 'TEX_IMAGE':
            if node.image:
                img = node.image
                print(f"      Image: {img.name}")
                print(f"      Path: {img.filepath}")
                print(f"      Size: {img.size[0]}x{img.size[1]}")
                print(f"      Packed: {img.packed_file is not None}")
                print(f"      Colorspace: {img.colorspace_settings.name}")
                # Check if image has actual pixel data
                if img.size[0] == 0 or img.size[1] == 0:
                    print(f"      *** BROKEN IMAGE - zero size! ***")
            else:
                print(f"      *** NO IMAGE ASSIGNED ***")
        elif node.type == 'BSDF_PRINCIPLED':
            for inp in node.inputs:
                if inp.is_linked:
                    print(f"      Input '{inp.name}' <- linked")
                elif inp.type == 'RGBA':
                    print(f"      Input '{inp.name}' = {list(inp.default_value)}")


def inspect_usdz_contents(usdz_path):
    """List the files inside a USDZ archive."""
    print(f"\n  USDZ contents of {os.path.basename(usdz_path)}:")
    with zipfile.ZipFile(usdz_path) as z:
        for info in z.infolist():
            ext = os.path.splitext(info.filename)[1]
            print(f"    {info.filename}: {info.file_size:,} bytes")
            # Check texture files
            if ext in ['.png', '.jpg', '.exr', '.tif', '.tga']:
                if info.file_size < 1000:
                    print(f"      *** SUSPICIOUS: texture file is tiny ({info.file_size} bytes) ***")


print("=" * 70)
print("TEXTURE FILE INSPECTION")
print("=" * 70)

# Check Sultan textures
print("\n--- Sultan Unity Textures ---")
tex_dir = os.path.join(BASE, "SULTANASSETS/textures_unity")
for f in sorted(os.listdir(tex_dir)):
    if f.endswith('.tif'):
        print(f"  {f}:")
        inspect_tif(os.path.join(tex_dir, f))

print("\n--- Sultan PBR Textures ---")
tex_dir = os.path.join(BASE, "SULTANASSETS/textures_pbr")
for f in sorted(os.listdir(tex_dir)):
    if f.endswith('.tif'):
        print(f"  {f} ({os.path.getsize(os.path.join(tex_dir, f)) / 1024:.0f} KB):")
        inspect_tif(os.path.join(tex_dir, f))

print("\n--- Lion Textures ---")
for f in sorted(os.listdir(os.path.join(BASE, "LIONASSETS"))):
    if f.endswith('.tga'):
        fpath = os.path.join(BASE, "LIONASSETS", f)
        print(f"  {f} ({os.path.getsize(fpath) / (1024*1024):.0f} MB):")
        inspect_tga(fpath)
        # Also try loading in Blender
        try:
            img = bpy.data.images.load(fpath)
            print(f"    Blender: {img.size[0]}x{img.size[1]}, {img.channels}ch")
            bpy.data.images.remove(img)
        except Exception as e:
            print(f"    Blender load ERROR: {e}")


print("\n" + "=" * 70)
print("SULTAN FBX MATERIAL INSPECTION")
print("=" * 70)

clear_all()
print("\nImporting Sultan_Idle.fbx...")
bpy.ops.import_scene.fbx(
    filepath=os.path.join(BASE, "SULTANASSETS/Sultan_Idle.fbx"),
    use_anim=True,
)
print("\nObjects imported:")
for obj in bpy.data.objects:
    print(f"  {obj.name} (type={obj.type})")
    if obj.type == 'MESH':
        print(f"    Vertices: {len(obj.data.vertices)}")
        print(f"    UV layers: {[uv.name for uv in obj.data.uv_layers]}")
        print(f"    Material slots: {len(obj.material_slots)}")
        for i, slot in enumerate(obj.material_slots):
            if slot.material:
                print(f"    MatSlot[{i}]: {slot.material.name}")
                inspect_material_nodes(slot.material)

print("\nAll materials:")
for mat in bpy.data.materials:
    print(f"  Material: {mat.name} (users={mat.users})")
    inspect_material_nodes(mat)

# Check existing USDZ
print("\n\n" + "=" * 70)
print("EXISTING USDZ INSPECTION")
print("=" * 70)

inspect_usdz_contents(os.path.join(BASE, "SULTANASSETS/usdz_output/Sultan_Idle.usdz"))
inspect_usdz_contents(os.path.join(BASE, "LIONASSETS/usdz_output/Lion_Idle.usdz"))
inspect_usdz_contents(os.path.join(BASE, "LIONASSETS/usdz_output/Lion_Roar.usdz"))


print("\n" + "=" * 70)
print("LION ANIMATION INSPECTION")
print("=" * 70)

clear_all()

# Import Lion base model
print("\nImporting SK_Lion.FBX (base)...")
bpy.ops.import_scene.fbx(
    filepath=os.path.join(BASE, "LIONASSETS/uploads_files_6678807_Lion@Bite/SK_Lion.FBX"),
    use_anim=False,
    ignore_leaf_bones=False,
    automatic_bone_orientation=False,
)
print("Base objects:")
armature = None
for obj in bpy.data.objects:
    print(f"  {obj.name} (type={obj.type})")
    if obj.type == 'ARMATURE':
        armature = obj
        print(f"    Bones: {len(obj.data.bones)}")
        print(f"    Has anim_data: {obj.animation_data is not None}")
        if obj.animation_data and obj.animation_data.action:
            print(f"    Action: {obj.animation_data.action.name}")
    if obj.type == 'MESH':
        print(f"    Vertices: {len(obj.data.vertices)}")
        # Check if mesh has vertex groups (bone weights)
        print(f"    Vertex groups: {len(obj.vertex_groups)}")
        if obj.vertex_groups:
            print(f"    First 5 groups: {[g.name for g in obj.vertex_groups[:5]]}")

# Now import an animation FBX
print("\nImporting Lion@IdleBreathe.FBX (animation)...")
existing = set(bpy.data.objects[:])
bpy.ops.import_scene.fbx(
    filepath=os.path.join(BASE, "LIONASSETS/uploads_files_6678807_Lion@Bite/Lion@IdleBreathe.FBX"),
    use_anim=True,
    ignore_leaf_bones=False,
    automatic_bone_orientation=False,
)
new_objects = set(bpy.data.objects[:]) - existing
print(f"New objects from animation FBX: {len(new_objects)}")
for obj in new_objects:
    print(f"  {obj.name} (type={obj.type})")
    if obj.type == 'ARMATURE':
        print(f"    Bones: {len(obj.data.bones)}")
        if obj.animation_data:
            print(f"    Has animation_data: True")
            if obj.animation_data.action:
                act = obj.animation_data.action
                print(f"    Action: {act.name}")
                print(f"    Frame range: {act.frame_range}")
                print(f"    FCurves: {len(act.fcurves)}")
                if act.fcurves:
                    print(f"    First 3 FCurves:")
                    for fc in act.fcurves[:3]:
                        print(f"      {fc.data_path} [{fc.array_index}] ({len(fc.keyframe_points)} keys)")
                        
# Check if bone names match between base armature and animation armature
if armature:
    base_bones = set(b.name for b in armature.data.bones)
    for obj in new_objects:
        if obj.type == 'ARMATURE':
            anim_bones = set(b.name for b in obj.data.bones)
            matching = base_bones & anim_bones
            only_base = base_bones - anim_bones
            only_anim = anim_bones - base_bones
            print(f"\n  Bone name comparison:")
            print(f"    Base bones: {len(base_bones)}")
            print(f"    Anim bones: {len(anim_bones)}")
            print(f"    Matching: {len(matching)}")
            if only_base:
                print(f"    Only in base (first 5): {list(only_base)[:5]}")
            if only_anim:
                print(f"    Only in anim (first 5): {list(only_anim)[:5]}")

# Check all actions
print(f"\nAll actions in blend file:")
for act in bpy.data.actions:
    print(f"  {act.name}: frames {act.frame_range}, {len(act.fcurves)} fcurves")

print("\n" + "=" * 70)
print("LION ROAR ANIMATION CHECK")
print("=" * 70)
# Also check Roar specifically
print("\nImporting Lion@Roar.FBX...")
existing2 = set(bpy.data.objects[:])
bpy.ops.import_scene.fbx(
    filepath=os.path.join(BASE, "LIONASSETS/uploads_files_6678807_Lion@Bite/Lion@Roar.FBX"),
    use_anim=True,
    ignore_leaf_bones=False,
    automatic_bone_orientation=False,
)
new_objects2 = set(bpy.data.objects[:]) - existing2
for obj in new_objects2:
    if obj.type == 'ARMATURE' and obj.animation_data and obj.animation_data.action:
        act = obj.animation_data.action
        print(f"  Roar Action: {act.name}, frames {act.frame_range}, {len(act.fcurves)} fcurves")
        # Check the data_path format
        if act.fcurves:
            print(f"  Sample FCurve paths:")
            seen = set()
            for fc in act.fcurves:
                path_root = fc.data_path.split('.')[0] if '.' in fc.data_path else fc.data_path
                if path_root not in seen:
                    seen.add(path_root)
                    print(f"    {fc.data_path}")
                if len(seen) > 10:
                    break

print("\nDONE")
