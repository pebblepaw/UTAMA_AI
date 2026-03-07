"""
Lion FBX → USDZ converter (Blender 5.0+)
Fixes:
  1. Converts TGA textures → PNG (iOS USDZ only supports PNG/JPEG)
  2. Creates PBR material from Lion textures
  3. Properly handles Blender 5.0 layered action system for animations
  4. Transfers animation action to BASE armature (preserves rest pose)

Strategy:
  The base SK_Lion.FBX has the correct rest pose that the mesh was skinned against.
  Animation FBX files have a DIFFERENT rest pose (18/39 bones differ).
  Reparenting mesh to anim armature causes warping/stretching.
  
  CORRECT approach: Import base FBX (mesh stays parented to its armature) →
  Import animation FBX → Transfer the action to the base armature via
  Blender 5.0's slot system → Delete the animation armature → Export.

Usage: /Applications/Blender.app/Contents/MacOS/Blender --background --python convert_lion_to_usdz.py
"""

import bpy
import os
import sys

# ──────────────────────── Config ────────────────────────
BASE = '/Users/pebblepaw/Documents/CODING_PROJECTS/UTAMA_AI/LIONASSETS'
LION_DIR = os.path.join(BASE, 'uploads_files_6678807_Lion@Bite')
OUT_DIR = os.path.join(BASE, 'usdz_output')
PNG_DIR = os.path.join(BASE, 'textures_png')

# Base model
BASE_FBX = os.path.join(LION_DIR, 'SK_Lion.FBX')

# Texture sources (TGA, at workspace root of LIONASSETS)
TEX_BASE_COLOR = os.path.join(BASE, 'uploads_files_6678807_T_Lion_BaseColor.tga')
TEX_METALLIC   = os.path.join(BASE, 'uploads_files_6678807_T_Lion_MetallicSmoothness.tga')

# Animation mapping: output name → animation FBX file
ANIMATIONS = {
    'Lion_Base':    None,  # Just the base model, no animation
    'Lion_Idle':    os.path.join(LION_DIR, 'Lion@IdleBreathe.FBX'),
    'Lion_Resting': os.path.join(LION_DIR, 'Lion@Resting.FBX'),
    'Lion_Roar':    os.path.join(LION_DIR, 'Lion@Roar.FBX'),
    'Lion_Run':     os.path.join(LION_DIR, 'Lion@Run.FBX'),
    'Lion_Walk':    os.path.join(LION_DIR, 'Lion@Walk.FBX'),
}

os.makedirs(OUT_DIR, exist_ok=True)
os.makedirs(PNG_DIR, exist_ok=True)

# ──────────────────────── Step 1: Convert TGA → PNG ────────────────────────
def convert_textures_to_png():
    """Convert Lion TGA textures to PNG for USDZ compatibility."""
    print('\n=== Converting TGA textures to PNG ===')
    conversions = [
        (TEX_BASE_COLOR, os.path.join(PNG_DIR, 'T_Lion_BaseColor.png')),
        (TEX_METALLIC,   os.path.join(PNG_DIR, 'T_Lion_MetallicSmoothness.png')),
    ]
    for src, dst in conversions:
        if os.path.exists(dst):
            print(f'  [skip] {os.path.basename(dst)} already exists')
            continue
        if not os.path.exists(src):
            print(f'  ERROR: Source not found: {src}')
            continue
        print(f'  [convert] {os.path.basename(src)} → {os.path.basename(dst)}')
        img = bpy.data.images.load(src, check_existing=False)
        img.pixels[0]  # Force pixel data load
        img.file_format = 'PNG'
        img.filepath_raw = dst
        img.save_render(dst)
        bpy.data.images.remove(img)
    print('  PNG conversion complete.')


