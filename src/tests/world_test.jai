test_floor_div_mod :: () {
    s := begin_suite("floor_div / floor_mod");

    check(*s, "floor_div( 0,  32) ==  0",  floor_div( 0,  32) ==  0);
    check(*s, "floor_div( 1,  32) ==  0",  floor_div( 1,  32) ==  0);
    check(*s, "floor_div(31,  32) ==  0",  floor_div(31,  32) ==  0);
    check(*s, "floor_div(32,  32) ==  1",  floor_div(32,  32) ==  1);
    check(*s, "floor_div(33,  32) ==  1",  floor_div(33,  32) ==  1);
    check(*s, "floor_div(-1,  32) == -1",  floor_div(-1,  32) == -1);
    check(*s, "floor_div(-32, 32) == -1",  floor_div(-32, 32) == -1);
    check(*s, "floor_div(-33, 32) == -2",  floor_div(-33, 32) == -2);

    check(*s, "floor_mod( 0,  32) ==  0",  floor_mod( 0,  32) ==  0);
    check(*s, "floor_mod( 1,  32) ==  1",  floor_mod( 1,  32) ==  1);
    check(*s, "floor_mod(31,  32) == 31",  floor_mod(31,  32) == 31);
    check(*s, "floor_mod(32,  32) ==  0",  floor_mod(32,  32) ==  0);
    check(*s, "floor_mod(33,  32) ==  1",  floor_mod(33,  32) ==  1);
    check(*s, "floor_mod(-1,  32) == 31",  floor_mod(-1,  32) == 31);
    check(*s, "floor_mod(-32, 32) ==  0",  floor_mod(-32, 32) ==  0);
    check(*s, "floor_mod(-33, 32) == 31",  floor_mod(-33, 32) == 31);

    end_suite(s);
}

test_coord_roundtrip :: () {
    s := begin_suite("world coord round-trip");

    roundtrip_check :: (suite: *Test_Suite, wx: s32, wy: s32, wz: s32) {
        ck := world_to_chunk_coord(wx, wy, wz);
        lx, ly, lz := world_to_local(wx, wy, wz);
        rx, ry, rz := chunk_local_to_world(ck, lx, ly, lz);
        check(suite, tprint("(%, %, %) round-trips", wx, wy, wz), rx == wx && ry == wy && rz == wz);
    }

    roundtrip_check(*s,   0,   0,   0);
    roundtrip_check(*s,   1,   1,   1);
    roundtrip_check(*s,  31,  31,  31);
    roundtrip_check(*s,  32,  32,  32);
    roundtrip_check(*s,  33,  33,  33);
    roundtrip_check(*s,  -1,  -1,  -1);
    roundtrip_check(*s, -32, -32, -32);
    roundtrip_check(*s, -33, -33, -33);
    roundtrip_check(*s,  63,  -1,  32);

    end_suite(s);
}

test_chunk_coord_values :: () {
    s := begin_suite("world_to_chunk_coord values");

    check(*s, "( 0, 0, 0) -> chunk ( 0, 0, 0)", world_to_chunk_coord( 0,  0,  0) == .{ 0,  0,  0});
    check(*s, "(31, 0, 0) -> chunk ( 0, 0, 0)", world_to_chunk_coord(31,  0,  0) == .{ 0,  0,  0});
    check(*s, "(32, 0, 0) -> chunk ( 1, 0, 0)", world_to_chunk_coord(32,  0,  0) == .{ 1,  0,  0});
    check(*s, "(-1, 0, 0) -> chunk (-1, 0, 0)", world_to_chunk_coord(-1,  0,  0) == .{-1,  0,  0});
    check(*s, "(-32,0, 0) -> chunk (-1, 0, 0)", world_to_chunk_coord(-32, 0,  0) == .{-1,  0,  0});
    check(*s, "(-33,0, 0) -> chunk (-2, 0, 0)", world_to_chunk_coord(-33, 0,  0) == .{-2,  0,  0});

    end_suite(s);
}

