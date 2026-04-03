#scope_file

#import "String";
hash :: #import "Hash";
Pool :: #import "Pool";

#load "loaders.jai";

MAIN_CHUNK_BUFFER_SIZE : s64 : 256 * 1024;
RDM_CHUNK_BUFFER_SIZE  : s64 : 64 * 1024 * 1024;

Active_Fetch :: struct {
    occupied    : bool;
    req         : Fetch_Request;
    accumulated : [..]u8;
    chunk_buf   : []u8;
}

#scope_export

CHANNEL_MAIN : u32 : 0;
CHANNEL_RDM  : u32 : 1;

Fetch_Type :: enum {
    PACK;
    WORLD;
    WORLD_CHUNKS;
    RDM_ATLAS;
    RDM_LOOKUP;
}

Fetch_Request :: struct {
    type                : Fetch_Type;
    path                : string;
    
    // Pack
    pack_name           : string;
    should_block        : bool;
    should_block_engine : bool;
    
    // World / RDM
    world_name          : string;
    chunk_key           : Chunk_Key;
    
    // Atlas GPU image held between RDM_ATLAS and its paired RDM_LOOKUP fetch.
    rdm_pending_atlas   : sg_image;

    // Copy of world.json carried between WORLD and WORLD_CHUNKS fetches.
    world_json_data     : []u8;
}

Asset_Manager :: struct {
    active                      : [2]Active_Fetch;
    main_queue                  : [..]Fetch_Request;
    rdm_queue                   : [..]Fetch_Request;
    loadedPacks                 : [..]Loaded_Pack;
    pending_hot_reload          : bool;
    hot_reload_unpause_pending  : bool;
}

g_asset_manager : Asset_Manager;

#scope_file

#load "rdm_loader.jai";

fetch_callback :: (res: *sfetch_response_t) #c_call {
    push_context,defer_pop default_context;

    af := *g_asset_manager.active[res.channel];

    if res.fetched {
        chunk_count := res.data.size.(s64);
        needed      := af.accumulated.count + chunk_count;
        if af.accumulated.allocated < needed {
            new_cap := max(needed, max(af.accumulated.allocated * 2, 1024 * 1024));
            array_reserve(*af.accumulated, new_cap);
        }
        memcpy(af.accumulated.data + af.accumulated.count, res.data.ptr, chunk_count);
        af.accumulated.count = needed;
    }

    if !res.finished then return;

    // Mark channel free before processing so that enqueued follow-up requests
    // (WORLD -> WORLD_CHUNKS, RDM_ATLAS -> RDM_LOOKUP) are visible on the next tick.
    af.occupied = false;
    req := af.req;

    if res.failed {
        handle_fetch_failed(*req);
        array_reset(*af.accumulated);
        return;
    }

    data : []u8;
    data.data  = af.accumulated.data;
    data.count = af.accumulated.count;

    process_completed_fetch(*req, data);

    if req.type == .PACK {
        // process_completed_fetch either stored data in Loaded_Pack.data_buffer or
        // freed it on parse failure. Either way, zero af.accumulated without freeing.
        af.accumulated.data      = null;
        af.accumulated.count     = 0;
        af.accumulated.allocated = 0;
    } else {
        array_reset(*af.accumulated);
    }
}

handle_fetch_failed :: (req: *Fetch_Request) {
    if req.type == {

    case .PACK;
        log_error("Failed to load pack '%'", req.pack_name);

    case .WORLD;
        if ends_with(req.path, "world.json") {
            fallback_req : Fetch_Request;
            fallback_req.type         = .WORLD;
            fallback_req.world_name   = req.world_name;
            fallback_req.path         = sprint("%/worlds/%/index.world", GAME_RESOURCES_DIR, req.world_name);
            fallback_req.should_block = true;
            array_add(*g_asset_manager.main_queue, fallback_req);
            return;
        }
        log_error("Failed to load world '%'", req.world_name);

    case .WORLD_CHUNKS;
        free(req.world_json_data.data);
        log_error("Failed to load chunks.bin for world '%'", req.world_name);

    case .RDM_ATLAS;
        log_error("RDM: failed to load atlas for chunk %", req.chunk_key);

    case .RDM_LOOKUP;
        if req.rdm_pending_atlas.id != 0 then sg_destroy_image(req.rdm_pending_atlas);
        log_error("RDM: failed to load lookup for chunk %", req.chunk_key);

    }
}

