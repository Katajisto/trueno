#scope_file

#import "String";
hash :: #import "Hash";
Pool :: #import "Pool";

#load "loaders.jai";

// MAX_PACK_SIZE, MAX_WORLD_SIZE and MAX_CHUNKS_SIZE are injected as build strings
// by first.jai after scanning the actual asset files at compile time.

MAX_FETCH_SLOTS :: 16;

#scope_export

// Replaces the old should_block / should_block_engine bool pair.
Load_Priority :: enum u8 {
    BLOCK_ENGINE;    // must finish before the first game frame
    LOADING_SCREEN;  // show loading screen while pending
    BACKGROUND;      // stream silently; game runs normally
}

Fetch_Type :: enum {
    PACK;
    WORLD;
    WORLD_CHUNKS;
    WORLD_PROBES;
}

Fetch_Request :: struct {
    type              : Fetch_Type;
    path              : string;
    priority          : Load_Priority;

    // PACK
    pack_name         : string;

    // WORLD
    world_name        : string;

    // WORLD_CHUNKS: JSON carried forward from the WORLD fetch
    world_json_data   : []u8;
}

// One in-flight sfetch request.  `buf` is allocated when dispatched and
// freed (or handed to Loaded_Pack) when the callback fires.
Fetch_Slot :: struct {
    occupied : bool;
    req      : Fetch_Request;
    buf      : []u8;
}

Asset_Manager :: struct {
    slots                      : [MAX_FETCH_SLOTS]Fetch_Slot;
    queue                      : [..]Fetch_Request;
    loadedPacks                : [..]Loaded_Pack;
    pending_hot_reload         : bool;
    hot_reload_unpause_pending : bool;
}

g_asset_manager : Asset_Manager;

#scope_file

fetch_type_buffer_size :: (type: Fetch_Type) -> s64 {
    if #complete type == {
        case .PACK;         return MAX_PACK_SIZE;
        case .WORLD;        return MAX_WORLD_SIZE;
        case .WORLD_CHUNKS; return MAX_CHUNKS_SIZE;
        case .WORLD_PROBES; return MAX_PROBES_SIZE;
    }
}

fetch_callback :: (res: *sfetch_response_t) #c_call {
    push_context,defer_pop default_context;

    // sokol copied the slot index into res.user_data when we sent the request.
    slot_idx := (cast(*u32) res.user_data).*;
    slot     := *g_asset_manager.slots[slot_idx];

    if !res.finished then return;

    slot.occupied = false;
    req := slot.req;

    if res.failed {
        handle_fetch_failed(*req);
        free(slot.buf.data);
        slot.buf = .{};
        return;
    }

    data: []u8;
    data.data  = cast(*u8) res.data.ptr;
    data.count = cast(s64) res.data.size;

    process_completed_fetch(*req, data);

    if req.type == .PACK {
        // process_completed_fetch transferred ownership to Loaded_Pack.data_buffer.
        slot.buf = .{};
    } else {
        free(slot.buf.data);
        slot.buf = .{};
    }
}

handle_fetch_failed :: (req: *Fetch_Request) {
    if req.type == {

    case .PACK;
        log_error("Failed to load pack '%'", req.pack_name);

    case .WORLD;
        if ends_with(req.path, "world.json") {
            fallback: Fetch_Request;
            fallback.type       = .WORLD;
            fallback.priority   = req.priority;
            fallback.world_name = req.world_name;
            fallback.path       = sprint("%/worlds/%/index.world", GAME_RESOURCES_DIR, req.world_name);
            array_add(*g_asset_manager.queue, fallback);
            return;
        }
        log_error("Failed to load world '%'", req.world_name);

    case .WORLD_CHUNKS;
        free(req.world_json_data.data);
        log_error("Failed to load chunks.bin for world '%'", req.world_name);

    case .WORLD_PROBES;
        log_info("No baked probes for world '%'", req.world_name);

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
        json_copy := NewArray(data.count, u8, false);
        memcpy(json_copy.data, data.data, data.count);
        chunks_req: Fetch_Request;
        chunks_req.type            = .WORLD_CHUNKS;
        chunks_req.priority        = req.priority;
        chunks_req.world_name      = req.world_name;
        chunks_req.path            = sprint("%/worlds/%/chunks.bin", GAME_RESOURCES_DIR, req.world_name);
        chunks_req.world_json_data = json_copy;
        array_add(*g_asset_manager.queue, chunks_req);

    case .WORLD_CHUNKS;
        json_data := req.world_json_data;
        defer free(json_data.data);

        json_str: string;
        json_str.data  = json_data.data;
        json_str.count = json_data.count;

        world, ok := load_world_from_json(json_str, data);
        if ok {
            set_loaded_world(world);
            log_info("Loaded world: %", req.world_name);
            probes_req: Fetch_Request;
            probes_req.type       = .WORLD_PROBES;
            probes_req.priority   = .BACKGROUND;
            probes_req.world_name = req.world_name;
            probes_req.path       = sprint("%/worlds/%/probes.bin", GAME_RESOURCES_DIR, req.world_name);
            array_add(*g_asset_manager.queue, probes_req);
        } else {
            log_error("Failed to parse world '%'", req.world_name);
        }

    case .WORLD_PROBES;
        // Another world may have been loaded while these were on the way.
        curworld := get_current_world();
        if !curworld.valid || curworld.world.name != req.world_name  return;
        if !load_probes(data)  log_error("Broken probes.bin for world '%'", req.world_name);

    }
}

Loaded_Pack :: struct {
    name        : string;
    nameHash    : u32 = 0;
    data_buffer : []u8;
    content     : Load_Package;
    textures    : Table(string, Texture);
    animations  : Table(string, Animation);
    audio       : Table(string, Audio_Data);
    pool        : Pool.Pool;
}

