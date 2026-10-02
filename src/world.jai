#scope_file

Pool :: #import "Pool";

CHUNK_SIZE :: 32;

Current_World :: struct {
    world : World;
    pool  : Pool.Pool; // A memory pool to allocate stuff for the lifetime of this level being active.
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
    trile_name : string;
    instances  : [..]Trile_Instance;
}


Chunk :: struct {
    coord:  Chunk_Key;
    groups: [..]Chunk_Trile_Group;

    // This goes x,z,y so y is the bitmask because
    // that is useful when we're checking for ground under
    // entities
    occupancy_mask : [32][32]u32;
    // We want to be easily able to identify stairs from the chunk.
    stairs_mask    : [32][32]u32;
}

Occupancy_State :: enum {
    FREE;
    OCCUPIED;
    OCCUPIED_STAIRS;
}

// @Note: these are local coords inside the chunk
chunk_get_occupancy_mask_at :: inline (chunk: *Chunk, lx: u32, ly: u32, lz: u32) -> Occupancy_State {
    if (chunk.occupancy_mask[lx][lz] & (cast(u32)1 << ly)) != 0 {
        if (chunk.stairs_mask[lx][lz] & (cast(u32)1 << ly)) != 0 then return .OCCUPIED_STAIRS;
        return .OCCUPIED;
    }
    return .FREE;
}

// @Note: these are local coords inside the chunk
chunk_set_occupancy_mask_at :: inline (chunk: *Chunk, lx: u32, ly: u32, lz: u32, occupied: Occupancy_State) {
    if occupied != .FREE {
        if occupied == .OCCUPIED_STAIRS {
            chunk.occupancy_mask[lx][lz] |= (cast(u32)1 << ly);
            chunk.stairs_mask[lx][lz] |= (cast(u32)1 << ly);
        } else {
            chunk.occupancy_mask[lx][lz] |= (cast(u32)1 << ly);
            chunk.stairs_mask[lx][lz] &= ~(cast(u32)1 << ly);
        }
    } else {
        chunk.occupancy_mask[lx][lz] &= ~(cast(u32)1 << ly);
        chunk.stairs_mask[lx][lz] &= ~(cast(u32)1 << ly);
    }
}

chunk_clear_full_occupancy_mask :: (chunk: *Chunk) {
    for i: 0..31 {
        for j: 0..31 {
            chunk.occupancy_mask[cast(u32)i][cast(u32)j] = 0;
            chunk.stairs_mask[cast(u32)i][cast(u32)j] = 0;
        }
    }
}

Editor_Note :: struct {
    position : Chunk_Key;
    text     : string;
}


World :: struct {
    name              : string;
    conf              : World_Config;
    environment       : Environment;
    chunks            : Table(Chunk_Key, Chunk, chunk_key_hash, chunk_key_compare);
    emitter_instances : [..]Particle_Emitter_Instance;
    notes             : [..]Editor_Note;
    entities          : [..]*Entity;
    next_entity_id    : u32;
}

// The mask state a colliding trile instance contributes. Stairs only count as
// stairs when upright.
occupancy_state_for :: inline (trile: *Trile, orientation: u8) -> Occupancy_State {
    if trile.is_stairs && orientation < 4  return .OCCUPIED_STAIRS;
    return .OCCUPIED;
}

calculate_and_set_chunk_occupancy_mask :: (chunk: *Chunk) {
    chunk_clear_full_occupancy_mask(chunk);
    
    for group: chunk.groups {
        trile, ok := get_trile(group.trile_name);
        if !ok || trile.skip_collision then continue;
        for instance : group.instances {
            chunk_set_occupancy_mask_at(chunk, instance.x, instance.y, instance.z, occupancy_state_for(trile, instance.orientation));
        }
    }
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

// Copy another world's config (sky, sun, water, ...) onto the loaded world, so a
// new level can start from an existing look instead of retyping the values.
copy_world_info :: (name: string) {
    if !current_world.valid {
        log_error("Cannot copy: no world loaded");
        return;
    }
    #if OS != .WASM {
        file :: #import "File";
        path := tprint("%/worlds/%/world.json", GAME_RESOURCES_DIR, name);
        json_str, read_ok := file.read_entire_file(path,, allocator = temp);
        if !read_ok {
            log_error("Cannot copy: failed to read '%'", path);
            return;
        }

        parse_ok, wj := Jaison.json_parse_string(json_str, World_Json,, temp);
        if !parse_ok {
            log_error("Cannot copy: failed to parse world '%'", name);
            return;
        }

        current_world.world.conf = world_config_from_json(*wj.config);
        log_info("Copied world config from '%'", name);
    }
} @Command

init_world_system :: () {
    Pool.set_allocators(*current_world.pool);
}

unload_current_world :: () {
    if !current_world.valid then return;
    world_clear();
    for *chunk: current_world.world.chunks {
        for *group: chunk.groups {
            array_free(group.instances);
        }
        array_free(chunk.groups);
    }
    deinit(*current_world.world.chunks);
    free_all_entities(*current_world.world);
    // Entity ids restart per world, so a stale editor selection would latch onto
    // an unrelated entity in the next one.
    #if OS != .WASM { level_editor_clear_entity_selection(); }
    Pool.reset(*current_world.pool);
    current_world.valid = false;
}

