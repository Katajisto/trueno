#scope_file

#import "String";
hash :: #import "Hash";

#load "loaders.jai";

MAX_FILE_SIZE :: 200_000_000;
buf       : [MAX_FILE_SIZE]u8;
world_buf : [MAX_FILE_SIZE]u8;

Pack_Request :: struct {
    name              : string;
    shouldBlock       : bool;
    loading           : bool = false;
    shouldBlockEngine : bool; // Means that the engine loop should do nothing while this is loading...
}

World_Load_Request :: struct {
    name    : string;
    pending : bool = false;
    loading : bool = false;
}

Asset_Manager :: struct {
    packQueue    : [..]Pack_Request;
    loadedPacks  : [..]Loaded_Pack;
    worldRequest : World_Load_Request;
}

g_asset_manager : Asset_Manager;

packcb :: (res: *sfetch_response_t) #c_call {
    push_context,defer_pop default_context;
    mem := NewArray(res.data.size.(s64), u8, false);
    memcpy(mem.data, res.data.ptr, res.data.size.(s64));

    pack: Loaded_Pack;
    pack.nameHash = hash.get_hash(g_asset_manager.packQueue[0].name);
    pack.name = g_asset_manager.packQueue[0].name;
    success := init_from_memory(*pack.content, mem, sprint("%", g_asset_manager.packQueue[0].name));
    if !success then print("Failed to load pack!!\n");
    add_resources_from_pack(*pack);
    array_add(*g_asset_manager.loadedPacks, pack);
    array_unordered_remove_by_index(*g_asset_manager.packQueue, 0);
}

worldcb :: (res: *sfetch_response_t) #c_call {
    push_context,defer_pop default_context;
    if res.failed {
        print("Failed to load world '%'\n", g_asset_manager.worldRequest.name);
        g_asset_manager.worldRequest = .{};
        return;
    }
    data: []u8;
    data.data = res.data.ptr;
    data.count = res.data.size.(s64);
    world, ok := load_world_from_data(data);
    if ok {
        set_loaded_world(world);
        print("Loaded world: %\n", world.name);
    } else {
        print("Failed to parse world '%'\n", g_asset_manager.worldRequest.name);
    }
    g_asset_manager.worldRequest = .{};
}

Loaded_Pack :: struct {
    name       : string;
    nameHash   : u32 = 0;
    content    : Load_Package;
    textures   : Table(string, sg_image);
    animations : Table(string, Animation);
    audio      : Table(string, Audio_Data);
    //fonts    : [..]Font??;
}

add_resources_from_pack :: (pack: *Loaded_Pack) {
    // We need to go trough this at the end.
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
                    print("Failed to parse animation sheet JSON for sheet(%)\n", name);
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
            case "ttf";
            // Load into a font. Add to free list.
            case;
                print("There was file(%) in pack(%), that did not match any known fileformat...\n", v.name, pack);
        }
        print("% -> %\n", v.name, extension);
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
            print("Added anim(%)\n", anim.name);            
        }
    }

    // add_new_spritesheets_from_pack(*pack.content, pack.name);
    // load_color_lut_images(*pack.content, pack.name);
}

free_resources_from_pack :: (pack: *Loaded_Pack) {
    
}

find_pack_by_name :: (name: string) -> (bool, Loaded_Pack) {
    nameHash := get_hash(name);
    for g_asset_manager.loadedPacks {
        if it.nameHash == nameHash {
            return true, it;
        }
    }
    print("[WARNING] Was unable to find pack: %\n", name);
    return false, .{};
}

#scope_export

// Pack management:

mandatory_loads_done :: () -> bool {
    for g_asset_manager.packQueue {
        if it.shouldBlockEngine return false;
    }
    return true;
}

show_loading_screen :: () -> bool {
    if g_asset_manager.worldRequest.pending return true;
    for g_asset_manager.packQueue {
        if it.shouldBlock return true;
    }
    return false;
}

asset_manager_tick :: () {
    if g_asset_manager.packQueue.count > 0 && !g_asset_manager.packQueue[0].loading {
        sfetch_send(*(sfetch_request_t.{
            path = to_c_string(tprint("./packs/%.pack", g_asset_manager.packQueue[0].name)),
            callback = packcb,
            buffer = .{
                ptr = buf.data,
                size = buf.count
            }
        }));
        g_asset_manager.packQueue[0].loading = true;
    }

    if g_asset_manager.worldRequest.pending && !g_asset_manager.worldRequest.loading {
        sfetch_send(*(sfetch_request_t.{
            path = to_c_string(tprint("./game/resources/worlds/%/index.world", g_asset_manager.worldRequest.name)),
            callback = worldcb,
            buffer = .{
                ptr = world_buf.data,
                size = world_buf.count
            }
        }));
        g_asset_manager.worldRequest.loading = true;
    }

    sfetch_dowork();
}

load_world :: (name: string) {
    unload_current_world();
    g_asset_manager.worldRequest = .{
        name = name,
        pending = true,
    };
}

load_pack :: (name: string, shouldBlock: bool = true, shouldBlockEngine: bool = false) {
    array_add(*g_asset_manager.packQueue, .{
        name = name,
        shouldBlock = shouldBlock,
        shouldBlockEngine = shouldBlockEngine
    });
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
        print("[WARNING] Failed to find texture(%) from pack(%)\n", path, pack.name);
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
    if !audio then print("Failed to find audio(%)\n", path);
    return audio;
}

add_font_from_pack :: (pack: string, path: string) {
    pack_ok, pack := find_pack_by_name(pack);
    if !pack_ok then return;
    ok, entry := table_find(*pack.content.lookup, path);
    if !ok {
        print("Failed to find font % from pack...\n", path);
        return;
    }
    state.font_default.fons_font = fonsAddFontMem(state.fons, "sans", entry.data.data, xx entry.data.count, 0);
}

load_string_from_pack :: (pack: string, path: string) -> string {
    print("Warning: you are circumventing the asset management system....\n");
    pack_ok, pack := find_pack_by_name(pack);
    if !pack_ok return "";
    
    ok, entry := table_find(*pack.content.lookup, path);
    if !ok {
        print("Failed to load string from pack: %\n", path);
        return "";
    }

    s: string;
    s.data = entry.data.data;
    s.count = entry.data.count;
    return s;
}
