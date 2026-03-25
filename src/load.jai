#if FLAG_TEST_EXE_ENGINE {
    PACK_DIR           :: "./test_packs";
    GAME_RESOURCES_DIR :: "./test_game/resources";
} else {
    PACK_DIR           :: "./packs";
    GAME_RESOURCES_DIR :: "./game/resources";
}

g_asset_pack : Load_Package;

#scope_export

init_after_mandatory_done : bool = false;
init_after_core_done : bool = false;


asset_list :: () -> string #expand {
    count := 0;
    for v : g_asset_pack.lookup {
        console_add_output_line(sprint("% (%)", v.name, format_size(v.size_of_entry)));
        count += 1;
    }
    return tprint("> A total of % assets.", count);
} @Command

// Returns tprinted string, please copy it somewhere.
format_size :: (bytes: int) -> string {
    bytes_counter := bytes;
    bytes_float := cast(float) bytes;
    names : []string = .["b", "kb", "mb", "gb", "tb"];
    name_index := 0;
    while bytes_counter / 1000 > 0 {
        name_index += 1;
        bytes_counter /= 1000;
        bytes_float /= 1000.0;
        if name_index > 4 then break;
    }
    return tprint("% %", bytes_float, names[name_index]);
    
}
