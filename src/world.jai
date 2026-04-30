#scope_file

Pool :: #import "Pool";

CHUNK_SIZE :: 32;

Current_World :: struct {
    world : World;
    pool  : Pool.Pool; // A memory pool to allocate stuff for the lifetime of this level being active. For example RDMs.
    valid : bool = false;
};

current_world : Current_World;

#scope_export

Chunk_Key :: struct {
    x: s32;
    y: s32;
    z: s32;
}

operator == :: (a: Chunk_Key, b: Chunk_Key) -> bool {
    return a.x == b.x && a.y == b.y && a.z == b.z;
}

chunk_key_hash :: (key: Chunk_Key) -> u32 {
    h := cast(u32) 2166136261;
    h = (h ^ (cast,no_check(u32) key.x)) * 16777619;
    h = (h ^ (cast,no_check(u32) key.y)) * 16777619;
    h = (h ^ (cast,no_check(u32) key.z)) * 16777619;
    return h;
}

chunk_key_compare :: (a: Chunk_Key, b: Chunk_Key) -> bool {
    return a.x == b.x && a.y == b.y && a.z == b.z;
}

Trile_Instance :: struct {
    x:           u8; // local position within chunk (0..31)
    y:           u8;
    z:           u8;
    orientation: u8; // 0..23, index into cube rotation group
}

Chunk_Trile_Group :: struct {
    trile_name: string;
    instances:  [..]Trile_Instance;
    is_buried:  [..]bool;  // Runtime-only, parallel to instances. Not serialized.
}

Chunk :: struct {
    coord:  Chunk_Key;
    groups: [..]Chunk_Trile_Group;

    sh_probe_grid:  sg_image;  // 192x4096 RGBA16F 2D texture (2 probes/trile/axis)
    sh_valid:       bool;
    sh_dirty:       bool;
}

Editor_Note :: struct {
    position : Chunk_Key;
    text     : string;
}

RDM_DEFAULT_SIZE :: 128;

Rdm_Instance_Override :: struct {
    x           : s32;
    y           : s32;
    z           : s32;
    rdm_enabled : bool;
    rdm_size    : s32; // side in px; 0 means legacy — treat as RDM_DEFAULT_SIZE.
}

// Per-world entry of the global RDM atlas. atlas_rect is normalized UV (x, y, w, h).
Rdm_Atlas_Entry :: struct {
    x, y, z    : s32;
    atlas_rect : Vector4;
}

World :: struct {
    name              : string;
    conf              : World_Config;
    chunks            : Table(Chunk_Key, Chunk, chunk_key_hash, chunk_key_compare);
    emitter_instances : [..]Particle_Emitter_Instance;
    notes             : [..]Editor_Note;
    rdm_overrides     : [..]Rdm_Instance_Override;
    rdm_lookup        : [..]Rdm_Atlas_Entry;   // populated by bake (Step 5) and by loader (Step 6)
}

rdm_get_atlas_rect :: (world: *World, x: s32, y: s32, z: s32) -> (Vector4, bool) {
    for world.rdm_lookup {
        if it.x == x && it.y == y && it.z == z then return it.atlas_rect, true;
    }
    return .{}, false;
}

is_rdm_instance_enabled :: (world: *World, x: s32, y: s32, z: s32) -> bool {
    for world.rdm_overrides {
        if it.x == x && it.y == y && it.z == z then return it.rdm_enabled;
    }
    return false;
}

set_rdm_instance_enabled :: (world: *World, x: s32, y: s32, z: s32, enabled: bool) {
    for *world.rdm_overrides {
        if it.x == x && it.y == y && it.z == z {
            if !enabled {
                array_ordered_remove_by_index(*world.rdm_overrides, it_index);
            } else {
                it.rdm_enabled = true;
                if it.rdm_size == 0 then it.rdm_size = RDM_DEFAULT_SIZE;
            }
            return;
        }
    }
    if enabled {
        array_add(*world.rdm_overrides, .{x=x, y=y, z=z, rdm_enabled=true, rdm_size=RDM_DEFAULT_SIZE});
    }
}

