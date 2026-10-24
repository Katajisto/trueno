// The new scene API. The idea is that what to draw is defined trough this,
// and the renderer can be nicely separated and tested.
//
// I'm also planning to maybe add a WGPU backend at some point or something.

Trile_Mesh :: struct { id: u32; }
Texture    :: struct { id: u32; }
Font_Face  :: struct { id: s32; }
View_Id    :: struct { index: s32; }

Environment :: struct {
    reflection_height  : float;
    water              : bool;
    sky                : bool = true;   // off: black outside the level
    water_color        : Vector3 = .{1, 1, 1};
    deep_color         : Vector3 = .{1, 1, 1};
    water_reflectivity : float;
    water_distortion   : float = 0.007;
    water_shininess    : float = 64;
    water_normals      : Texture;
    sun_direction      : Vector3 = #run normalize(Vector3.{0.2, 0.3, 0.4});   // towards the sun
    sun_color          : Vector3 = .{1, 1, 1};
    shade_color        : Vector3 = .{0.45, 0.45, 0.75};
    sky_base           : Vector3 = .{0.38, 0.81, 0.95};
    sky_top            : Vector3 = .{0.17, 0.4, 0.95};
    sun_disk           : Vector3 = .{1, 1, 1};
    sun_halo           : Vector3 = .{1, 1, 1};
    horizon_halo       : Vector3 = .{1, 1, 1};
    sky_intensity      : float = 0.3;
    exposure           : float;   // in stops
    contrast           : float = 1;
    saturation         : float = 1;
    bloom_amount       : float = 0.4;
    shaft_density      : float = 0.1;   // light shafts through glass
    shaft_amount       : float = 1;
}

// With cut on, triles marked ROOF or WALL are hidden from the camera around the
// focus: everything marked from the lowest roof above the focus upward, so the
// storeys above go whole, and walls on the camera's side of the focus down to a
// one-trile stub. They dissolve in and out rather than popping, and still cast
// shadows and show in reflections.
View :: struct {
    camera      : Camera;
    environment : *Environment;
    draw_world  : bool = true;
    cut         : bool;
    focus       : Vector3;
}

Trile_Cut :: enum u8 {
    NONE;
    ROOF;
    WALL;
}

CUT_RADIUS      :: 12.0;   // horizontal reach from the focus, for roofs and walls
CUT_WALL_MARGIN :: 0.5;    // walls this close to the focus, toward the camera, stay
CUT_FADE_TIME   :: 0.25;   // seconds to dissolve in or out

SHADOW_MAP_SIZE :: 2048;
SHADOW_RADIUS   :: 40.0;
SHADOW_DEPTH    :: 100.0;

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
    glow     : float;     // 0..1, like swatch emittance
}

// Pixels from top left.
Ui_Vertex :: struct {
    position : Vector2;
    uv       : Vector2;
    color    : Vector4;
}

trile_mesh_create :: (trile: *Trile) -> Trile_Mesh {
    vertices, indices := mesh_trile(trile);
    mesh := Trile_Mesh.{renderer_trile_mesh_create(vertices, indices)};
    set_mesh_info(mesh, trile.cut, trile_fills_cell(trile));
    return mesh;
}

trile_mesh_update :: (mesh: Trile_Mesh, trile: *Trile) {
    vertices, indices := mesh_trile(trile);
    renderer_trile_mesh_update(mesh.id, vertices, indices);
    set_mesh_info(mesh, trile.cut, trile_fills_cell(trile));
}

trile_mesh_destroy :: (mesh: Trile_Mesh) {
    renderer_trile_mesh_destroy(mesh.id);
    set_mesh_info(mesh, .NONE, false);
}