process_completed_fetch :: (req: *Fetch_Request, data: []u8) {
    if req.type == {

    case .PACK;
        pack: Loaded_Pack;
        Pool.set_allocators(*pack.pool);
        pack.nameHash    = hash.get_hash(req.pack_name);
        pack.name        = sprint("%", req.pack_name);
        pack.data_buffer = data;
        success := init_from_memory(*pack.content, pack.data_buffer, sprint("%", req.pack_name));
        if !success {
            log_error("Failed to load pack!!");
            free(pack.data_buffer.data);
            pack.data_buffer = .{};
            return;
        }
        add_resources_from_pack(*pack);
        array_add(*g_asset_manager.loadedPacks, pack);

    case .WORLD;
        is_json := data.count > 0 && data[0] == #char "{";
        if is_json {
            json_copy := NewArray(data.count, u8, false);
            memcpy(json_copy.data, data.data, data.count);
            chunks_req : Fetch_Request;
            chunks_req.type            = .WORLD_CHUNKS;
            chunks_req.world_name      = req.world_name;
            chunks_req.path            = sprint("%/worlds/%/chunks.bin", GAME_RESOURCES_DIR, req.world_name);
            chunks_req.should_block    = true;
            chunks_req.world_json_data = json_copy;
            array_add(*g_asset_manager.main_queue, chunks_req);
        } else {
            world, ok := load_world_from_data(data);
            if ok {
                set_loaded_world(world);
                rdm_loader_enqueue_world(*get_current_world().world);
                log_info("Loaded world (legacy): %", req.world_name);
            } else {
                log_error("Failed to parse world '%'", req.world_name);
            }
        }

    case .WORLD_CHUNKS;
        json_data := req.world_json_data;
        defer free(json_data.data);

        json_str: string;
        json_str.data  = json_data.data;
        json_str.count = json_data.count;

        world, ok := load_world_from_json(json_str, data);
        if ok {
            set_loaded_world(world);
            rdm_loader_enqueue_world(*get_current_world().world);
            log_info("Loaded world: %", req.world_name);
        } else {
            log_error("Failed to parse world '%'", req.world_name);
        }

    case .RDM_ATLAS;
        curworld := get_current_world();
        if !curworld.valid || curworld.world.name != req.world_name then return;

        header_size := cast(s64) size_of(RDM_File_Header);
        if data.count < header_size {
            log_error("RDM: atlas too small for chunk %", req.chunk_key);
            return;
        }
        header := cast(*RDM_File_Header) data.data;
        if header.magic != RDM_FILE_MAGIC {
            log_error("RDM: bad atlas magic for chunk %", req.chunk_key);
            return;
        }
        atlas_pixel_bytes := cast(u64) header.width * cast(u64) header.height * 4 * size_of(float);
        atlas_imgdata : sg_image_data;
        atlas_imgdata.subimage[0][0] = .{ data.data + header_size, atlas_pixel_bytes };
        atlas_desc : sg_image_desc = .{
            render_target = false,
            width         = header.width,
            height        = header.height,
            pixel_format  = sg_pixel_format.RGBA32F,
            sample_count  = 1,
            data          = atlas_imgdata,
        };
        chunk_ptr := table_find_pointer(*curworld.world.chunks, req.chunk_key);
        lookup_path: string;
        if chunk_ptr != null && chunk_ptr.rdm_lookup_path.count > 0 {
            lookup_path = sprint("%/worlds/%/%", GAME_RESOURCES_DIR, req.world_name, chunk_ptr.rdm_lookup_path);
        } else {
            lookup_path = rdm_chunk_filename(req.world_name, req.chunk_key, "rdm_lookup");
        }
        lookup_req : Fetch_Request;
        lookup_req.type              = .RDM_LOOKUP;
        lookup_req.world_name        = req.world_name;
        lookup_req.chunk_key         = req.chunk_key;
        lookup_req.path              = lookup_path;
        lookup_req.rdm_pending_atlas = sg_make_image(*atlas_desc);
        array_add(*g_asset_manager.rdm_queue, lookup_req);

    case .RDM_LOOKUP;
        curworld  := get_current_world();
        world_ok  := curworld.valid && curworld.world.name == req.world_name;

        if !world_ok {
            if req.rdm_pending_atlas.id != 0 then sg_destroy_image(req.rdm_pending_atlas);
            return;
        }
        header_size := cast(s64) size_of(RDM_File_Header);
        if data.count < header_size {
            log_error("RDM: lookup too small for chunk %", req.chunk_key);
            sg_destroy_image(req.rdm_pending_atlas);
            return;
        }
        header := cast(*RDM_File_Header) data.data;
        if header.magic != RDM_FILE_MAGIC {
            log_error("RDM: bad lookup magic for chunk %", req.chunk_key);
            sg_destroy_image(req.rdm_pending_atlas);
            return;
        }
        lookup_pixel_bytes := cast(u64) header.width * cast(u64) header.height * 4 * size_of(float);
        lookup_imgdata : sg_image_data;
        lookup_imgdata.subimage[0][0] = .{ data.data + header_size, lookup_pixel_bytes };
        lookup_desc : sg_image_desc = .{
            render_target = false,
            width         = header.width,
            height        = header.height,
            pixel_format  = sg_pixel_format.RGBA32F,
            sample_count  = 1,
            data          = lookup_imgdata,
        };
        chunk := table_find_pointer(*curworld.world.chunks, req.chunk_key);
        if chunk != null {
            chunk.rdm_atlas  = req.rdm_pending_atlas;
            chunk.rdm_lookup = sg_make_image(*lookup_desc);
            #if !FLAG_RELEASE_BUILD {
                chunk.rdm_lookup_w = header.width;
                chunk.rdm_lookup_h = header.height;
                num_floats := cast(s64)(header.width * header.height * 4);
                cpu_copy   := NewArray(num_floats, float);
                memcpy(cpu_copy.data, data.data + header_size, cast(s64)lookup_pixel_bytes);
                chunk.rdm_lookup_cpu = cpu_copy;
            }
            chunk.rdm_valid = true;
            log_debug("RDM: loaded chunk %", req.chunk_key);
        } else {
            sg_destroy_image(req.rdm_pending_atlas);
        }

    }
}

