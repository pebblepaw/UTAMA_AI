"""
Sultan FBX → USDZ converter (Blender 5.0+)
Fixes:
  1. Converts TIF textures → PNG (iOS USDZ only supports PNG/JPEG)
  2. Creates PBR materials from scratch (Mixamo strips materials)
  3. Assigns materials by mesh object name (Body → body, Cloths → cloth, eye → eyes)

Usage: /Applications/Blender.app/Contents/MacOS/Blender --background --python convert_sultan_to_usdz.py
"""

import bpy
import os
import sys

# ──────────────────────── Config ────────────────────────
BASE = '/Users/pebblepaw/Documents/CODING_PROJECTS/UTAMA_AI/SULTANASSETS'
TEX_DIR = os.path.join(BASE, 'textures_unity')
OUT_DIR = os.path.join(BASE, 'usdz_output')
PNG_DIR = os.path.join(BASE, 'textures_png')  # Pre-converted PNGs

ANIMATIONS = {
    'Sultan_Idle':    os.path.join(BASE, 'Sultan_Idle.fbx'),
    'Sultan_Talking': os.path.join(BASE, 'Sultan_Talking.fbx'),
    'Sultan_Gesture': os.path.join(BASE, 'Sultan_Gesture.fbx'),
    'Sultan_Bow':     os.path.join(BASE, 'Sultan_Bow.fbx'),
    'Sultan_Dance':   os.path.join(BASE, 'Sultan_Dance.fbx'),
}

# Mesh name → texture prefix mapping
MESH_TEX_MAP = {
    'Body':   'sultan_body',
    'Cloths': 'sultan_cloth',
    'eye':    'sultan_eyes',
}

os.makedirs(OUT_DIR, exist_ok=True)
os.makedirs(PNG_DIR, exist_ok=True)

# ──────────────────────── Step 1: Convert TIF → PNG ────────────────────────
def convert_textures_to_png():
    """Convert all TIF textures to PNG format for USDZ compatibility."""
    print('\n=== Converting TIF textures to PNG ===')
    for fname in os.listdir(TEX_DIR):
        if not fname.lower().endswith('.tif'):
            continue
        tif_path = os.path.join(TEX_DIR, fname)
        png_name = os.path.splitext(fname)[0] + '.png'
        png_path = os.path.join(PNG_DIR, png_name)
        
        if os.path.exists(png_path):
            print(f'  [skip] {png_name} already exists')
            continue
        
        print(f'  [convert] {fname} → {png_name}')
        # Load image in Blender and ensure pixels are loaded
        img = bpy.data.images.load(tif_path, check_existing=False)
        # Force pixel data to load
        img.pixels[0]
        img.file_format = 'PNG'
        img.filepath_raw = png_path
        img.save_render(png_path)
        bpy.data.images.remove(img)
    
    print('  PNG conversion complete.')


def get_png_path(prefix, suffix):
    """Get the PNG path for a given texture prefix and suffix."""
    return os.path.join(PNG_DIR, f'{prefix}_{suffix}.png')