get_rdm_instance_size :: (world: *World, x: s32, y: s32, z: s32) -> s32 {
    for world.rdm_overrides {
        if it.x == x && it.y == y && it.z == z {
            if !it.rdm_enabled then return 0;
            return ifx it.rdm_size > 0 then it.rdm_size else RDM_DEFAULT_SIZE;
        }
    }
    return 0;
}

set_rdm_instance_size :: (world: *World, x: s32, y: s32, z: s32, size: s32) {
    for *world.rdm_overrides {
        if it.x == x && it.y == y && it.z == z {
            it.rdm_size = size;
            return;
        }
    }
}

RDM_SIZE_LADDER :: s32.[32, 64, 128, 256, 512, 1024, 2048, 4096];

rdm_cycle_size :: (cur: s32, dir: s32) -> s32 {
    idx : s32 = 2;
    for RDM_SIZE_LADDER {
        if it == cur { idx = cast(s32) it_index; break; }
    }
    idx += dir;
    if idx < 0 then idx = 0;
    if idx >= cast(s32) RDM_SIZE_LADDER.count then idx = cast(s32) RDM_SIZE_LADDER.count - 1;
    return RDM_SIZE_LADDER[idx];
}

// Convert a world-space integer position to chunk coordinate.
world_to_chunk_coord :: (wx: s32, wy: s32, wz: s32) -> Chunk_Key {
    return .{
        x = floor_div(wx, CHUNK_SIZE),
        y = floor_div(wy, CHUNK_SIZE),
        z = floor_div(wz, CHUNK_SIZE),
    };
}

// Convert a world-space integer position to local position within its chunk (0..31).
world_to_local :: (wx: s32, wy: s32, wz: s32) -> (u8, u8, u8) {
    return cast(u8) floor_mod(wx, CHUNK_SIZE),
           cast(u8) floor_mod(wy, CHUNK_SIZE),
           cast(u8) floor_mod(wz, CHUNK_SIZE);
}

// Convert chunk coord + local position back to world position.
chunk_local_to_world :: (chunk: Chunk_Key, lx: u8, ly: u8, lz: u8) -> (s32, s32, s32) {
    return chunk.x * CHUNK_SIZE + cast(s32) lx,
           chunk.y * CHUNK_SIZE + cast(s32) ly,
           chunk.z * CHUNK_SIZE + cast(s32) lz;
}

// Floor division that handles negatives correctly (rounds toward -infinity).
floor_div :: (a: s32, b: s32) -> s32 {
    d := a / b;
    r := a % b;
    if (r != 0) && ((r ^ b) < 0) then d -= 1;
    return d;
}

// Floor modulo that always returns a non-negative result.
floor_mod :: (a: s32, b: s32) -> s32 {
    r := a % b;
    if (r != 0) && ((r ^ b) < 0) then r += b;
    return r;
}

nworld :: (name: string) {
    unload_current_world();
    current_world.world = .{};
    current_world.world.name = sprint("%", name);
    current_world.valid = true;
} @Command;

lworld :: (name: string) {
    load_world(name);
} @Command;

init_world_system :: () {
    Pool.set_allocators(*current_world.pool);
}

unload_current_world :: () {
    if !current_world.valid then return;
    rdm_loader_cancel_all();
    for *chunk: current_world.world.chunks {
        for *group: chunk.groups {
            array_free(group.instances);
            array_free(group.is_buried);
        }
        array_free(chunk.groups);
    }
    deinit(*current_world.world.chunks);
    array_free(current_world.world.rdm_lookup);
    Pool.reset(*current_world.pool);
    current_world.valid = false;
}

set_loaded_world :: (world: World) {
    unload_current_world();
    current_world.world = world;
    current_world.valid = true;
    resolve_emitter_definitions(*current_world.world);
    for *chunk: current_world.world.chunks {
        recompute_buried_for_chunk(*current_world.world, chunk);
    }
}

is_cell_opaque :: (name: string) -> bool {
    if name.count == 0  return false;
    t, ok := get_trile(name);
    if !ok  return false;
    return t.is_opaque;
}

