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
}

Chunk :: struct {
    coord:  Chunk_Key;
    groups: [..]Chunk_Trile_Group;

    rdm_atlas:      sg_image;
    rdm_lookup:     sg_image;
    rdm_valid:      bool;
    #if !FLAG_RELEASE_BUILD {
        rdm_lookup_cpu: []float;
        rdm_lookup_w:   s32;
        rdm_lookup_h:   s32;
    }
}

Editor_Note :: struct {
    position : Chunk_Key;
    text     : string;
}

World :: struct {
    name              : string;
    conf              : World_Config;
    chunks            : Table(Chunk_Key, Chunk, chunk_key_hash, chunk_key_compare);
    emitter_instances : [..]Particle_Emitter_Instance;
    notes             : [..]Editor_Note;
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

unload_current_world :: () {
    if current_world.valid {
        rdm_loader_cancel_all();
        for *chunk: current_world.world.chunks {
            // Release RDM GPU resources.
            if chunk.rdm_valid {
                sg_destroy_image(chunk.rdm_atlas);
                sg_destroy_image(chunk.rdm_lookup);
                #if !FLAG_RELEASE_BUILD {
                    if chunk.rdm_lookup_cpu.data then free(chunk.rdm_lookup_cpu.data);
                    chunk.rdm_lookup_cpu = .{};
                }
                chunk.rdm_atlas  = .{};
                chunk.rdm_lookup = .{};
                chunk.rdm_valid  = false;
            }
            for *group: chunk.groups {
                array_free(group.instances);
            }
            array_free(chunk.groups);
        }
        deinit(*current_world.world.chunks);
        Pool.reset(*current_world.pool);
        current_world.valid = false;
    } else {
        print("Setting allocators on current world!!\n");
        Pool.set_allocators(*current_world.pool);
    }
}

set_loaded_world :: (world: World) {
    unload_current_world();
    current_world.world = world;
    current_world.valid = true;
    resolve_emitter_definitions(*current_world.world);
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
    water_color:     [3]float;
    deep_color:      [3]float;
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
    b.water_color     = conf.waterColor.component;
    b.deep_color      = conf.deepColor.component;
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
        dir := tprint("./game/resources/worlds/%", name);
        file.make_directory_if_it_does_not_exist(dir, recursive = true);
        data := save_world(*current_world.world);
        file.write_entire_file(tprint("%/index.world", dir), data);
        log_info("Saved world '%' (% bytes)", name, data.count);
    }
} @Command

save_world :: (world: *World) -> string {
    builder: String_Builder;

    // Header
    write_value(*builder, WORLD_MAGIC);
    write_value(*builder, WORLD_VERSION);
    name_len := cast(u16) world.name.count;
    write_value(*builder, name_len);
    append(*builder, world.name);

    // World config
    conf_bin := world_config_to_binary(*world.conf);
    write_value(*builder, conf_bin);

    // Count non-empty chunks
    num_chunks: u32 = 0;
    for world.chunks {
        if it.groups.count > 0 then num_chunks += 1;
    }
    write_value(*builder, num_chunks);

    // We need to write chunk table, then chunk data.
    // First pass: serialize all chunk data to get sizes.
    Chunk_Data_Entry :: struct {
        coord: Chunk_Key;
        data:  string;
    }
    chunk_entries: [..]Chunk_Data_Entry;
    chunk_entries.allocator = temp;

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
        array_add(*chunk_entries, .{coord = chunk.coord, data = builder_to_string(*chunk_builder,, temp)});
    }

    // Calculate data offsets.
    // Chunk table starts right after what we've written so far.
    // header_size = current builder length + chunk_table_size
    current_header_size := builder_string_length(*builder);
    chunk_table_entry_size : s64 = size_of(s32)*3 + size_of(u32)*2; // chunk_x, chunk_y, chunk_z, data_offset, data_size
    chunk_table_size := cast(s64) num_chunks * chunk_table_entry_size;
    data_start := current_header_size + chunk_table_size;

    // Write chunk table
    running_offset := cast(u32) data_start;
    for entry: chunk_entries {
        write_value(*builder, entry.coord.x);
        write_value(*builder, entry.coord.y);
        write_value(*builder, entry.coord.z);
        write_value(*builder, running_offset);
        data_size := cast(u32) entry.data.count;
        write_value(*builder, data_size);
        running_offset += data_size;
    }

    // Write chunk data
    for entry: chunk_entries {
        append(*builder, entry.data);
    }

    // Write emitter instances
    num_emitters := cast(u16) world.emitter_instances.count;
    write_value(*builder, num_emitters);
    for inst: world.emitter_instances {
        name_len := cast(u16) inst.definition_name.count;
        write_value(*builder, name_len);
        append(*builder, inst.definition_name);
        write_value(*builder, inst.position.x);
        write_value(*builder, inst.position.y);
        write_value(*builder, inst.position.z);
    }

    // Write notes
    num_notes := cast(u16) world.notes.count;
    write_value(*builder, num_notes);
    for note: world.notes {
        text_len := cast(u16) note.text.count;
        write_value(*builder, text_len);
        append(*builder, note.text);
        write_value(*builder, note.position.x);
        write_value(*builder, note.position.y);
        write_value(*builder, note.position.z);
    }

    return builder_to_string(*builder);
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
    sunIntensity  : float = 2.0; @Slider,0,100,0.5
    skyIntensity  : float = 1.0; @Slider,0,10,0.5

    hasClouds     : s32 = 1; @Slider,0,1,1

    planeHeight   : float = 0.0; @Slider,0,3,0.1
    animatePlaneHeight : s32 = 1; @Slider,0,1,1
    waterColor    : Vector3 = .{1.0, 1.0, 1.0}; @Color // @ToDo: sensible default values.
    deepColor     : Vector3 = .{1.0, 1.0, 1.0}; @Color // @ToDo: sensible default values.

    // ambientColor     : Vector3 = .{1.0, 1.0, 1.0}; @Color
    // ambientIntensity : float   = 0.3; @Slider,0,3,0.1

}

// Copies over all the fields of our world config into a given shader type.
// Requires that the shader type has all of the fields the world config has.
world_config_to_shader_type :: (wc: *World_Config, data: *$T) {
    generate_copy_code :: () -> string {
        builder : String_Builder;
        ti := type_info(World_Config);
        for ti.members {
            if it.type == type_info(Vector3) then print_to_builder(*builder, "data.% = wc.%.component;\n", it.name, it.name);
            else print_to_builder(*builder, "data.% = wc.%;\n", it.name, it.name);
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
			if info.short_name == "index.world" {
				// Extract world name from path: .../worlds/{name}/index.world
				#import "String";
				_, left, _ := split_from_right(info.full_name, "/index.world");
				_, _, name := split_from_right(left, "/");
				if name.count > 0 then array_add(names, name);
			}
		}

		File_Utilities.visit_files("./game/resources/worlds", true, *world_names, dir_visitor);

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
