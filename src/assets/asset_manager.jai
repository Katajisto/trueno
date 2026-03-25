#scope_file

#import "String";
hash :: #import "Hash";
Pool :: #import "Pool";

#load "loaders.jai";

// Shared types and the global must be #scope_export so that rdm_loader.jai
// (a separate file, even when #load-ed) can access them.
#scope_export

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
    // Heap copy of world.json carried between WORLD and WORLD_CHUNKS fetches.
    world_json_data     : []u8;
}

Asset_Manager :: struct {
    fetch_queue                 : [..]Fetch_Request;
    is_fetching                 : bool;
    current_fetch               : Fetch_Request;
    loadedPacks                 : [..]Loaded_Pack;
    pending_hot_reload          : bool;
    hot_reload_unpause_pending  : bool;
}

g_asset_manager : Asset_Manager;

#scope_file

#load "rdm_loader.jai";

MAX_FILE_SIZE        :: 200_000_000;
RDM_ATLAS_MAX_BYTES  :: 4096 * 4096 * 4 * 4 + size_of(RDM_File_Header);
RDM_LOOKUP_MAX_BYTES :: 512  * 512  * 4 * 4 + size_of(RDM_File_Header);

buf              : []u8;
world_buf        : []u8;
world_chunks_buf : []u8;
rdm_atlas_buf    : []u8;
rdm_lookup_buf   : []u8;

buffer_for_fetch :: (type: Fetch_Type) -> (*u8, u64) {
    if type == .PACK          return buf.data,              xx buf.count;
    if type == .WORLD         return world_buf.data,        xx world_buf.count;
    if type == .WORLD_CHUNKS  return world_chunks_buf.data, xx world_chunks_buf.count;
    if type == .RDM_ATLAS     return rdm_atlas_buf.data,    xx rdm_atlas_buf.count;
    if type == .RDM_LOOKUP    return rdm_lookup_buf.data,   xx rdm_lookup_buf.count;
    return null, 0;
}