trile_at_world :: (world: *World, wx: s32, wy: s32, wz: s32) -> string {
    key := world_to_chunk_coord(wx, wy, wz);
    chunk := table_find_pointer(*world.chunks, key);
    if !chunk  return "";
    lx, ly, lz := world_to_local(wx, wy, wz);
    for *group: chunk.groups {
        for inst: group.instances {
            if inst.x == lx && inst.y == ly && inst.z == lz {
                return group.trile_name;
            }
        }
    }
    return "";
}

BURIED_DIRS :: s32.[ 1,0,0,  -1,0,0,  0,1,0,  0,-1,0,  0,0,1,  0,0,-1 ];

compute_buried_at_world :: (world: *World, wx: s32, wy: s32, wz: s32) -> bool {
    for axis: 0..5 {
        nwx := wx + BURIED_DIRS[axis*3+0];
        nwy := wy + BURIED_DIRS[axis*3+1];
        nwz := wz + BURIED_DIRS[axis*3+2];
        if !is_cell_opaque(trile_at_world(world, nwx, nwy, nwz))  return false;
    }
    return true;
}

recompute_buried_for_chunk :: (world: *World, chunk: *Chunk) {
    // Build an O(1) local lookup grid (32^3 trile names) for this chunk so the
    // common in-chunk neighbor case is a single index lookup. Cross-chunk
    // neighbors fall back to trile_at_world.
    GRID :: CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE;
    grid: [GRID] string;
    grid_data := grid;
    for *group: chunk.groups {
        for inst: group.instances {
            idx := cast(int)inst.x + CHUNK_SIZE * (cast(int)inst.y + CHUNK_SIZE * cast(int)inst.z);
            grid_data[idx] = group.trile_name;
        }
    }

    for *group: chunk.groups {
        array_resize(*group.is_buried, group.instances.count);
        for inst, i: group.instances {
            wx, wy, wz := chunk_local_to_world(chunk.coord, inst.x, inst.y, inst.z);
            buried := true;
            for axis: 0..5 {
                nwx := wx + BURIED_DIRS[axis*3+0];
                nwy := wy + BURIED_DIRS[axis*3+1];
                nwz := wz + BURIED_DIRS[axis*3+2];
                neighbor_name: string;
                nkey := world_to_chunk_coord(nwx, nwy, nwz);
                if nkey == chunk.coord {
                    nlx, nly, nlz := world_to_local(nwx, nwy, nwz);
                    nidx := cast(int)nlx + CHUNK_SIZE * (cast(int)nly + CHUNK_SIZE * cast(int)nlz);
                    neighbor_name = grid_data[nidx];
                } else {
                    neighbor_name = trile_at_world(world, nwx, nwy, nwz);
                }
                if !is_cell_opaque(neighbor_name) {
                    buried = false;
                    break;
                }
            }
            group.is_buried[i] = buried;
        }
    }
}

recompute_buried_at_cell :: (world: *World, wx: s32, wy: s32, wz: s32) {
    key := world_to_chunk_coord(wx, wy, wz);
    chunk := table_find_pointer(*world.chunks, key);
    if !chunk  return;
    lx, ly, lz := world_to_local(wx, wy, wz);
    for *group: chunk.groups {
        for inst, i: group.instances {
            if inst.x == lx && inst.y == ly && inst.z == lz {
                if group.is_buried.count != group.instances.count  array_resize(*group.is_buried, group.instances.count);
                group.is_buried[i] = compute_buried_at_world(world, wx, wy, wz);
                return;
            }
        }
    }
}

invalidate_buried_around :: (world: *World, wx: s32, wy: s32, wz: s32) {
    recompute_buried_at_cell(world, wx, wy, wz);
    for axis: 0..5 {
        recompute_buried_at_cell(world, wx + BURIED_DIRS[axis*3+0], wy + BURIED_DIRS[axis*3+1], wz + BURIED_DIRS[axis*3+2]);
    }
}

resolve_emitter_definitions :: (world: *World) {
    for *inst: world.emitter_instances {
        inst.definition = get_emitter_def(inst.definition_name);
    }
}

clear_world :: () {
    if !current_world.valid then return;
    for *chunk: current_world.world.chunks {
        for *group: chunk.groups {
            array_free(group.instances);
            array_free(group.is_buried);
        }
        array_free(chunk.groups);
    }
    deinit(*current_world.world.chunks);
    current_world.world.chunks = .{};
} @Command

