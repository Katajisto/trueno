#scope_file

Pool :: #import "Pool";

Current_World :: struct {
    world : *World;
    pool  : Pool.Pool; // A memory pool to allocate stuff for the lifetime of this level being active. For example RDMs.
    valid : bool = false;
};

current_world : Current_World;
world_table   : Table(string, World);

#scope_export

nworld :: (name: string) {
    w : World;
    w.name = sprint("%", name);
    table_set(*world_table, w.name, w);
} @Command;

lworld :: (name: string) {
    if current_world.valid {
        Pool.reset(*current_world.pool);
    } else {
        Pool.set_allocators(*current_world.pool);
    }

    worldptr := table_find_pointer(*world_table, name);
    current_world.world = worldptr;
    current_world.valid = true;
} @Command;

get_current_world :: () -> *Current_World {
    return *current_world;
}

sworlds :: () {
    worlds : [..]World_Serialized;
    worlds.allocator = temp;
    for v : world_table {
        array_add(*worlds, serialize_world(*v,, temp));
    }
    #if OS != .WASM {
        file :: #import "File";
        json := Jaison.json_write_string(worlds, " ");
        file.write_entire_file("./game/resources/worlds.json", json); // @ToDo: it's quite likely that at some point having all of the worlds in one file will not be ok.
    }
} @Command

lworlds :: () {
    s := load_string_from_pack("./game/resources/worlds.json");
    success, worlds := Jaison.json_parse_string(s, [..]World_Serialized,, temp);
    for worlds {
        w : World;
        deserialize_world(*it, *w);
        table_set(*world_table, w.name, w);
        print("Loaded world: %\n", w.name);
    }
} @Command

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

    hasPlane      : s32  = 0; @Slider,0,1,1
    planeHeight   : float = 0.0; @Slider,-100,100,1
    planeType     : s32   = 1; @Slider,0,1,1

    grassDensity  : float = 200; @Slider,10,300,1
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

TrilePositions :: struct {
    trileName: string;
    positions: [..]Vector4;
}

Ground_Tile :: enum u8 {
    WATER :: 0;
    GRASS :: 1;
    SAND  :: 2;
}

World :: struct {
    name      : string;
    conf      : World_Config;
    positions : [..]TrilePositions;
    ground    : [1000][1000]Ground_Tile;
}

Trile_Positions_Serialized :: struct {
    trileName : string;
    positions : [..]float;
}

World_Serialized :: struct {
    name      : string;
    conf      : World_Config;
    positions : [..]Trile_Positions_Serialized;
    ground    : string;
}

// You should call this function with the temp allocator as context allocator.
serialize_world :: (world: *World) -> World_Serialized {
    ws : World_Serialized;
    ws.name = world.name;
    ws.conf = world.conf;
    for world.positions {
        tsp : Trile_Positions_Serialized;
        tsp.trileName = it.trileName;
        for v: it.positions {
            array_add(*tsp.positions, v.x);
            array_add(*tsp.positions, v.y);
            array_add(*tsp.positions, v.z);
            array_add(*tsp.positions, v.w);
        }
        array_add(*ws.positions, tsp);
    }

    groundstring : [..]u8;
    for i: 0..999 {
        for j: 0..999 {
            array_add(*groundstring, (cast(u8) world.ground[i][j]) + #char "a");
        }
    }
    ws.ground.data = groundstring.data;
    ws.ground.count = groundstring.count;
    return ws;
}

deserialize_world :: (ws: *World_Serialized, world: *World) {
    world.name = sprint("%", ws.name); // It's important that we re-store everything since the serialization is going to temp and gets freed.
    world.conf = ws.conf;

    for ws.positions {
        tp : TrilePositions;
        tp.trileName = sprint("%", it.trileName);
        for i : 0..it.positions.count/4-1 {
            v: Vector4;
            v.x = it.positions[i*4+0];
            v.y = it.positions[i*4+1];
            v.z = it.positions[i*4+2];
            v.w = it.positions[i*4+3];
            array_add(*tp.positions, v);
        }
        array_add(*world.positions, tp);
    }

    for c, ci : ws.ground {
        world.ground[ci/1000][ci%1000] = cast(Ground_Tile)((cast(u8)c)-#char "a");
    }
}

update_image_from_ground :: (world: *World, img: *sg_image) {
    materialdata : [1000*1000*4]u8;
    counter      : int = 0;
    for x: 0..999 {
        for y: 0..999 {
            if world.ground[x][y] == .GRASS {
                materialdata[counter + 0] = 0;
                materialdata[counter + 1] = 255;
                materialdata[counter + 2] = 0;
                materialdata[counter + 3] = 255;
                
            }
            if world.ground[x][y] == .WATER {
                materialdata[counter + 0] = 0;
                materialdata[counter + 1] = 0;
                materialdata[counter + 2] = 255;
                materialdata[counter + 3] = 255;
                
            }
            if world.ground[x][y] == .SAND {
                materialdata[counter + 0] = 255;
                materialdata[counter + 1] = 0;
                materialdata[counter + 2] = 0;
                materialdata[counter + 3] = 255;
                
            }
            counter += 4;
        } 
    }
    imgdata : sg_image_data;
    imgdata.subimage[0][0] = .{materialdata.data, materialdata.count};

    sg_update_image(img, *imgdata);
}

draw_world_picker :: (r_in: GR.Rect, theme: *GR.Overall_Theme) {
    r   := r_in;
	r.h = ui_h(4,4);
	count := 0;
	for v : world_table {
		if GR.button(r, v.name, *t_button_selectable(theme, current_world.valid && current_world.world.name == v.name), count) {
			lworld(v.name);
		}
		count += 1;
		r.y += r.h;
	}
}