fetch_callback :: (res: *sfetch_response_t) #c_call {
    push_context,defer_pop default_context;

    req := g_asset_manager.current_fetch;
    g_asset_manager.is_fetching = false;
    if req.type == {

    case .PACK;
        if res.failed {
            log_error("Failed to load pack '%'", req.pack_name);
            return;
        }
        mem := NewArray(res.data.size.(s64), u8, false);
        memcpy(mem.data, res.data.ptr, res.data.size.(s64));
        pack: Loaded_Pack;
        Pool.set_allocators(*pack.pool);
        pack.nameHash = hash.get_hash(req.pack_name);
        pack.name = sprint("%", req.pack_name);
        success := init_from_memory(*pack.content, mem, sprint("%", req.pack_name));
        if !success { log_error("Failed to load pack!!"); return; }
        add_resources_from_pack(*pack);
        array_add(*g_asset_manager.loadedPacks, pack);

    case .WORLD;
        if res.failed {
            if ends_with(req.path, "world.json") {
                fallback_req : Fetch_Request;
                fallback_req.type         = .WORLD;
                fallback_req.world_name   = req.world_name;
                fallback_req.path         = sprint("%/worlds/%/index.world", GAME_RESOURCES_DIR, req.world_name);
                fallback_req.should_block = true;
                array_add(*g_asset_manager.fetch_queue, fallback_req);
                return;
            }
            log_error("Failed to load world '%'", req.world_name);
            return;
        }
        data: []u8;
        data.data  = res.data.ptr;
        data.count = res.data.size.(s64);

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
            array_add(*g_asset_manager.fetch_queue, chunks_req);
        } else {
            world, ok := load_world_from_data(data);
            if ok {
                set_loaded_world(world);
                rdm_loader_enqueue_world(*get_current_world().world);
                log_info("Loaded world (legacy): %", world.name);
            } else {
                log_error("Failed to parse world '%'", req.world_name);
            }
        }

    case .WORLD_CHUNKS;
        json_data := req.world_json_data;
        defer free(json_data.data);

        if res.failed {
            log_error("Failed to load chunks.bin for world '%'", req.world_name);
            return;
        }

        json_str: string;
        json_str.data = json_data.data;
        json_str.count = json_data.count;

        chunk_bin: []u8;
        chunk_bin.data = res.data.ptr;
        chunk_bin.count = res.data.size.(s64);

        world, ok := load_world_from_json(json_str, chunk_bin);
        if ok {
            set_loaded_world(world);
            rdm_loader_enqueue_world(*get_current_world().world);
            log_info("Loaded world: %", world.name);
        } else {
            log_error("Failed to parse world '%'", req.world_name);
        }

    case .RDM_ATLAS;
        curworld := get_current_world();
        if !curworld.valid || curworld.world.name != req.world_name then return;

        if res.failed {
            log_error("RDM: failed to load atlas for chunk %", req.chunk_key);
            return;
        }
        header_size := cast(s64) size_of(RDM_File_Header);
        if res.data.size < cast(u64) header_size {
            log_error("RDM: atlas too small for chunk %", req.chunk_key);
            return;
        }
        header := cast(*RDM_File_Header) res.data.ptr;
        if header.magic != RDM_FILE_MAGIC {
            log_error("RDM: bad atlas magic for chunk %", req.chunk_key);
            return;
        }
        atlas_pixel_bytes := cast(u64) header.width * cast(u64) header.height * 4 * size_of(float);
        atlas_imgdata : sg_image_data;
        atlas_imgdata.subimage[0][0] = .{ res.data.ptr + header_size, atlas_pixel_bytes };
        atlas_desc : sg_image_desc = .{
            render_target = false,
            width         = header.width,
            height        = header.height,
            pixel_format  = sg_pixel_format.RGBA32F,
            sample_count  = 1,
            data          = atlas_imgdata,
        };
        lookup_path: string;
        chunk_ptr := table_find_pointer(*curworld.world.chunks, req.chunk_key);
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
        array_add(*g_asset_manager.fetch_queue, lookup_req);

    case .RDM_LOOKUP;
        curworld  := get_current_world();
        world_ok  := curworld.valid && curworld.world.name == req.world_name;

        if res.failed || !world_ok {
            if res.failed then log_error("RDM: failed to load lookup for chunk %", req.chunk_key);
            if req.rdm_pending_atlas.id != 0 then sg_destroy_image(req.rdm_pending_atlas);
            return;
        }
        header_size := cast(s64) size_of(RDM_File_Header);
        if res.data.size < cast(u64) header_size {
            log_error("RDM: lookup too small for chunk %", req.chunk_key);
            sg_destroy_image(req.rdm_pending_atlas);
            return;
        }
        header := cast(*RDM_File_Header) res.data.ptr;
        if header.magic != RDM_FILE_MAGIC {
            log_error("RDM: bad lookup magic for chunk %", req.chunk_key);
            sg_destroy_image(req.rdm_pending_atlas);
            return;
        }
        lookup_pixel_bytes := cast(u64) header.width * cast(u64) header.height * 4 * size_of(float);
        lookup_imgdata : sg_image_data;
        lookup_imgdata.subimage[0][0] = .{ res.data.ptr + header_size, lookup_pixel_bytes };
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
            chunk.rdm_atlas    = req.rdm_pending_atlas;
            chunk.rdm_lookup   = sg_make_image(*lookup_desc);
            #if !FLAG_RELEASE_BUILD {
                chunk.rdm_lookup_w = header.width;
                chunk.rdm_lookup_h = header.height;
                num_floats := cast(s64)(header.width * header.height * 4);
                cpu_copy := NewArray(num_floats, float);
                memcpy(cpu_copy.data, res.data.ptr + header_size, cast(s64)lookup_pixel_bytes);
                chunk.rdm_lookup_cpu = cpu_copy;
            }
            chunk.rdm_valid    = true;
            log_debug("RDM: loaded chunk %", req.chunk_key);
        } else {
            sg_destroy_image(req.rdm_pending_atlas);
        }

    }
}