get_current_world :: () -> *Current_World {
    return *current_world;
}

// --- Binary serialization (.world format) ---

WORLD_MAGIC :: u32.[0x4C575254][0]; // "TRWL" as little-endian u32
WORLD_VERSION :: cast(u16) 3;

World_Json :: struct {
    version       : s32;
    name          : string;
    config        : World_Json_Config;
    chunks        : [..]World_Json_Chunk;
    emitters      : [..]World_Json_Emitter;
    notes         : [..]World_Json_Note;
    rdm_overrides : [..]World_Json_Rdm_Override;
}

World_Json_Config :: struct {
    skyBase              : [3]float;
    skyTop               : [3]float;
    sunDisk              : [3]float;
    horizonHalo          : [3]float;
    sunHalo              : [3]float;
    sunLightColor        : [3]float;
    sunPosition          : [3]float;
    sunIntensity         : float;
    skyIntensity         : float;
    hasClouds            : s32;
    planeHeight          : float;
    animatePlaneHeight   : s32;
    waterColor           : [3]float;
    deepColor            : [3]float;
    waterShininess       : float;
}

World_Json_Chunk :: struct {
    x          : s32;
    y          : s32;
    z          : s32;
    offset     : s32;
    size       : s32;
}

World_Json_Emitter :: struct {
    definition_name : string;
    position        : [3]float;
    offset          : [3]float;
}

World_Json_Note :: struct {
    text     : string;
    position : [3]s32;
}

World_Json_Rdm_Override :: struct {
    x           : s32;
    y           : s32;
    z           : s32;
    rdm_enabled : bool;
    rdm_size    : s32;
}

// World_Config serialized as a fixed-size binary blob.
// We serialize it field-by-field to avoid padding issues.
World_Config_Binary :: struct {
    sky_base:        [3]float;
    sky_top:         [3]float;
    sun_disk:        [3]float;
    horizon_halo:    [3]float;
    sun_halo:        [3]float;
    sun_light_color: [3]float;
    sun_position:    [3]float;
    sun_intensity:   float;
    sky_intensity:   float;
    has_clouds:      s32;
    plane_height:    float;
    animate_plane_height: s32;
    water_color:         [3]float;
    deep_color:          [3]float;
    water_shininess:     float;
}

world_config_to_binary :: (conf: *World_Config) -> World_Config_Binary {
    b: World_Config_Binary;
    b.sky_base        = conf.skyBase.component;
    b.sky_top         = conf.skyTop.component;
    b.sun_disk        = conf.sunDisk.component;
    b.horizon_halo    = conf.horizonHalo.component;
    b.sun_halo        = conf.sunHalo.component;
    b.sun_light_color = conf.sunLightColor.component;
    b.sun_position    = conf.sunPosition.component;
    b.sun_intensity   = conf.sunIntensity;
    b.sky_intensity   = conf.skyIntensity;
    b.has_clouds      = conf.hasClouds;
    b.plane_height    = conf.planeHeight;
    b.animate_plane_height = conf.animatePlaneHeight;
    b.water_color         = conf.waterColor.component;
    b.deep_color          = conf.deepColor.component;
    b.water_shininess     = conf.waterShininess;
    return b;
}

world_config_from_binary :: (b: *World_Config_Binary) -> World_Config {
    conf: World_Config;
    conf.skyBase.component       = b.sky_base;
    conf.skyTop.component        = b.sky_top;
    conf.sunDisk.component       = b.sun_disk;
    conf.horizonHalo.component   = b.horizon_halo;
    conf.sunHalo.component       = b.sun_halo;
    conf.sunLightColor.component = b.sun_light_color;
    conf.sunPosition.component   = b.sun_position;
    conf.sunIntensity            = b.sun_intensity;
    conf.skyIntensity            = b.sky_intensity;
    conf.hasClouds               = b.has_clouds;
    conf.planeHeight             = b.plane_height;
    conf.animatePlaneHeight      = b.animate_plane_height;
    conf.waterColor.component    = b.water_color;
    conf.deepColor.component     = b.deep_color;
    conf.waterShininess          = b.water_shininess;
    return conf;
}