add_resources_from_pack :: (pack: *Loaded_Pack) {
    push_allocator(.{Pool.pool_allocator_proc, *pack.pool});

    Queued_Sheet_File :: struct {
        name    : string;
        image   : Texture;
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
            case "wav";
                audio := load_wav_from_memory(v.data);
                table_set(*pack.audio, name, audio);
            case "ogg";
                audio := load_ogg_from_memory(v.data);
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
                } else if name == "foliage" {
                    load_foliage_defs_from_json(create_string_from_memory(v.data));
                }
            case "hex";
                pal : Loaded_Palette;
                pal.name = sprint("%", name);
                pal.entries = load_hex_palette_from_memory(v.data);
                // Pack hot reload brings the same palettes in again.
                replaced := false;
                for *g_palettes  if it.name == pal.name { it.* = pal; replaced = true; }
                if !replaced  array_add(*g_palettes, pal);
                log_info("Loaded % colors from hex palette(%)", pal.entries.count, v.name);
            case "ttf";
            case;
                log_warn("File(%) in pack(%) has unknown format", v.name, pack.name);
        }
        log_debug("% -> %", v.name, extension);
    }

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

// Removes the highest-priority item from the queue (lowest enum value = most urgent).
// Within equal priority, the earliest-queued item wins (stable).
dequeue_highest_priority :: (queue: *[..]Fetch_Request) -> (Fetch_Request, bool) {
    if queue.count == 0 return .{}, false;
    best := 0;
    for i: 1..queue.count - 1 {
        if queue.*[i].priority < queue.*[best].priority then best = i;
    }
    req := queue.*[best];
    array_ordered_remove_by_index(queue, best);
    return req, true;
}

dispatch_slots :: () {
    for i: 0..MAX_FETCH_SLOTS - 1 {
        slot := *g_asset_manager.slots[i];
        if slot.occupied continue;
        if g_asset_manager.queue.count == 0 break;

        req, found := dequeue_highest_priority(*g_asset_manager.queue);
        if !found break;

        slot.occupied = true;
        slot.req      = req;
        slot.buf      = NewArray(fetch_type_buffer_size(req.type), u8, false);

        // sokol copies user_data bytes immediately on sfetch_send, so a
        // stack-local index is safe here.
        slot_idx : u32 = cast(u32) i;

        // Route BACKGROUND requests to channel 1 so they don't starve
        // LOADING_SCREEN / BLOCK_ENGINE work on native (two IO threads).
        channel : u32 = ifx req.priority == .BACKGROUND then cast(u32)1 else cast(u32)0;

        path_c := to_c_string(req.path);
        defer free(path_c);

        sfetch_send(*(sfetch_request_t.{
            channel   = channel,
            path      = path_c,
            callback  = fetch_callback,
            buffer    = .{ ptr = slot.buf.data, size = cast(u64) slot.buf.count },
            user_data = .{ ptr = *slot_idx,     size = cast(u64) size_of(u32) },
        }));
    }
}

#scope_export

free_resources_from_pack :: (pack: *Loaded_Pack) {
    for pack.textures  texture_destroy(it);
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
    // No upfront allocations; buffers are allocated per-request in dispatch_slots.
}

mandatory_loads_done :: () -> bool {
    for g_asset_manager.slots {
        if it.occupied && it.req.priority == .BLOCK_ENGINE then return false;
    }
    for g_asset_manager.queue {
        if it.priority == .BLOCK_ENGINE then return false;
    }
    return true;
}

show_loading_screen :: () -> bool {
    for g_asset_manager.slots {
        if it.occupied && it.req.priority != .BACKGROUND then return true;
    }
    for g_asset_manager.queue {
        if it.priority != .BACKGROUND then return true;
    }
    return false;
}

asset_manager_tick :: () {
    #if !FLAG_RELEASE_BUILD && OS != .WASM {
        all_idle := true;
        for g_asset_manager.slots if it.occupied { all_idle = false; break; }

        if g_asset_manager.pending_hot_reload && all_idle && g_asset_manager.queue.count == 0 {
            g_asset_manager.pending_hot_reload = false;
            hot_reload_all_packs();
        }
        if g_asset_manager.hot_reload_unpause_pending && !show_loading_screen() {
            g_mixer.paused = false;
            g_asset_manager.hot_reload_unpause_pending = false;
        }
    }

    sfetch_dowork();
    dispatch_slots();
}

load_world :: (name: string) {
    unload_current_world();
    req: Fetch_Request;
    req.type       = .WORLD;
    req.priority   = .LOADING_SCREEN;
    req.world_name = sprint("%", name);
    req.path       = sprint("%/worlds/%/world.json", GAME_RESOURCES_DIR, name);
    array_add(*g_asset_manager.queue, req);
}

load_pack :: (name: string, priority: Load_Priority = .LOADING_SCREEN) {
    req: Fetch_Request;
    req.type      = .PACK;
    req.priority  = priority;
    req.pack_name = sprint("%", name);
    req.path      = sprint("%/%.pack", PACK_DIR, name);
    array_add(*g_asset_manager.queue, req);
}

// Asset accessors:

#scope_file
#scope_export

get_texture_from_pack :: (pack: string, path: string) -> (Texture) {
    found, pack := find_pack_by_name(pack);
    invalid_img : Texture;

    if !found {
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
    state.font_default.face = font_face_add("sans", entry.data);
}

// For files that may legitimately be absent from a pack.
get_raw_file_from_pack :: (pack: string, path: string) -> ([]u8, found: bool) {
    pack_ok, loaded := find_pack_by_name(pack);
    if !pack_ok return .[], false;
    ok, entry := table_find(*loaded.content.lookup, path);
    if !ok return .[], false;
    return entry.data, true;
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