Loaded_Pack :: struct {
    name       : string;
    nameHash   : u32 = 0;
    content    : Load_Package;
    textures   : Table(string, sg_image);
    animations : Table(string, Animation);
    audio      : Table(string, Audio_Data);
    pool       : Pool.Pool;
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

    // add_new_spritesheets_from_pack(*pack.content, pack.name);
    // load_color_lut_images(*pack.content, pack.name);
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

#scope_export

free_resources_from_pack :: (pack: *Loaded_Pack) {
    for pack.textures  sg_destroy_image(it);
    table_reset(*pack.textures);
    table_reset(*pack.audio);
    table_reset(*pack.animations);
    Pool.reset(*pack.pool);
}

asset_manager_init :: () {
    buf              = NewArray(MAX_FILE_SIZE,        u8, false);
    world_buf        = NewArray(MAX_FILE_SIZE,        u8, false);
    world_chunks_buf = NewArray(MAX_FILE_SIZE,        u8, false);
    rdm_atlas_buf    = NewArray(RDM_ATLAS_MAX_BYTES,  u8, false);
    rdm_lookup_buf   = NewArray(RDM_LOOKUP_MAX_BYTES, u8, false);
}

mandatory_loads_done :: () -> bool {
    if g_asset_manager.is_fetching && g_asset_manager.current_fetch.should_block_engine then return false;
    for g_asset_manager.fetch_queue {
        if it.should_block_engine then return false;
    }
    return true;
}

show_loading_screen :: () -> bool {
    if g_asset_manager.is_fetching && g_asset_manager.current_fetch.should_block then return true;
    for g_asset_manager.fetch_queue {
        if it.should_block then return true;
    }
    return false;
}

asset_manager_tick :: () {
    #if !FLAG_RELEASE_BUILD && OS != .WASM {
        if g_asset_manager.pending_hot_reload && !g_asset_manager.is_fetching && g_asset_manager.fetch_queue.count == 0 {
            g_asset_manager.pending_hot_reload = false;
            hot_reload_all_packs();
        }
        if g_asset_manager.hot_reload_unpause_pending && !show_loading_screen() {
            g_mixer.paused = false;
            g_asset_manager.hot_reload_unpause_pending = false;
        }
    }

    if !g_asset_manager.is_fetching && g_asset_manager.fetch_queue.count > 0 {
        req := g_asset_manager.fetch_queue[0];
        // Ordered remove from front to preserve queue priority.
        for i: 0..g_asset_manager.fetch_queue.count - 2 {
            g_asset_manager.fetch_queue[i] = g_asset_manager.fetch_queue[i + 1];
        }
        g_asset_manager.fetch_queue.count -= 1;

        g_asset_manager.current_fetch = req;
        g_asset_manager.is_fetching   = true;

        buf_ptr, buf_size := buffer_for_fetch(req.type);
        sfetch_send(*(sfetch_request_t.{
            path     = to_c_string(req.path),
            callback = fetch_callback,
            buffer   = .{ ptr = buf_ptr, size = buf_size },
        }));
    }

    sfetch_dowork();
}

load_world :: (name: string) {
    unload_current_world();
    req : Fetch_Request;
    req.type         = .WORLD;
    req.world_name   = sprint("%", name);
    req.path         = sprint("%/worlds/%/world.json", GAME_RESOURCES_DIR, name);
    req.should_block = true;
    array_add(*g_asset_manager.fetch_queue, req);
}

load_pack :: (name: string, shouldBlock: bool = true, shouldBlockEngine: bool = false) {
    req : Fetch_Request;
    req.type                = .PACK;
    req.pack_name           = sprint("%", name);
    req.path                = sprint("%/%.pack", PACK_DIR, name);
    req.should_block        = shouldBlock;
    req.should_block_engine = shouldBlockEngine;
    array_add(*g_asset_manager.fetch_queue, req);
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