Loaded_Pack :: struct {
    name        : string;
    nameHash    : u32 = 0;
    data_buffer : []u8;
    content     : Load_Package;
    textures    : Table(string, sg_image);
    animations  : Table(string, Animation);
    audio       : Table(string, Audio_Data);
    pool        : Pool.Pool;
}

add_resources_from_pack :: (pack: *Loaded_Pack) {
    push_allocator(.{Pool.pool_allocator_proc, *pack.pool});

    Queued_Sheet_File :: struct {
        name    : string;
        image   : sg_image;
        sheet_w : s32;
        sheet_h : s32;
        sheet   : Aseprite_Sheet;
    }
    sheets_to_init : Table(string, Queued_Sheet_File);
    sheets_to_init.allocator = temp;

    for v : pack.content.lookup {
        _, name, extension := split_from_left(v.name, ".");
        if extension == {
            case "png";
                img, w, h := create_texture_from_memory(v.data);
                table_set(*pack.textures, sprint("%", v.name), img);
            case "sheet.png";
                img, w, h := create_texture_from_memory(v.data);
                queuedSheet := table_find_pointer(*sheets_to_init, name);
                if !queuedSheet {
                    table_set(*sheets_to_init, name, .{ name = name, image = img, sheet_w = w, sheet_h = h });
                } else {
                    queuedSheet.image = img;
                    queuedSheet.sheet_w = w;
                    queuedSheet.sheet_h = h;
                }
            case "sheet.json";
                s := create_string_from_memory(v.data);
                success, sheet := Jaison.json_parse_string(s, Aseprite_Sheet,, temp);
                if !success {
                    log_error("Failed to parse animation sheet JSON for sheet(%)", name);
                    continue;
                }
                queuedSheet := table_find_pointer(*sheets_to_init, name);
                if !queuedSheet {
                    table_set(*sheets_to_init, name, .{ name = name, sheet = sheet });
                } else {
                    queuedSheet.sheet = sheet;
                }
            case "colorgrade.png";
                img, x, y := create_texture_from_memory(v.data);
                add_image_to_lut_list(img, v.name);
            case "wav";
                audio := load_wav_from_memory(v.data);
                table_set(*pack.audio, name, audio);
            case "json";
                if name == "particles" {
                    s := create_string_from_memory(v.data);
                    success, defs := Jaison.json_parse_string(s, [..]Particle_Emitter_Config,, temp);
                    if success {
                        array_reset(*g_emitter_defs);
                        for defs {
                            def := it;
                            def.name = sprint("%", it.name);
                            def.animation_name = sprint("%", it.animation_name);
                            array_add(*g_emitter_defs, def);
                        }
                        log_info("Loaded % particle definitions from pack", g_emitter_defs.count);
                    }
                }
            case "hex";
                pal : Loaded_Palette;
                pal.name = sprint("%", name);
                pal.entries = load_hex_palette_from_memory(v.data);
                array_add(*g_palettes, pal);
                log_info("Loaded % colors from hex palette(%)", pal.entries.count, v.name);
            case "ttf";
            // Load into a font. Add to free list.
            case;
                log_warn("File(%) in pack(%) has unknown format", v.name, pack.name);
        }
        log_debug("% -> %", v.name, extension);
    }

    // Properly initialize animations from the pack now that we have the images
    // and the JSON files both combined.
    for qsheet : sheets_to_init {
        for qsheet.sheet.meta.frameTags {
            anim : Animation;
            anim.name = sprint("%", it.name);
            anim.sheet = qsheet.image;
            anim.sheet_w = qsheet.sheet_w;
            anim.sheet_h = qsheet.sheet_h;
            for idx : it.from..it.to {
                frameData := qsheet.sheet.frames[idx];
                array_add(*anim.frames, Frame.{
                    frameData.frame.x,
                    frameData.frame.y,
                    frameData.frame.w,
                    frameData.frame.h,
                    frameData.duration
                });
            }
            table_add(*pack.animations, anim.name, anim);
            log_debug("Added anim(%)", anim.name);
        }
    }
}

