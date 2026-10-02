// The new scene API. The idea is that what to draw is defined trough this,
// and the renderer can be nicely separated and tested.
//
// I'm also planning to maybe add a WGPU backend at some point or something.

Trile_Mesh :: struct { id: u32; }
Texture    :: struct { id: u32; }
Font_Face  :: struct { id: s32; }
View_Id    :: struct { index: s32; }

Environment :: struct {
}

View :: struct {
    camera      : Camera;
    environment : *Environment;
    draw_world  : bool = true;
}

Trile_Tint :: enum u8 {
    NONE;
    ADD_PREVIEW;
    DELETE_PREVIEW;
}

// This direction means that the billboard should face the camera.
BILLBOARD_FACE_CAMERA :: Vector3.{-100, -100, -100};

Blend_Mode :: enum u8 {
    ALPHA;
    ADDITIVE;
}

Particle_Instance :: struct {
    position : Vector3;
    size     : float;
    uv_rect  : Vector4;   // x, y, w, h, 0..1
    color    : Vector4;
}

// Pixels from top left.
Ui_Vertex :: struct {
    position : Vector2;
    uv       : Vector2;
    color    : Vector4;
}

trile_mesh_create :: (trile: *Trile) -> Trile_Mesh {
    scene.trile_mesh_count += 1;
    return .{scene.trile_mesh_count};
}

trile_mesh_update :: (mesh: Trile_Mesh, trile: *Trile) {
}

trile_mesh_destroy :: (mesh: Trile_Mesh) {
}

// Pixels are RGBA8.
texture_create :: (width: s32, height: s32, pixels: []u8) -> Texture {
    return .{renderer_texture_create(width, height, pixels)};
}

texture_update :: (texture: Texture, pixels: []u8) {
    renderer_texture_update(texture.id, pixels);
}

texture_destroy :: (texture: Texture) {
    renderer_texture_destroy(texture.id);
}

World_Group :: struct {
    mesh      : Trile_Mesh;
    instances : []Trile_Instance;
}

world_set_chunk :: (key: Chunk_Key, groups: []World_Group) {
    chunk := find_or_add(*scene.chunks, key);
    for chunk.groups  array_free(it.instances);
    array_reset_keeping_memory(*chunk.groups);
    for groups {
        group := array_add(*chunk.groups);
        group.mesh      = it.mesh;
        group.instances = array_copy(it.instances);
    }
}

world_remove_chunk :: (key: Chunk_Key) {
    chunk := table_find_pointer(*scene.chunks, key);
    if !chunk  return;
    for chunk.groups  array_free(it.instances);
    array_free(chunk.groups);
    table_remove(*scene.chunks, key);
}

world_clear :: () {
    for chunk: scene.chunks {
        for chunk.groups  array_free(it.instances);
        array_free(chunk.groups);
    }
    table_reset(*scene.chunks);
}

add_view :: (view: View) -> View_Id {
    array_add(*scene.views, view);
    return .{xx (scene.views.count - 1)};
}

draw_trile :: (view: View_Id, mesh: Trile_Mesh, position: Vector3, orientation: u8, tint := Trile_Tint.NONE) {
    array_add(*scene.triles, .{view, mesh, position, orientation, tint});
}

// uv_rect is x, y, w, h in the sheet, normalized; a negative w mirrors it.
draw_billboard :: (view: View_Id, sheet: Texture, uv_rect: Vector4, size: Vector2, position: Vector3, face := BILLBOARD_FACE_CAMERA) {
    array_add(*scene.billboards, .{view, sheet, uv_rect, size, position, face});
}

draw_particles :: (view: View_Id, sheet: Texture, blend: Blend_Mode, particles: []Particle_Instance) {
    array_add(*scene.particles, .{view, sheet, blend, array_copy(particles,, temp)});
}

// Untextured triangles pass a zero texture.
ui_triangles :: (vertices: []Ui_Vertex, texture: Texture) {
    array_add(*scene.ui, .{texture = texture, vertices = array_copy(vertices,, temp)});
}

ui_scissor :: (x: s32, y: s32, w: s32, h: s32) {
    array_add(*scene.ui, .{scissor = .{x, y, w, h}, set_scissor = true});
}

ui_scissor_clear :: () {
    array_add(*scene.ui, .{clear_scissor = true});
}

Scene_Chunk :: struct {
    groups : [..]World_Group;
}

Scene_Trile :: struct {
    view        : View_Id;
    mesh        : Trile_Mesh;
    position    : Vector3;
    orientation : u8;
    tint        : Trile_Tint;
}

Scene_Billboard :: struct {
    view     : View_Id;
    sheet    : Texture;
    uv_rect  : Vector4;
    size     : Vector2;
    position : Vector3;
    face     : Vector3;
}

Scene_Particles :: struct {
    view      : View_Id;
    sheet     : Texture;
    blend     : Blend_Mode;
    particles : []Particle_Instance;
}

Scene_Ui :: struct {
    texture       : Texture;
    vertices      : []Ui_Vertex;
    scissor       : Ui_Rect;
    set_scissor   : bool;
    clear_scissor : bool;
}

Scene :: struct {
    trile_mesh_count : u32;

    chunks : Table(Chunk_Key, Scene_Chunk, chunk_key_hash, chunk_key_compare);

    views      : [..]View;
    triles     : [..]Scene_Trile;
    billboards : [..]Scene_Billboard;
    particles  : [..]Scene_Particles;
    ui         : [..]Scene_Ui;
}

scene_init :: () {
    renderer_init();
}

scene_shutdown :: () {
    renderer_shutdown();
}

scene_end_frame :: (width: s32, height: s32) {
    renderer_render(*scene, width, height);
    array_reset_keeping_memory(*scene.views);
    array_reset_keeping_memory(*scene.triles);
    array_reset_keeping_memory(*scene.billboards);
    array_reset_keeping_memory(*scene.particles);
    array_reset_keeping_memory(*scene.ui);
}

#scope_file

scene : Scene;