write_bytes :: (builder: *String_Builder, data: *void, count: s64) {
    s: string;
    s.data = data;
    s.count = count;
    append(builder, s);
}

write_value :: (builder: *String_Builder, value: $T) {
    v := value;
    write_bytes(builder, *v, size_of(T));
}

read_value :: (data: []u8, cursor: *s64, $T: Type) -> T {
    result: T;
    assert(cursor.* + size_of(T) <= data.count, "read_value: out of bounds");
    memcpy(*result, data.data + cursor.*, size_of(T));
    cursor.* += size_of(T);
    return result;
}

read_string :: (data: []u8, cursor: *s64, len: s64) -> string {
    assert(cursor.* + len <= data.count, "read_string: out of bounds");
    result := sprint("%", string.{count = len, data = data.data + cursor.*});
    cursor.* += len;
    return result;
}

sworld :: () {
    if !current_world.valid {
        log_error("Cannot save: no world loaded");
        return;
    }
    #if OS != .WASM {
        file :: #import "File";
        name := current_world.world.name;
        dir := tprint("%/worlds/%", GAME_RESOURCES_DIR, name);
        file.make_directory_if_it_does_not_exist(dir, recursive = true);
        json_data, bin_data := save_world(*current_world.world);
        file.write_entire_file(tprint("%/world.json", dir), json_data);
        file.write_entire_file(tprint("%/chunks.bin", dir), bin_data);
        log_info("Saved world '%' (json=% bytes, bin=% bytes)", name, json_data.count, bin_data.count);
    }
} @Command

world_config_to_json :: (conf: *World_Config) -> World_Json_Config {
    jc: World_Json_Config;
    jc.skyBase            = conf.skyBase.component;
    jc.skyTop             = conf.skyTop.component;
    jc.sunDisk            = conf.sunDisk.component;
    jc.horizonHalo        = conf.horizonHalo.component;
    jc.sunHalo            = conf.sunHalo.component;
    jc.sunLightColor      = conf.sunLightColor.component;
    jc.sunPosition        = conf.sunPosition.component;
    jc.sunIntensity       = conf.sunIntensity;
    jc.skyIntensity       = conf.skyIntensity;
    jc.hasClouds          = conf.hasClouds;
    jc.planeHeight        = conf.planeHeight;
    jc.animatePlaneHeight = conf.animatePlaneHeight;
    jc.waterColor         = conf.waterColor.component;
    jc.deepColor          = conf.deepColor.component;
    jc.waterShininess     = conf.waterShininess;
    return jc;
}

world_config_from_json :: (jc: *World_Json_Config) -> World_Config {
    conf: World_Config;
    conf.skyBase.component       = jc.skyBase;
    conf.skyTop.component        = jc.skyTop;
    conf.sunDisk.component       = jc.sunDisk;
    conf.horizonHalo.component   = jc.horizonHalo;
    conf.sunHalo.component       = jc.sunHalo;
    conf.sunLightColor.component = jc.sunLightColor;
    conf.sunPosition.component   = jc.sunPosition;
    conf.sunIntensity            = jc.sunIntensity;
    conf.skyIntensity            = jc.skyIntensity;
    conf.hasClouds               = jc.hasClouds;
    conf.planeHeight             = jc.planeHeight;
    conf.animatePlaneHeight      = jc.animatePlaneHeight;
    conf.waterColor.component    = jc.waterColor;
    conf.deepColor.component     = jc.deepColor;
    conf.waterShininess          = ifx jc.waterShininess > 0 then jc.waterShininess else 64.0;
    return conf;
}

