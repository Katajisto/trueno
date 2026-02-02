#scope_file

hash :: #import "Hash";

MAX_FILE_SIZE :: 2_000_000_000;
buf : [MAX_FILE_SIZE]u8;

Pack_Request :: struct {
    name              : string;
    shouldBlock       : bool;
    loading           : bool = false;
    shouldBlockEngine : bool; // Means that the engine loop should do nothing while this is loading...
}

Loaded_Pack :: struct {
    name     : string;
    nameHash : u32 = 0;
    content  : Load_Package;
    textures : [..]sg_image;
    sounds   : [..]Audio_Data;
    //fonts    : [..]Font??;
    
}

Asset_Manager :: struct {
    packQueue   : [..]Pack_Request;
    loadedPacks : [..]Loaded_Pack;
}

g_asset_manager : Asset_Manager;

packcb :: (res: *sfetch_response_t) #c_call {
    push_context,defer_pop default_context;
    mem : []u8;
    mem.count = res.data.size.(s64);
    mem.data = res.data.ptr;
    pack: Loaded_Pack;
    pack.nameHash = hash.get_hash(g_asset_manager.packQueue[0].name);
    pack.name = g_asset_manager.packQueue[0].name;
    success := init_from_memory(*pack.content, mem, sprint("%", g_asset_manager.packQueue[0].name));
    if !success then print("Failed to load pack!!\n");
    array_add(*g_asset_manager.loadedPacks, pack);
    array_unordered_remove_by_index(*g_asset_manager.packQueue, 0);

    add_resources_from_pack(*pack);
}

add_resources_from_pack :: (pack: *Loaded_Pack) {
    add_new_spritesheets_from_pack(*pack.content, pack.name);
    load_color_lut_images(*pack.content, pack.name);
}

find_pack_by_name :: (name: string) -> (bool, Loaded_Pack) {
    nameHash := get_hash(name);
    asset_pack : Loaded_Pack;
    for g_asset_manager.loadedPacks {
        if it.nameHash == nameHash {
            return true, it;
        }
    }
    print("Was unable to find pack: %\n", name);
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
    sfetch_dowork();
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

create_texture_from_pack :: (pack: string, path: string) -> (sg_image, s32, s32) {
    pack_ok, pack := find_pack_by_name(pack);
    ok, entry := table_find(*pack.content.lookup, path);
    if !ok {
        print("Failed to find texture % from pack...\n", path);
        img : sg_image;
        return img, 0, 0;
    }
    
    x : s32;
    y : s32;
    channels : s32;
    data := stbi.stbi_load_from_memory(entry.data.data, xx entry.data.count, *x, *y, *channels, 4);
    img := sg_alloc_image();

    subimg : [6][16]sg_range;
    subimg[0][0] = .{
        ptr = data,
        size = xx (x * y * 4)
    };

    sg_init_image(img, *(sg_image_desc.{
        width = x,
        height = y,
        pixel_format = sg_pixel_format.RGBA8,
        data = .{
            subimage = subimg
        }
    }));

    stbi.stbi_image_free(data);

    return img, x, y;
}


// get_texture_pointer :: (pack: string, path: string) -> (ready: bool, texture: *sg_image) {
    
    
// }

add_font_from_pack :: (pack: string, path: string) {
    pack_ok, pack := find_pack_by_name(pack);
    if !pack_ok then return;
    for _, key : pack.content.lookup {
        print("Key: %\n", key);
    }
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