make_test_world :: () -> World {
    world: World;
    world.name = "test_world";
    world.conf.skyBase = .{0.1, 0.2, 0.3};
    world.conf.sunIntensity = 5.0;
    world.conf.hasClouds = 0;
    world.conf.planeHeight = 2.5;

    chunk1: Chunk;
    chunk1.coord = .{x = 0, y = 0, z = 0};
    group1: Chunk_Trile_Group;
    group1.trile_name = "stone";
    array_add(*group1.instances, Trile_Instance.{x = 1, y = 2, z = 3, orientation = 5});
    array_add(*group1.instances, Trile_Instance.{x = 10, y = 20, z = 30, orientation = 12});
    array_add(*chunk1.groups, group1);
    table_set(*world.chunks, chunk1.coord, chunk1);

    chunk2: Chunk;
    chunk2.coord = .{x = -1, y = 0, z = 2};
    group2: Chunk_Trile_Group;
    group2.trile_name = "grass";
    array_add(*group2.instances, Trile_Instance.{x = 0, y = 0, z = 0, orientation = 0});
    array_add(*chunk2.groups, group2);
    group3: Chunk_Trile_Group;
    group3.trile_name = "dirt";
    array_add(*group3.instances, Trile_Instance.{x = 5, y = 5, z = 5, orientation = 3});
    array_add(*chunk2.groups, group3);
    table_set(*world.chunks, chunk2.coord, chunk2);

    e1: Particle_Emitter_Instance;
    e1.definition_name = "fire";
    e1.position = .{10.5, 0.0, 5.5};
    e1.active = true;
    array_add(*world.emitter_instances, e1);

    n1: Editor_Note;
    n1.text = "spawn point";
    n1.position = .{x = 0, y = 0, z = 0};
    array_add(*world.notes, n1);

    return world;
}

test_world_save_load_roundtrip :: () {
    s := begin_suite("world JSON save/load roundtrip");

    world := make_test_world();
    json_str, bin_data := save_world(*world);

    bin_bytes: []u8;
    bin_bytes.data = bin_data.data;
    bin_bytes.count = bin_data.count;

    loaded, ok := load_world_from_json(json_str, bin_bytes);
    check(*s, "load succeeds", ok);
    check(*s, "name matches", loaded.name == "test_world");
    check(*s, "skyBase.x", loaded.conf.skyBase.x == 0.1);
    check(*s, "skyBase.y", loaded.conf.skyBase.y == 0.2);
    check(*s, "skyBase.z", loaded.conf.skyBase.z == 0.3);
    check(*s, "sunIntensity", loaded.conf.sunIntensity == 5.0);
    check(*s, "hasClouds", loaded.conf.hasClouds == 0);
    check(*s, "planeHeight", loaded.conf.planeHeight == 2.5);

    chunk0 := table_find_pointer(*loaded.chunks, Chunk_Key.{x=0, y=0, z=0});
    check(*s, "chunk (0,0,0) exists", chunk0 != null);
    if chunk0 {
        check(*s, "chunk0 has 1 group", chunk0.groups.count == 1);
        if chunk0.groups.count >= 1 {
            check(*s, "chunk0 group name", chunk0.groups[0].trile_name == "stone");
            check(*s, "chunk0 group has 2 instances", chunk0.groups[0].instances.count == 2);
            if chunk0.groups[0].instances.count >= 2 {
                inst := chunk0.groups[0].instances[0];
                check(*s, "inst0 pos", inst.x == 1 && inst.y == 2 && inst.z == 3);
                check(*s, "inst0 orient", inst.orientation == 5);
            }
        }
    }

    chunk_neg := table_find_pointer(*loaded.chunks, Chunk_Key.{x=-1, y=0, z=2});
    check(*s, "chunk (-1,0,2) exists", chunk_neg != null);
    if chunk_neg {
        check(*s, "chunk_neg has 2 groups", chunk_neg.groups.count == 2);
    }

    check(*s, "1 emitter", loaded.emitter_instances.count == 1);
    if loaded.emitter_instances.count >= 1 {
        check(*s, "emitter name", loaded.emitter_instances[0].definition_name == "fire");
        check(*s, "emitter pos.x", loaded.emitter_instances[0].position.x == 10.5);
    }

    check(*s, "1 note", loaded.notes.count == 1);
    if loaded.notes.count >= 1 {
        check(*s, "note text", loaded.notes[0].text == "spawn point");
        check(*s, "note pos", loaded.notes[0].position == Chunk_Key.{x=0, y=0, z=0});
    }

    end_suite(s);
}

