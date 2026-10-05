// Our foliage system. Cells on a 2D grid.

Foliage_Type :: enum u8 {
    GRASS; // For stuff that you want to just paint and gets rendered a lot. Grass or hay.
    TREE;  // For when you want single placements of something. Trees or bushes.
}

Foliage_Frame_Mode :: enum u8 {
    VARIANT; // The seed picks one frame and it stays there.
    LOOP;    // Plays the animation, with the seed offsetting the start.
}

Foliage_Def :: struct {
    name           : string;
    type           : Foliage_Type;

    // What we render
    animation_name : string;
    frame_mode     : Foliage_Frame_Mode;

    density        : float = 0.5; // Only does anything when foliage type is grass.
    scale_min      : float = 1;
    scale_max      : float = 1;
    jitter         : float = 0.4;
    sway_intensity : float;
    sway_speed     : float = 1;
}

FOLIAGE_NONE :: 0;

// Chunks in the world contain a 2D grid of these.
Foliage_Cell :: struct {
    id : u8; // FOLIAGE_NONE when empty.
    y  : u8; // Local y inside the chunk, so we don't draw grass on top of a bridge.
}

g_foliage_defs : [..]Foliage_Def;

get_foliage_def :: (name: string) -> *Foliage_Def {
    for *def: g_foliage_defs {
        if def.name == name then return def;
    }
    return null;
}

register_foliage_def :: (def: Foliage_Def) {
    for *existing: g_foliage_defs {
        if existing.name == def.name {
            existing.* = def;
            return;
        }
    }
    array_add(*g_foliage_defs, def);
}

get_foliage_def_names :: () -> []string {
    names : [..]string;
    names.allocator = temp;
    for def: g_foliage_defs {
        array_add(*names, def.name);
    }
    return names;
}

load_foliage_defs_from_json :: (s: string) {
    success, defs := Jaison.json_parse_string(s, [..]Foliage_Def,, temp);
    if !success {
        log_error("Failed to parse foliage definitions");
        return;
    }
    array_reset(*g_foliage_defs);
    for defs {
        def := it;
        def.name           = sprint("%", it.name);
        def.animation_name = sprint("%", it.animation_name);
        array_add(*g_foliage_defs, def);
    }
    log_info("Loaded % foliage definitions from pack", g_foliage_defs.count);
}

save_foliage_defs :: () {
    #if OS != .WASM {
        file :: #import "File";
        json := Jaison.json_write_string(g_foliage_defs, " ");
        file.write_entire_file(tprint("%/game_core/foliage.json", GAME_RESOURCES_DIR), json);
        log_info("Saved % foliage definitions", g_foliage_defs.count);
    }
}