# ──────────────────────── Step 2: Build PBR Material ────────────────────────
def create_lion_material():
    """Create Principled BSDF material for the Lion."""
    mat = bpy.data.materials.new(name='MAT_Lion')
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    
    output = nodes.new('ShaderNodeOutputMaterial')
    output.location = (400, 0)
    bsdf = nodes.new('ShaderNodeBsdfPrincipled')
    bsdf.location = (0, 0)
    links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])
    
    # Base Color
    bc_path = os.path.join(PNG_DIR, 'T_Lion_BaseColor.png')
    if os.path.exists(bc_path):
        tex_bc = nodes.new('ShaderNodeTexImage')
        tex_bc.location = (-600, 0)
        tex_bc.image = bpy.data.images.load(bc_path)
        tex_bc.image.colorspace_settings.name = 'sRGB'
        links.new(tex_bc.outputs['Color'], bsdf.inputs['Base Color'])
        print(f'    BaseColor: {os.path.basename(bc_path)}')
    else:
        print(f'    WARNING: BaseColor not found: {bc_path}')
    
    # Metallic + Smoothness (R=Metallic, A=Smoothness)
    ms_path = os.path.join(PNG_DIR, 'T_Lion_MetallicSmoothness.png')
    if os.path.exists(ms_path):
        tex_ms = nodes.new('ShaderNodeTexImage')
        tex_ms.location = (-600, -300)
        tex_ms.image = bpy.data.images.load(ms_path)
        tex_ms.image.colorspace_settings.name = 'Non-Color'
        
        sep = nodes.new('ShaderNodeSeparateColor')
        sep.location = (-300, -300)
        links.new(tex_ms.outputs['Color'], sep.inputs['Color'])
        links.new(sep.outputs[0], bsdf.inputs['Metallic'])
        
        # Invert smoothness → roughness
        invert = nodes.new('ShaderNodeMath')
        invert.operation = 'SUBTRACT'
        invert.location = (-100, -400)
        invert.inputs[0].default_value = 1.0
        links.new(tex_ms.outputs['Alpha'], invert.inputs[1])
        links.new(invert.outputs[0], bsdf.inputs['Roughness'])
        print(f'    MetallicSmoothness: {os.path.basename(ms_path)}')
    
    return mat