save_world :: (world: *World) -> (json: string, chunks_bin: string) {
    bin_builder: String_Builder;

    Chunk_Save_Entry :: struct {
        coord: Chunk_Key;
        offset: s32;
        size: s32;
    }
    chunk_entries: [..]Chunk_Save_Entry;
    chunk_entries.allocator = temp;

    running_offset: s32 = 0;
    for chunk: world.chunks {
        if chunk.groups.count == 0 then continue;
        chunk_builder: String_Builder;
        chunk_builder.allocator = temp;

        num_types := cast(u16) chunk.groups.count;
        write_value(*chunk_builder, num_types);

        for group: chunk.groups {
            gname_len := cast(u16) group.trile_name.count;
            write_value(*chunk_builder, gname_len);
            append(*chunk_builder, group.trile_name);
            count := cast(u16) group.instances.count;
            write_value(*chunk_builder, count);
            for inst: group.instances {
                write_value(*chunk_builder, inst);
            }
        }
        chunk_data := builder_to_string(*chunk_builder,, temp);
        data_size := cast(s32) chunk_data.count;

        array_add(*chunk_entries, .{
            coord = chunk.coord,
            offset = running_offset,
            size = data_size,
        });
        append(*bin_builder, chunk_data);
        running_offset += data_size;
    }

    wj: World_Json;
    wj.version = 4;
    wj.name = world.name;
    wj.config = world_config_to_json(*world.conf);

    for entry: chunk_entries {
        jc: World_Json_Chunk;
        jc.x = entry.coord.x;
        jc.y = entry.coord.y;
        jc.z = entry.coord.z;
        jc.offset = entry.offset;
        jc.size = entry.size;
        array_add(*wj.chunks, jc);
    }

    for inst: world.emitter_instances {
        je: World_Json_Emitter;
        je.definition_name = inst.definition_name;
        je.position = inst.position.component;
        je.offset   = inst.offset.component;
        array_add(*wj.emitters, je);
    }

    for note: world.notes {
        jn: World_Json_Note;
        jn.text = note.text;
        jn.position = .[note.position.x, note.position.y, note.position.z];
        array_add(*wj.notes, jn);
    }

    for ov: world.rdm_overrides {
        size := ifx ov.rdm_size > 0 then ov.rdm_size else RDM_DEFAULT_SIZE;
        array_add(*wj.rdm_overrides, .{x=ov.x, y=ov.y, z=ov.z, rdm_enabled=ov.rdm_enabled, rdm_size=size});
    }

    json_str := Jaison.json_write_string(wj, " ");
    return json_str, builder_to_string(*bin_builder);
}

load_world_from_json :: (json_str: string, chunk_bin: []u8) -> (World, bool) {
    world: World;

    success, wj := Jaison.json_parse_string(json_str, World_Json);
    if !success {
        log_error("Failed to parse world JSON");
        return world, false;
    }

    world.name = sprint("%", wj.name);
    world.conf = world_config_from_json(*wj.config);

    for jc: wj.chunks {
        chunk: Chunk;
        chunk.coord = .{x = jc.x, y = jc.y, z = jc.z};

        offset := cast(s64) jc.offset;
        size   := cast(s64) jc.size;
        if offset + size > chunk_bin.count {
            log_error("Chunk data out of bounds: offset=%, size=%, bin=%", offset, size, chunk_bin.count);
            return world, false;
        }

        chunk_data: []u8;
        chunk_data.data = chunk_bin.data + offset;
        chunk_data.count = size;
        chunk_cursor: s64 = 0;

        num_types := read_value(chunk_data, *chunk_cursor, u16);
        for t: 0..cast(s64)num_types-1 {
            group: Chunk_Trile_Group;
            gname_len := cast(s64) read_value(chunk_data, *chunk_cursor, u16);
            group.trile_name = read_string(chunk_data, *chunk_cursor, gname_len);
            count := cast(s64) read_value(chunk_data, *chunk_cursor, u16);
            for i: 0..count-1 {
                inst := read_value(chunk_data, *chunk_cursor, Trile_Instance);
                array_add(*group.instances, inst);
            }
            array_add(*chunk.groups, group);
        }
        table_set(*world.chunks, chunk.coord, chunk);
    }

    for je: wj.emitters {
        inst: Particle_Emitter_Instance;
        inst.definition_name = sprint("%", je.definition_name);
        inst.position.component = je.position;
        inst.offset.component   = je.offset;
        inst.active = true;
        array_add(*world.emitter_instances, inst);
    }

    for jn: wj.notes {
        note: Editor_Note;
        note.text = sprint("%", jn.text);
        note.position = .{x = jn.position[0], y = jn.position[1], z = jn.position[2]};
        array_add(*world.notes, note);
    }

    for jov: wj.rdm_overrides {
        size := ifx jov.rdm_size > 0 then jov.rdm_size else RDM_DEFAULT_SIZE;
        array_add(*world.rdm_overrides, .{x=jov.x, y=jov.y, z=jov.z, rdm_enabled=jov.rdm_enabled, rdm_size=size});
    }

    return world, true;
}