set_loaded_world :: (world: World) {
    unload_current_world();
    current_world.world = world;
    current_world.valid = true;
    resolve_emitter_definitions(*current_world.world);
    for *chunk: current_world.world.chunks  upload_chunk(chunk);
}

// Hands a chunk's triles to the renderer. Call after loading or editing it.
upload_chunk :: (chunk: *Chunk) {
    groups: [..]World_Group;
    groups.allocator = temp;
    for chunk.groups {
        mesh, ok := get_trile_mesh(it.trile_name);
        if ok  array_add(*groups, .{mesh, it.instances});
    }
    world_set_chunk(chunk.coord, groups);
}

get_note_locations :: (note : string) -> []Vector3 {
    result: [..]Vector3;
    print("Looking for notes %\n", current_world.world.name);
    for n: current_world.world.notes {
        print("COMP: % %\n", n.text, note);
        if n.text == note {
            v: Vector3 = .{cast(float)n.position.x, cast(float)n.position.y, cast(float)n.position.z};
            array_add(*result, v);
        }
    }
    return result;
}

trile_instance_at_chunk :: (chunk: *Chunk, lx: s32, ly: s32, lz: s32) -> (bool, Trile_Instance, *Trile) {
    for group : chunk.groups {
        for instance : group.instances {
            if instance.x == lx && instance.y == ly && instance.z == lz {
                trile, ok := get_trile(group.trile_name);
                if !ok {
                    print("Error: did not find matching trile for group %\n", group.trile_name);
                    return false, .{}, null;
                }
                return true, instance, trile;
            }
        }
    }
    return false, .{}, null;
}

resolve_emitter_definitions :: (world: *World) {
    for *inst: world.emitter_instances {
        inst.definition = get_emitter_def(inst.definition_name);
    }
    for e: world.entities {
        for *inst: e.emitters {
            inst.definition = get_emitter_def(inst.definition_name);
        }
    }
}

clear_world :: () {
    if !current_world.valid then return;
    world_clear();
    for *chunk: current_world.world.chunks {
        for *group: chunk.groups {
            array_free(group.instances);
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
    entities      : [..]World_Json_Entity;
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
    waterReflectivity    : float = 0.0;
    waterDistortion      : float = 0.007;
    indoor               : s32;
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

// Entity fields are stored as name/value string pairs rather than a typed
// object, so that adding, removing or renaming a field never breaks loading:
// unknown names are skipped and missing ones keep their struct defaults.
World_Json_Entity :: struct {
    type        : string;   // entity type name, so reordering ENTITY_TYPES is safe
    id          : u32;
    position    : [3]float;
    orientation : u8;       // absent in worlds saved before entities could rotate
    fields      : [..]Entity_Field;
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
    jc.waterReflectivity  = conf.waterReflectivity;
    jc.waterDistortion    = conf.waterDistortion;
    jc.indoor             = conf.indoor;
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
    conf.waterReflectivity       = jc.waterReflectivity;
    conf.waterDistortion         = jc.waterDistortion;
    conf.indoor                  = jc.indoor;
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
    wj.version = 5;
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

    for e: world.entities {
        je: World_Json_Entity;
        je.type        = entity_type_name(e.type);
        je.id          = e.id;
        je.position    = e.position.component;
        je.orientation = e.orientation;
        for f: entity_fields_to_strings(e)  array_add(*je.fields, f);
        array_add(*wj.entities, je);
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
        calculate_and_set_chunk_occupancy_mask(*chunk);
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

    for je: wj.entities {
        e := spawn_entity(*world, je.type, .{je.position[0], je.position[1], je.position[2]}, je.orientation);
        if e == null then continue;  // unknown type; spawn_entity logged it
        e.id = je.id;
        if je.id >= world.next_entity_id then world.next_entity_id = je.id + 1;
        for f: je.fields {
            entity_apply_field(e, f.name, f.value);
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
    waterReflectivity   : float = 0.0;  @Slider,0,1,0.05
    waterDistortion     : float = 0.007; @Slider,0,0.05,0.001
    hsv_lighting        : s32   = 1;    @Slider,0,1,1
    // Indoor levels: no sun shadows (faces toward the sun still light up), a
    // flat skyBase instead of the sky, and no water. The reflection plane moves
    // to the top of the floor layer (y = 1) for floor reflections.
    indoor              : s32   = 0;    @Slider,0,1,1

    // ambientColor     : Vector3 = .{1.0, 1.0, 1.0}; @Color
    // ambientIntensity : float   = 0.3; @Slider,0,3,0.1

}

INDOOR_REFLECTION_PLANE :: 1.0;

// The planar reflection height: the water surface outdoors, the floor indoors.
effective_plane_height :: (wc: *World_Config) -> float {
    if wc.indoor  return INDOOR_REFLECTION_PLANE;
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

