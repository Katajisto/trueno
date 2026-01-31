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
    nameHash : u32 = 0;
    content  : Load_Package;
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
    success := init_from_memory(*pack.content, mem, sprint("%", g_asset_manager.packQueue[0].name));
    if !success then print("Failed to load pack!!\n");
    array_add(*g_asset_manager.loadedPacks, pack);
    array_unordered_remove_by_index(*g_asset_manager.packQueue, 0);
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