load_world_from_data :: (data: []u8) -> (World, bool) {
    world: World;
    cursor: s64 = 0;

    if data.count < size_of(u32) + size_of(u16) {
        log_error("World file too small");
        return world, false;
    }

    // Header
    magic := read_value(data, *cursor, u32);
    if magic != WORLD_MAGIC {
        log_error("Invalid world file magic");
        return world, false;
    }

    version := read_value(data, *cursor, u16);
    if version != 1 && version != 2 && version != 3 {
        log_error("Unsupported world version: %", version);
        return world, false;
    }

    name_len := cast(s64) read_value(data, *cursor, u16);
    world.name = read_string(data, *cursor, name_len);

    // World config
    conf_bin := read_value(data, *cursor, World_Config_Binary);
    world.conf = world_config_from_binary(*conf_bin);

    num_chunks := read_value(data, *cursor, u32);

    // Read chunk table
    Chunk_Table_Entry :: struct {
        coord:  Chunk_Key;
        offset: u32;
        size:   u32;
    }

    chunk_table: [..]Chunk_Table_Entry;
    chunk_table.allocator = temp;
    for i: 0..cast(s64)num_chunks-1 {
        entry: Chunk_Table_Entry;
        entry.coord.x = read_value(data, *cursor, s32);
        entry.coord.y = read_value(data, *cursor, s32);
        entry.coord.z = read_value(data, *cursor, s32);
        entry.offset  = read_value(data, *cursor, u32);
        entry.size    = read_value(data, *cursor, u32);
        array_add(*chunk_table, entry);
    }

    // Read chunk data
    for entry: chunk_table {
        chunk_cursor: s64 = cast(s64) entry.offset;
        chunk: Chunk;
        chunk.coord = entry.coord;

        num_types := read_value(data, *chunk_cursor, u16);
        for t: 0..cast(s64)num_types-1 {
            group: Chunk_Trile_Group;
            gname_len := cast(s64) read_value(data, *chunk_cursor, u16);
            group.trile_name = read_string(data, *chunk_cursor, gname_len);
            count := cast(s64) read_value(data, *chunk_cursor, u16);
            for i: 0..count-1 {
                inst := read_value(data, *chunk_cursor, Trile_Instance);
                array_add(*group.instances, inst);
            }
            array_add(*chunk.groups, group);
        }
        table_set(*world.chunks, chunk.coord, chunk);
    }

    if chunk_table.count > 0 {
        last := chunk_table[chunk_table.count - 1];
        cursor = cast(s64)(last.offset + last.size);
    }

    if version >= 2 && cursor < data.count {
        num_emitters := cast(s64) read_value(data, *cursor, u16);
        for i: 0..num_emitters-1 {
            inst: Particle_Emitter_Instance;
            name_len := cast(s64) read_value(data, *cursor, u16);
            inst.definition_name = read_string(data, *cursor, name_len);
            inst.position.x = read_value(data, *cursor, float);
            inst.position.y = read_value(data, *cursor, float);
            inst.position.z = read_value(data, *cursor, float);
            inst.active = true;
            array_add(*world.emitter_instances, inst);
        }
    }

    if version >= 3 && cursor < data.count {
        num_notes := cast(s64) read_value(data, *cursor, u16);
        for i: 0..num_notes-1 {
            note: Editor_Note;
            text_len := cast(s64) read_value(data, *cursor, u16);
            note.text = read_string(data, *cursor, text_len);
            note.position.x = read_value(data, *cursor, s32);
            note.position.y = read_value(data, *cursor, s32);
            note.position.z = read_value(data, *cursor, s32);
            array_add(*world.notes, note);
        }
    }

    return world, true;
}