swatch_set :: (id: u8, color: [3]u8, reflectivity: u8, gloss: u8, emittance: u8, glass: bool) {
    renderer_swatch_set(id, color, reflectivity, gloss, emittance, glass);
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

// Baked light at a trile centre, as L1 spherical harmonics in half floats: red,
// green and blue, each (constant, y, z, x). A negative red constant marks a probe
// inside geometry.
Probe :: struct {
    sh : [12]u16;
}

// One probe per trile, indexed x + y * CHUNK_SIZE + z * CHUNK_SIZE * CHUNK_SIZE.
PROBES_PER_CHUNK :: CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE;

world_set_chunk :: (key: Chunk_Key, origin: Vector3, groups: []World_Group) {
    scene.world_version += 1;
    chunk := find_or_add(*scene.chunks, key);
    chunk.origin = origin;
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
    scene.world_version += 1;
    for chunk.groups  array_free(it.instances);
    array_free(chunk.groups);
    table_remove(*scene.chunks, key);
}

world_clear :: () {
    scene.world_version += 1;
    for chunk: scene.chunks {
        for chunk.groups  array_free(it.instances);
        array_free(chunk.groups);
    }
    table_reset(*scene.chunks);
    table_reset(*scene.cut_fades);
    renderer_probes_clear();
}

// Probe light is added to the shade colour, so baking only ever brightens.
world_set_chunk_probes :: (key: Chunk_Key, probes: []Probe) {
    assert(probes.count == PROBES_PER_CHUNK);
    renderer_probes_set(key, probes);
}

add_view :: (view: View) -> View_Id {
    array_add(*scene.views, view);
    camera := view.camera;
    array_add(*scene.view_proj, create_viewproj(*camera));

    env := ifx view.environment then view.environment.* else .{};
    array_add(*scene.shadow_view_proj, create_sun_viewproj(camera.target, env.sun_direction, SHADOW_RADIUS, SHADOW_DEPTH, SHADOW_MAP_SIZE));

    height := env.reflection_height;
    camera.position.y = 2 * height - camera.position.y;
    camera.target.y   = 2 * height - camera.target.y;
    array_add(*scene.reflection_view_proj, create_viewproj(*camera));
    array_add(*scene.view_cuts, make_view_cut(view));
    return .{xx (scene.views.count - 1)};
}

// How far the view's camera has dissolved this trile, 0 shown to 1 gone.
// position is the trile's corner. Call once per trile per frame; it advances the fade.
trile_cut :: (view: View_Id, mesh: Trile_Mesh, position: Vector3) -> float {
    cut := scene.view_cuts[view.index];
    kind := mesh_cut(mesh);
    if !cut.enabled || kind == .NONE  return 0;

    target := 0.0;
    to_trile := Vector2.{position.x + 0.5 - cut.focus.x, position.z + 0.5 - cut.focus.z};
    if length(to_trile) <= CUT_RADIUS {
        if position.y >= cut.height  target = 1;
        if kind == .WALL && position.y > cut.floor && dot(to_trile, cut.toward_camera) > CUT_WALL_MARGIN  target = 1;
    }

    x, y, z := cast(s64) floor(position.x), cast(s64) floor(position.y), cast(s64) floor(position.z);
    key := (cast(s64) view.index << 60) | ((x & 0xFFFFF) << 40) | ((y & 0xFFFFF) << 20) | (z & 0xFFFFF);
    fade := table_find_pointer(*scene.cut_fades, key);
    if !fade {
        if target == 0  return 0;
        fade = table_set(*scene.cut_fades, key, 0);
    }
    step := (scene.time - scene.cut_time) / CUT_FADE_TIME;
    fade.* = ifx target > fade.* then min(target, fade.* + step) else max(target, fade.* - step);
    result := fade.*;
    if result == 0  table_remove(*scene.cut_fades, key);
    return result;
}

view_cut_chunks :: (view: View_Id) -> []Chunk_Key {
    keys : [..]Chunk_Key;
    keys.allocator = temp;
    cut := scene.view_cuts[view.index];
    if !cut.enabled  return keys;

    for scene.chunks {
        if chunk_column_distance(it.origin, cut.focus) <= CUT_RADIUS  array_add(*keys, it_index);
    }
    unpack :: (bits: s64) -> s32 { return xx (((bits & 0xFFFFF) ^ 0x80000) - 0x80000); }
    for scene.cut_fades {
        if (it_index >> 60) != view.index  continue;
        array_add_if_unique(*keys, world_to_chunk_coord(unpack(it_index >> 40), unpack(it_index >> 20), unpack(it_index)), chunk_key_compare);
    }
    return keys;
}

trile_mesh_cuttable :: (mesh: Trile_Mesh) -> bool {
    return mesh_cut(mesh) != .NONE;
}

OCCLUDER_WORDS :: CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE / 64;
World_Occluders :: Table(Chunk_Key, *[OCCLUDER_WORDS]u64, chunk_key_hash, chunk_key_compare);

world_occluders :: () -> World_Occluders {
    occluders : World_Occluders;
    occluders.allocator = temp;
    for chunk: scene.chunks {
        bits := New([OCCLUDER_WORDS]u64,, temp);
        for group: chunk.groups {
            if !mesh_occludes(group.mesh)  continue;
            for group.instances {
                cell := cast(s64) it.x + cast(s64) it.y * CHUNK_SIZE + cast(s64) it.z * CHUNK_SIZE * CHUNK_SIZE;
                bits.*[cell >> 6] |= (cast(u64) 1) << cast(u64) (cell & 63);
            }
        }
        table_set(*occluders, it_index, bits);
    }
    return occluders;
}

trile_buried :: (occluders: *World_Occluders, key: Chunk_Key, x: s32, y: s32, z: s32) -> bool {
    occluded :: (occluders: *World_Occluders, key: Chunk_Key, x: s32, y: s32, z: s32) -> bool {
        c := s32.[x, y, z];
        k := s32.[key.x, key.y, key.z];
        for 0..2 {
            if c[it] < 0           { c[it] += CHUNK_SIZE; k[it] -= 1; }
            if c[it] >= CHUNK_SIZE { c[it] -= CHUNK_SIZE; k[it] += 1; }
        }
        bits := table_find_pointer(occluders, .{k[0], k[1], k[2]});
        if !bits  return false;
        cell := cast(s64) c[0] + c[1] * CHUNK_SIZE + c[2] * CHUNK_SIZE * CHUNK_SIZE;
        return ((bits.*.*[cell >> 6] >> cast(u64) (cell & 63)) & 1) != 0;
    }
    return occluded(occluders, key, x - 1, y, z) && occluded(occluders, key, x + 1, y, z)
        && occluded(occluders, key, x, y - 1, z) && occluded(occluders, key, x, y + 1, z)
        && occluded(occluders, key, x, y, z - 1) && occluded(occluders, key, x, y, z + 1);
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

// Lines are drawn in every view; overlay lines ignore depth. The slice must stay
// valid until render().
draw_debug_lines :: (lines: []Debug_Line, overlay: bool) {
    if overlay  scene.overlay_lines = lines;
    else        scene.debug_lines   = lines;
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

View_Cut :: struct {
    enabled       : bool;
    focus         : Vector3;
    floor         : float;     // the trile layer the focus stands in
    height        : float;     // marked triles from here up are hidden
    toward_camera : Vector2;   // horizontal, normalized
}

Scene_Chunk :: struct {
    origin : Vector3;
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

Trile_Vertex :: struct {
    position : Vector3;
    swatch   : u8;
    ao       : u8;   // 0 = fully occluded, 3 = open
    normal   : u8;   // axis * 2, +1 when facing the negative direction
    _        : u8;
}

Scene :: struct {
    chunks : Table(Chunk_Key, Scene_Chunk, chunk_key_hash, chunk_key_compare);
    world_version  : u64;
    mesh_cuts      : [..]Trile_Cut;   // by mesh id
    mesh_occluders : [..]bool;

    views      : [..]View;
    view_proj  : [..]Matrix4;
    reflection_view_proj : [..]Matrix4;
    shadow_view_proj     : [..]Matrix4;
    view_cuts            : [..]View_Cut;
    cut_fades            : Table(s64, float);   // dissolving or cut triles, by view and position
    cut_time             : float;               // when the fades last advanced
    time       : float;
    triles     : [..]Scene_Trile;
    billboards : [..]Scene_Billboard;
    particles  : [..]Scene_Particles;
    ui         : [..]Scene_Ui;

    debug_lines   : []Debug_Line;
    overlay_lines : []Debug_Line;
}

scene_init :: () {
    orientations : [ORIENTATION_COUNT]Matrix3;
    for *orientations {
        m := orientation_matrix(xx it_index).m;
        for r: 0..2  for c: 0..2  it.coef[r][c] = xx m[r][c];
    }
    renderer_init(orientations);
}

scene_shutdown :: () {
    renderer_shutdown();
}

scene_end_frame :: (width: s32, height: s32, time: float) {
    scene.time = time;
    renderer_render(*scene, width, height);
    scene.cut_time = time;
    array_reset_keeping_memory(*scene.views);
    array_reset_keeping_memory(*scene.view_proj);
    array_reset_keeping_memory(*scene.reflection_view_proj);
    array_reset_keeping_memory(*scene.shadow_view_proj);
    array_reset_keeping_memory(*scene.view_cuts);
    array_reset_keeping_memory(*scene.triles);
    array_reset_keeping_memory(*scene.billboards);
    array_reset_keeping_memory(*scene.particles);
    array_reset_keeping_memory(*scene.ui);
    scene.debug_lines   = .[];
    scene.overlay_lines = .[];
}

#scope_file

scene : Scene;

set_mesh_info :: (mesh: Trile_Mesh, cut: Trile_Cut, fills_cell: bool) {
    if scene.mesh_cuts.count <= mesh.id {
        array_resize(*scene.mesh_cuts, mesh.id + 1);
        array_resize(*scene.mesh_occluders, mesh.id + 1);
    }
    scene.mesh_cuts[mesh.id] = cut;
    scene.mesh_occluders[mesh.id] = fills_cell && cut == .NONE;
    scene.world_version += 1;
}

mesh_occludes :: (mesh: Trile_Mesh) -> bool {
    if mesh.id >= scene.mesh_occluders.count  return false;
    return scene.mesh_occluders[mesh.id];
}

trile_fills_cell :: (trile: *Trile) -> bool {
    if !trile.is_opaque  return false;
    for x: 0..15  for y: 0..15  for z: 0..15 {
        id := trile.trixels[x][y][z];
        if !id || g_swatches[id].glass  return false;
    }
    return true;
}

chunk_column_distance :: (origin: Vector3, point: Vector3) -> float {
    dx := max(max(origin.x - point.x, point.x - origin.x - CHUNK_SIZE), 0);
    dz := max(max(origin.z - point.z, point.z - origin.z - CHUNK_SIZE), 0);
    return sqrt(dx * dx + dz * dz);
}

mesh_cut :: (mesh: Trile_Mesh) -> Trile_Cut {
    if mesh.id >= scene.mesh_cuts.count  return .NONE;
    return scene.mesh_cuts[mesh.id];
}

make_view_cut :: (view: View) -> View_Cut {
    cut : View_Cut;
    if !view.cut  return cut;
    cut.enabled = true;
    cut.focus   = view.focus;
    cut.floor   = floor(view.focus.y + 0.5);
    cut.height  = FLOAT32_MAX;
    to_camera := Vector2.{view.camera.position.x - view.focus.x, view.camera.position.z - view.focus.z};
    if length(to_camera) > 0.0001  cut.toward_camera = normalize(to_camera);

    for chunk: scene.chunks {
        if chunk.origin.y + CHUNK_SIZE <= cut.floor || chunk_column_distance(chunk.origin, view.focus) > CUT_RADIUS  continue;
        for group: chunk.groups {
            if mesh_cut(group.mesh) != .ROOF  continue;
            for group.instances {
                p := chunk.origin + Vector3.{xx it.x, xx it.y, xx it.z};
                if p.y <= cut.floor  continue;
                if length(Vector2.{p.x + 0.5 - view.focus.x, p.z + 0.5 - view.focus.z}) > CUT_RADIUS  continue;
                cut.height = min(cut.height, p.y);
            }
        }
    }
    return cut;
}