find_pack_by_name :: (name: string) -> (bool, Loaded_Pack) {
    nameHash := get_hash(name);
    for g_asset_manager.loadedPacks {
        if it.nameHash == nameHash {
            return true, it;
        }
    }
    log_warn("Unable to find pack: %", name);
    return false, .{};
}

dispatch_channel :: (queue: *[..]Fetch_Request, channel: u32) {
    af := *g_asset_manager.active[channel];
    if af.occupied || queue.count == 0 then return;

    req := queue.data[0];
    for i: 0..queue.count - 2 {
        queue.data[i] = queue.data[i + 1];
    }
    queue.count -= 1;

    af.occupied          = true;
    af.req               = req;
    af.accumulated.count = 0;

    path_c := to_c_string(req.path);
    defer free(path_c);
    sfetch_send(*(sfetch_request_t.{
        channel    = channel,
        path       = path_c,
        callback   = fetch_callback,
        chunk_size = cast(u32) af.chunk_buf.count,
        buffer     = .{ ptr = af.chunk_buf.data, size = cast(u64) af.chunk_buf.count },
    }));
}

#scope_export

free_resources_from_pack :: (pack: *Loaded_Pack) {
    for pack.textures  sg_destroy_image(it);
    table_reset(*pack.textures);
    table_reset(*pack.audio);
    table_reset(*pack.animations);
    Pool.reset(*pack.pool);
    if pack.data_buffer.data {
        free(pack.data_buffer.data);
        pack.data_buffer = .{};
    }
}

asset_manager_init :: () {
    g_asset_manager.active[CHANNEL_MAIN].chunk_buf = NewArray(MAIN_CHUNK_BUFFER_SIZE, u8, false);
    g_asset_manager.active[CHANNEL_RDM].chunk_buf  = NewArray(RDM_CHUNK_BUFFER_SIZE,  u8, false);
}