test_world_json_chunk_offsets :: () {
    s := begin_suite("world JSON chunk offsets");

    world := make_test_world();
    json_str, bin_data := save_world(*world);

    Jaison :: #import "Jaison";
    ok, wj := Jaison.json_parse_string(json_str, World_Json);
    check(*s, "JSON parses", ok);
    check(*s, "2 chunk entries", wj.chunks.count == 2);

    if wj.chunks.count == 2 {
        for jc: wj.chunks {
            check(*s, tprint("chunk %: offset+size <= bin", it_index),
                  cast(s64)(jc.offset + jc.size) <= bin_data.count);
        }
        a := wj.chunks[0];
        b := wj.chunks[1];
        no_overlap := (a.offset + a.size <= b.offset) || (b.offset + b.size <= a.offset);
        check(*s, "chunks don't overlap", no_overlap);
    }

    end_suite(s);
}

test_legacy_load_cursor_fix :: () {
    s := begin_suite("legacy binary cursor fix");

    world := make_test_world();

    builder: String_Builder;
    write_value(*builder, WORLD_MAGIC);
    write_value(*builder, cast(u16) 3);
    name_len := cast(u16) world.name.count;
    write_value(*builder, name_len);
    append(*builder, world.name);

    conf_bin := world_config_to_binary(*world.conf);
    write_value(*builder, conf_bin);

    Chunk_Data_Entry :: struct { coord: Chunk_Key; data: string; }
    chunk_entries: [..]Chunk_Data_Entry;
    chunk_entries.allocator = temp;
    num_chunks: u32 = 0;
    for chunk: world.chunks {
        if chunk.groups.count == 0 then continue;
        num_chunks += 1;
        cb: String_Builder;
        cb.allocator = temp;
        write_value(*cb, cast(u16) chunk.groups.count);
        for group: chunk.groups {
            write_value(*cb, cast(u16) group.trile_name.count);
            append(*cb, group.trile_name);
            write_value(*cb, cast(u16) group.instances.count);
            for inst: group.instances { write_value(*cb, inst); }
        }
        array_add(*chunk_entries, .{coord = chunk.coord, data = builder_to_string(*cb,, temp)});
    }
    write_value(*builder, num_chunks);

    current_header_size := builder_string_length(*builder);
    chunk_table_entry_size : s64 = size_of(s32)*3 + size_of(u32)*2;
    chunk_table_size := cast(s64) num_chunks * chunk_table_entry_size;
    data_start := current_header_size + chunk_table_size;
    running_offset := cast(u32) data_start;
    for entry: chunk_entries {
        write_value(*builder, entry.coord.x);
        write_value(*builder, entry.coord.y);
        write_value(*builder, entry.coord.z);
        write_value(*builder, running_offset);
        write_value(*builder, cast(u32) entry.data.count);
        running_offset += cast(u32) entry.data.count;
    }
    for entry: chunk_entries { append(*builder, entry.data); }

    write_value(*builder, cast(u16) world.emitter_instances.count);
    for inst: world.emitter_instances {
        write_value(*builder, cast(u16) inst.definition_name.count);
        append(*builder, inst.definition_name);
        write_value(*builder, inst.position.x);
        write_value(*builder, inst.position.y);
        write_value(*builder, inst.position.z);
    }

    write_value(*builder, cast(u16) world.notes.count);
    for note: world.notes {
        write_value(*builder, cast(u16) note.text.count);
        append(*builder, note.text);
        write_value(*builder, note.position.x);
        write_value(*builder, note.position.y);
        write_value(*builder, note.position.z);
    }

    binary := builder_to_string(*builder);
    data: []u8;
    data.data = binary.data;
    data.count = binary.count;
    loaded, ok := load_world_from_data(data);
    check(*s, "legacy load succeeds", ok);
    check(*s, "legacy emitter count", loaded.emitter_instances.count == 1);
    if loaded.emitter_instances.count >= 1 {
        check(*s, "legacy emitter name", loaded.emitter_instances[0].definition_name == "fire");
    }
    check(*s, "legacy note count", loaded.notes.count == 1);
    if loaded.notes.count >= 1 {
        check(*s, "legacy note text", loaded.notes[0].text == "spawn point");
    }

    end_suite(s);
}

#run {
    test_floor_div_mod();
    test_coord_roundtrip();
    test_chunk_coord_values();
    test_world_save_load_roundtrip();
    test_world_json_chunk_offsets();
    test_legacy_load_cursor_fix();
}