# ──────────────────────── Step 2: Build PBR Material ────────────────────────
def create_pbr_material(name, tex_prefix):
    """Create a Principled BSDF material with Unity metallic workflow textures."""
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    
    # Clear defaults
    nodes.clear()
    
    # Create output + Principled BSDF
    output = nodes.new('ShaderNodeOutputMaterial')
    output.location = (400, 0)
    bsdf = nodes.new('ShaderNodeBsdfPrincipled')
    bsdf.location = (0, 0)
    links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])
    
    y_offset = 0
    
    # --- Albedo (Base Color) ---
    albedo_path = get_png_path(tex_prefix, 'AlbedoTransparency')
    if os.path.exists(albedo_path):
        tex_albedo = nodes.new('ShaderNodeTexImage')
        tex_albedo.location = (-600, y_offset)
        tex_albedo.image = bpy.data.images.load(albedo_path)
        tex_albedo.image.colorspace_settings.name = 'sRGB'
        links.new(tex_albedo.outputs['Color'], bsdf.inputs['Base Color'])
        # Use alpha for transparency if needed
        links.new(tex_albedo.outputs['Alpha'], bsdf.inputs['Alpha'])
        print(f'    Albedo: {os.path.basename(albedo_path)}')
    else:
        print(f'    WARNING: Albedo not found: {albedo_path}')
    
    y_offset -= 300
    
    # --- Normal Map ---
    normal_path = get_png_path(tex_prefix, 'Normal')
    if os.path.exists(normal_path):
        tex_normal = nodes.new('ShaderNodeTexImage')
        tex_normal.location = (-600, y_offset)
        tex_normal.image = bpy.data.images.load(normal_path)
        tex_normal.image.colorspace_settings.name = 'Non-Color'
        
        normal_map = nodes.new('ShaderNodeNormalMap')
        normal_map.location = (-200, y_offset)
        links.new(tex_normal.outputs['Color'], normal_map.inputs['Color'])
        links.new(normal_map.outputs['Normal'], bsdf.inputs['Normal'])
        print(f'    Normal: {os.path.basename(normal_path)}')
    else:
        print(f'    WARNING: Normal not found: {normal_path}')
    
    y_offset -= 300
    
    # --- Metallic + Smoothness (Unity packed: R=Metallic, A=Smoothness) ---
    metal_path = get_png_path(tex_prefix, 'MetallicSmoothness')
    if os.path.exists(metal_path):
        tex_metal = nodes.new('ShaderNodeTexImage')
        tex_metal.location = (-600, y_offset)
        tex_metal.image = bpy.data.images.load(metal_path)
        tex_metal.image.colorspace_settings.name = 'Non-Color'
        
        # Separate color channels - Blender 5.0 uses SeparateColor
        sep = nodes.new('ShaderNodeSeparateColor')
        sep.location = (-300, y_offset)
        links.new(tex_metal.outputs['Color'], sep.inputs['Color'])
        
        # R channel = Metallic
        links.new(sep.outputs[0], bsdf.inputs['Metallic'])
        
        # A channel = Smoothness → invert to get Roughness
        invert = nodes.new('ShaderNodeMath')
        invert.operation = 'SUBTRACT'
        invert.location = (-100, y_offset - 100)
        invert.inputs[0].default_value = 1.0
        links.new(tex_metal.outputs['Alpha'], invert.inputs[1])
        links.new(invert.outputs[0], bsdf.inputs['Roughness'])
        print(f'    MetallicSmoothness: {os.path.basename(metal_path)}')
    else:
        print(f'    WARNING: MetallicSmoothness not found: {metal_path}')
    
    return mat


# ──────────────────────── Step 3: Export each animation ────────────────────────
def export_sultan(anim_name, fbx_path):
    """Import Sultan FBX, apply materials, export to USDZ."""
    print(f'\n{"="*60}')
    print(f'Processing: {anim_name}')
    print(f'{"="*60}')
    
    # Clean scene
    bpy.ops.wm.read_factory_settings(use_empty=True)
    
    # Import FBX
    print(f'  Importing: {os.path.basename(fbx_path)}')
    bpy.ops.import_scene.fbx(
        filepath=fbx_path,
        use_anim=True,
        ignore_leaf_bones=False,
        automatic_bone_orientation=False,
    )
    
    # Create and assign materials
    print('  Creating PBR materials...')
    for obj in bpy.data.objects:
        if obj.type != 'MESH':
            continue
        
        mesh_name = obj.name
        tex_prefix = MESH_TEX_MAP.get(mesh_name)
        if not tex_prefix:
            print(f'    WARNING: No texture mapping for mesh "{mesh_name}", skipping')
            continue
        
        mat_name = f'MAT_{mesh_name}'
        mat = create_pbr_material(mat_name, tex_prefix)
        
        # Clear existing material slots and add new one
        obj.data.materials.clear()
        obj.data.materials.append(mat)
        
        # Assign material to all faces
        if obj.data.polygons:
            for poly in obj.data.polygons:
                poly.material_index = 0
        
        print(f'  Assigned {mat_name} to {mesh_name} ({len(obj.data.polygons)} faces)')
    
    # Select all for export
    bpy.ops.object.select_all(action='SELECT')
    
    # Export USDZ
    out_path = os.path.join(OUT_DIR, f'{anim_name}.usdz')
    print(f'  Exporting: {out_path}')
    bpy.ops.wm.usd_export(
        filepath=out_path,
        selected_objects_only=False,
        export_animation=True,
        export_textures_mode='NEW',
        generate_preview_surface=True,
        export_materials=True,
        overwrite_textures=True,
        usdz_downscale_size='2048',
        usdz_downscale_custom_size=2048,
    )
    
    # Verify
    file_size = os.path.getsize(out_path) / (1024 * 1024)
    print(f'  Output: {file_size:.1f} MB')


# ──────────────────────── Main ────────────────────────
if __name__ == '__main__':
    convert_textures_to_png()
    
    for anim_name, fbx_path in ANIMATIONS.items():
        if os.path.exists(fbx_path):
            export_sultan(anim_name, fbx_path)
        else:
            print(f'ERROR: FBX not found: {fbx_path}')
    
    print('\n=== Sultan conversion complete ===')