# ──────────────────────── Step 3: Export each animation ────────────────────────
def export_lion(anim_name, anim_fbx_path):
    """Build scene with Lion mesh + animation, export to USDZ.
    
    Key insight: The base SK_Lion.FBX armature has the correct rest pose
    that matches the mesh's vertex weights. The animation FBX files have
    a DIFFERENT rest pose (18/39 bones differ — Head by 5.5 units, etc.).
    
    We MUST keep the mesh parented to the base armature and transfer the
    animation action to it, rather than reparenting the mesh to a different
    armature with a mismatched rest pose.
    """
    print(f'\n{"="*60}')
    print(f'Processing: {anim_name}')
    print(f'{"="*60}')
    
    # Clean scene
    bpy.ops.wm.read_factory_settings(use_empty=True)
    
    # ---- Always import base FBX first (mesh + armature with correct rest pose) ----
    print(f'  Importing base: SK_Lion.FBX')
    bpy.ops.import_scene.fbx(
        filepath=BASE_FBX,
        use_anim=False,
        ignore_leaf_bones=False,
        automatic_bone_orientation=False,
    )
    
    base_arm = None
    mesh_objects = []
    for obj in bpy.data.objects:
        if obj.type == 'ARMATURE':
            base_arm = obj
        elif obj.type == 'MESH':
            mesh_objects.append(obj)
    
    print(f'  Base armature: {base_arm.name}, bones={len(base_arm.data.bones)}')
    
    # Keep only highest LOD mesh
    if mesh_objects:
        mesh_objects.sort(key=lambda o: len(o.data.vertices), reverse=True)
        keep_mesh = mesh_objects[0]
        for m in mesh_objects[1:]:
            bpy.data.objects.remove(m, do_unlink=True)
        print(f'  Kept LOD0: {keep_mesh.name} ({len(keep_mesh.data.vertices)} verts)')
    
    # ---- CRITICAL FIX: Add Armature modifier to mesh ----
    # The Lion FBX from CGTrader has the mesh parented to the armature but
    # WITHOUT an Armature modifier. This means Blender's USD exporter won't
    # generate SkelRoot or skel:skeleton binding. Without those, iOS/macOS
    # USDZ viewers cannot play skeletal animation.
    for obj in bpy.data.objects:
        if obj.type == 'MESH':
            has_arm_mod = any(m.type == 'ARMATURE' for m in obj.modifiers)
            if not has_arm_mod and base_arm:
                arm_mod = obj.modifiers.new(name='Armature', type='ARMATURE')
                arm_mod.object = base_arm
                print(f'  Added Armature modifier to {obj.name} → {base_arm.name}')
    
    if anim_fbx_path:
        # ---- Import animation FBX ----
        print(f'  Importing animation: {os.path.basename(anim_fbx_path)}')
        bpy.ops.import_scene.fbx(
            filepath=anim_fbx_path,
            use_anim=True,
            ignore_leaf_bones=False,
            automatic_bone_orientation=False,
        )
        
        # Find animation armature (the newly imported one)
        anim_arm = None
        for obj in bpy.data.objects:
            if obj.type == 'ARMATURE' and obj != base_arm:
                anim_arm = obj
                break
        
        if not anim_arm or not anim_arm.animation_data or not anim_arm.animation_data.action:
            print('  ERROR: No animation data found in animation FBX!')
            return
        
        anim_action = anim_arm.animation_data.action
        print(f'  Action: {anim_action.name}')
        
        # Get the channelbag slot handle (needed for Blender 5.0 slot binding)
        cb_slot_handle = None
        for layer in anim_action.layers:
            for strip in layer.strips:
                for cb in strip.channelbags:
                    cb_slot_handle = cb.slot_handle
                    fcs = list(cb.fcurves)
                    print(f'  FCurves: {len(fcs)}, slot_handle={cb_slot_handle}')
                    break
        
        # ---- Transfer action to base armature ----
        # Blender 5.0: Actions have "slots" that bind to specific objects.
        # We assign the action and force-bind to the correct slot handle.
        if not base_arm.animation_data:
            base_arm.animation_data_create()
        
        base_arm.animation_data.action = anim_action
        
        # Force-set the slot handle to match the channelbag's slot
        if cb_slot_handle is not None:
            base_arm.animation_data.action_slot_handle = cb_slot_handle
            print(f'  Bound action slot handle: {cb_slot_handle}')
        
        # Delete the animation armature (no longer needed)
        bpy.data.objects.remove(anim_arm, do_unlink=True)
        print('  Removed animation armature')
        
        # ---- Set animation frame range ----
        frame_start = float('inf')
        frame_end = float('-inf')
        for layer in anim_action.layers:
            for strip in layer.strips:
                for cb in strip.channelbags:
                    for fc in cb.fcurves:
                        for kf in fc.keyframe_points:
                            frame_start = min(frame_start, kf.co[0])
                            frame_end = max(frame_end, kf.co[0])
        
        if frame_start != float('inf'):
            bpy.context.scene.frame_start = int(frame_start)
            bpy.context.scene.frame_end = int(frame_end)
            print(f'  Animation range: {int(frame_start)}-{int(frame_end)}')
    
    # ---- Apply material to mesh ----
    print('  Creating PBR material...')
    mat = create_lion_material()
    
    for obj in bpy.data.objects:
        if obj.type == 'MESH':
            obj.data.materials.clear()
            obj.data.materials.append(mat)
            for poly in obj.data.polygons:
                poly.material_index = 0
            print(f'  Applied material to {obj.name}')
    
    # ---- Export USDZ ----
    out_path = os.path.join(OUT_DIR, f'{anim_name}.usdz')
    print(f'  Exporting: {out_path}')
    
    bpy.ops.wm.usd_export(
        filepath=out_path,
        selected_objects_only=False,
        export_animation=True if anim_fbx_path else False,
        export_textures_mode='NEW',
        generate_preview_surface=True,
        export_materials=True,
        overwrite_textures=True,
        usdz_downscale_size='2048',
        usdz_downscale_custom_size=2048,
    )
    
    file_size = os.path.getsize(out_path) / (1024 * 1024)
    print(f'  Output: {file_size:.1f} MB')


# ──────────────────────── Main ────────────────────────
if __name__ == '__main__':
    convert_textures_to_png()
    
    for anim_name, anim_fbx in ANIMATIONS.items():
        if anim_fbx and not os.path.exists(anim_fbx):
            print(f'ERROR: Animation FBX not found: {anim_fbx}')
            continue
        export_lion(anim_name, anim_fbx)
    
    print('\n=== Lion conversion complete ===')