mandatory_loads_done :: () -> bool {
    for channel: 0..1 {
        af := *g_asset_manager.active[channel];
        if af.occupied && af.req.should_block_engine then return false;
    }
    for g_asset_manager.main_queue {
        if it.should_block_engine then return false;
    }
    for g_asset_manager.rdm_queue {
        if it.should_block_engine then return false;
    }
    return true;
}

show_loading_screen :: () -> bool {
    for channel: 0..1 {
        af := *g_asset_manager.active[channel];
        if af.occupied && af.req.should_block then return true;
    }
    for g_asset_manager.main_queue {
        if it.should_block then return true;
    }
    for g_asset_manager.rdm_queue {
        if it.should_block then return true;
    }
    return false;
}

asset_manager_tick :: () {
    #if !FLAG_RELEASE_BUILD && OS != .WASM {
        if g_asset_manager.pending_hot_reload
           && !g_asset_manager.active[CHANNEL_MAIN].occupied
           && g_asset_manager.main_queue.count == 0 {
            g_asset_manager.pending_hot_reload = false;
            hot_reload_all_packs();
        }
        if g_asset_manager.hot_reload_unpause_pending && !show_loading_screen() {
            g_mixer.paused = false;
            g_asset_manager.hot_reload_unpause_pending = false;
        }
    }

    dispatch_channel(*g_asset_manager.main_queue, CHANNEL_MAIN);
    dispatch_channel(*g_asset_manager.rdm_queue,  CHANNEL_RDM);

    sfetch_dowork();
}

load_world :: (name: string) {
    unload_current_world();
    req : Fetch_Request;
    req.type         = .WORLD;
    req.world_name   = sprint("%", name);
    req.path         = sprint("%/worlds/%/world.json", GAME_RESOURCES_DIR, name);
    req.should_block = true;
    array_add(*g_asset_manager.main_queue, req);
}

load_pack :: (name: string, shouldBlock: bool = true, shouldBlockEngine: bool = false) {
    req : Fetch_Request;
    req.type                = .PACK;
    req.pack_name           = sprint("%", name);
    req.path                = sprint("%/%.pack", PACK_DIR, name);
    req.should_block        = shouldBlock;
    req.should_block_engine = shouldBlockEngine;
    array_add(*g_asset_manager.main_queue, req);
}

// Asset management:

#scope_file
#scope_export

get_texture_from_pack :: (pack: string, path: string) -> (sg_image) {
    found, pack := find_pack_by_name(pack);
    invalid_img : sg_image;

    if !found {
        // find_pack_by_name already logs this
        return invalid_img;
    }

    ok, img := table_find(*pack.textures, path);

    if !ok {
        log_warn("Failed to find texture(%) from pack(%)", path, pack.name);
        return invalid_img;
    }

    return img;
}

get_animation_from_pack :: (pack: string, path: string) -> *Animation {
    found, pack := find_pack_by_name(pack);
    if !found then return null;
    return table_find_pointer(*pack.animations, path);
}

get_audio_from_pack :: (pack: string, path: string) -> *Audio_Data {
    found, pack := find_pack_by_name(pack);
    if !found then return null;
    audio := table_find_pointer(*pack.audio, path);
    if !audio then log_error("Failed to find audio(%)", path);
    return audio;
}

add_font_from_pack :: (pack: string, path: string) {
    pack_ok, pack := find_pack_by_name(pack);
    if !pack_ok then return;
    ok, entry := table_find(*pack.content.lookup, path);
    if !ok {
        log_error("Failed to find font % from pack", path);
        return;
    }
    state.font_default.fons_font = fonsAddFontMem(state.fons, "sans", entry.data.data, xx entry.data.count, 0);
}

load_string_from_pack :: (pack: string, path: string) -> string {
    log_warn("You are circumventing the asset management system");
    pack_ok, pack := find_pack_by_name(pack);
    if !pack_ok return "";

    ok, entry := table_find(*pack.content.lookup, path);
    if !ok {
        log_error("Failed to load string from pack: %", path);
        return "";
    }

    s: string;
    s.data = entry.data.data;
    s.count = entry.data.count;
    return s;
}