World_Config :: struct {
    // All of the @Notes are for the autoedit functionality.
    skyBase       : Vector3 = .{0.38, 0.81, 0.95}; @Color
    skyTop        : Vector3 = .{0.17, 0.4, 0.95}; @Color
    sunDisk       : Vector3 = .{1.0, 1.0, 1.0}; @Color
    horizonHalo   : Vector3 = .{1.0, 1.0, 1.0}; @Color
    sunHalo       : Vector3 = .{1.0, 1.0, 1.0}; @Color
    sunLightColor : Vector3 = .{1.0, 1.0, 1.0}; @Color
    sunPosition   : Vector3 = #run normalize(Vector3.{0.2, 0.3, 0.4});
    sunIntensity  : float = 1.0; @Slider,0,4,0.1
    skyIntensity  : float = 0.3; @Slider,0,5,0.1

    hasClouds     : s32 = 1; @Slider,0,1,1

    planeHeight   : float = 0.0; @Slider,0,3,0.1
    animatePlaneHeight : s32 = 1; @Slider,0,1,1
    waterColor    : Vector3 = .{1.0, 1.0, 1.0}; @Color // @ToDo: sensible default values.
    deepColor     : Vector3 = .{1.0, 1.0, 1.0}; @Color // @ToDo: sensible default values.
    waterShininess      : float = 64.0; @Slider,1,512,8
    hsv_lighting        : s32   = 1;    @Slider,0,1,1

    // ambientColor     : Vector3 = .{1.0, 1.0, 1.0}; @Color
    // ambientIntensity : float   = 0.3; @Slider,0,3,0.1

}

// Copies over all the fields of our world config into a given shader type.
// Requires that the shader type has all of the fields the world config has.
world_config_to_shader_type :: (wc: *World_Config, data: *$T) {
    generate_copy_code :: () -> string {
        builder : String_Builder;
        ti_src := type_info(World_Config);
        ti_dst := type_info(T);
        for src_member: ti_src.members {
            has_field := false;
            for dst_member: ti_dst.members {
                if dst_member.name == src_member.name { has_field = true; break; }
            }
            if !has_field  continue;
            if src_member.type == type_info(Vector3) then print_to_builder(*builder, "data.% = wc.%.component;\n", src_member.name, src_member.name);
            else print_to_builder(*builder, "data.% = wc.%;\n", src_member.name, src_member.name);
        }
        return builder_to_string(*builder);
    }
    data.time = xx get_time();
    #insert #run,stallable generate_copy_code();
}

effective_plane_height :: (wc: *World_Config) -> float {
    if wc.animatePlaneHeight {
        return wc.planeHeight * (1.0 + sin(cast(float)get_time() * 0.5) * 0.1);
    }
    return wc.planeHeight;
}

draw_world_picker :: (r_in: GR.Rect, theme: *GR.Overall_Theme) {
    r   := r_in;
	r.h = ui_h(4,4);

	#if OS != .WASM {
		File_Utilities :: #import "File_Utilities";

		world_names: [..]string;
		world_names.allocator = temp;

		dir_visitor :: (info: *File_Utilities.File_Visit_Info, names: *[..]string) {
			if info.short_name == "world.json" || info.short_name == "index.world" {
				#import "String";
				suffix := ifx info.short_name == "world.json" then "/world.json" else "/index.world";
				_, left, _ := split_from_right(info.full_name, suffix);
				_, _, name := split_from_right(left, "/");
				if name.count > 0 {
					for names.* { if it == name then return; }
					array_add(names, name);
				}
			}
		}

		File_Utilities.visit_files(tprint("%/worlds", GAME_RESOURCES_DIR), true, *world_names, dir_visitor);

		count := 0;
		for name: world_names {
			is_current := current_world.valid && current_world.world.name == name;
			if GR.button(r, name, *t_button_selectable(theme, is_current), count) {
				lworld(name);
			}
			count += 1;
			r.y += r.h;
		}
	} else {
		if current_world.valid {
			GR.label(r, tprint("Current: %", current_world.world.name), *theme.label_theme);
		} else {
			GR.label(r, "No world loaded", *theme.label_theme);
		}
	}
}
