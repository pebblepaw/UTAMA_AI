import bpy, os

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(
    filepath='/Users/pebblepaw/Documents/CODING_PROJECTS/UTAMA_AI/SULTANASSETS/Sultan_Idle.fbx',
    use_anim=True, ignore_leaf_bones=False
)

print('=== OBJECTS ===')
for obj in bpy.data.objects:
    print(f'  {obj.name}: type={obj.type}')
    if obj.type == 'MESH':
        print(f'    mesh={obj.data.name}, verts={len(obj.data.vertices)}, mat_slots={len(obj.material_slots)}')
        for i, slot in enumerate(obj.material_slots):
            print(f'    slot[{i}]: {slot.material.name if slot.material else None}')
        for uv in obj.data.uv_layers:
            print(f'    UV: {uv.name}')

print('=== MATERIALS ===')
for mat in bpy.data.materials:
    print(f'  {mat.name}')
    if mat.node_tree:
        for node in mat.node_tree.nodes:
            print(f'    node: {node.type} - {node.name}')
