#if !FLAG_RELEASE_BUILD && OS != .WASM {

#import "String";
Pack_Writer :: #import "Simple_Package";
File_Util   :: #import "File_Utilities";
File_IO     :: #import "File";

_hotreload_visitor :: (info: *File_Util.File_Visit_Info, packs: *Table(string, Pack_Writer.Create_Package)) {
    {
        ok, left, right := split_from_right(info.short_name, #char ".");
        if right == "aseprite" return;
    }
    if contains(info.full_name, "/worlds/") return;

    _, _, pack_path := split_from_left(info.full_name, "/resources/");
    _, pack_name, file_name := split_from_left(pack_path, "/");

    if !table_contains(packs, pack_name) {
        package: Pack_Writer.Create_Package;
        Pack_Writer.init(*package);
        table_set(packs, pack_name, package);
    }

    pack_ptr := table_find_pointer(packs, pack_name);

    file_content, ok := File_IO.read_entire_file(info.full_name);
    if !ok {
        log_warn("Hot-reload: failed to read '%'", info.full_name);
        return;
    }
    data: []u8;
    data.data  = file_content.data;
    data.count = file_content.count;
    Pack_Writer.add(pack_ptr, file_name, data);
}

recreate_packs_on_disk :: () {
    packs: Table(string, Pack_Writer.Create_Package);
    File_Util.visit_files("./resources",      true, *packs, _hotreload_visitor);
    File_Util.visit_files(GAME_RESOURCES_DIR, true, *packs, _hotreload_visitor);
    for pack, key: packs {
        Pack_Writer.write(*pack, tprint("%/%.pack", PACK_DIR, key));
        log_info("Hot-reload: wrote pack '%'", key);
    }
}

hot_reload_all_packs :: () {
    pack_names: [..]string;
    pack_names.allocator = temp;
    for pack: g_asset_manager.loadedPacks {
        array_add(*pack_names, sprint("%", pack.name));
    }

    array_reset(*g_asset_manager.main_queue);

    g_mixer.paused = true;
    g_asset_manager.hot_reload_unpause_pending = true;

    // Clear tasks while holding the lock so the audio thread can't be
    // mid-sample when we free the audio data below.
    mixer_lock(*g_mixer);
    array_reset(*g_mixer.tasks);
    mixer_unlock(*g_mixer);

    for *pack: g_asset_manager.loadedPacks {
        free_resources_from_pack(pack);
    }
    array_reset(*g_asset_manager.loadedPacks);

    // Force init_after_core to re-run once the new packs are loaded,
    // so that all pack-dependent state (textures, post-process, game_init, etc.)
    // is refreshed with the new content.
    init_after_core_done = false;

    log_info("Hot-reload: recreating packs on disk...");
    recreate_packs_on_disk();

    for name: pack_names {
        load_pack(name, true, false);
    }
    log_info("Hot-reload: queued % pack(s) for reload", pack_names.count);
}

} // #if !RELEASE_BUILD && OS != .WASM
