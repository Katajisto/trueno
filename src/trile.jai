#scope_file

trile_mesh_table : Table(string, Trile_Mesh);
trile_table     : Table(string, Trile);

#scope_export

editor_current_trile : *Trile = null;

TRIXEL_SIZE :: 1.0 / 16.0;

get_trile_table_ptr :: () -> *Table(string, Trile) {
    return *trile_table;
}

trile_gen_heightmap :: (trile: *Trile) {
    for x: 0..15 {
        for z: 0..15 {
            height : u8 = 16;
            for y: 0..15 {
                if trile.trixels[x][15-y][z] == 0 {
                    height -= 1;
                } else {
                    break;
                }
            }
            trile.heightmap[x][z] = height;
        }
    }   
}

// Meshes are created the first time a trile is drawn.
get_trile_mesh :: (name: string) -> (Trile_Mesh, success: bool) {
    found, mesh := table_find(*trile_mesh_table, name);
    if found  return mesh, true;
    trile, ok := get_trile(name);
    if !ok  return .{}, false;
    mesh = trile_mesh_create(trile);
    table_set(*trile_mesh_table, name, mesh);
    return mesh, true;
}

// After editing a trile's trixels in place.
trile_changed :: (trile: *Trile) {
    found, mesh := table_find(*trile_mesh_table, trile.name);
    if found  trile_mesh_update(mesh, trile);
}

forget_trile_mesh :: (name: string) {
    found, mesh := table_find(*trile_mesh_table, name);
    if !found  return;
    trile_mesh_destroy(mesh);
    table_remove(*trile_mesh_table, name);
}

set_trile :: (name: string, trile: Trile) {
    log_debug("Setting trile with name: %", name);
    saved_editor_name: string;
    if editor_current_trile then saved_editor_name = editor_current_trile.name;
    stored := table_set(*trile_table, name, trile);
    // Updated in place, so handles already uploaded with world chunks stay valid.
    trile_changed(stored);
    if saved_editor_name.count > 0 {
        editor_current_trile = table_find_pointer(*trile_table, saved_editor_name);
    }
}

get_any_trile :: () -> (*Trile, success: bool) {
  for v : trile_table {
    print("Found trile: %\n", v.name);
    trileptr, err := get_trile(v.name);
    return trileptr, err;
  }
  return null, false;
}

get_trile :: (name: string) -> (*Trile, success: bool) {
    trileptr := table_find_pointer(*trile_table, name);
    if !trileptr {
        log_error("Failed to get trile with name: %", name);
        return null, false;
    }
    return trileptr, true;
}

rename_trile :: (old_name: string, new_name: string) {
    trile := get_trile(old_name);
    if !trile return;
    was_current := editor_current_trile != null && editor_current_trile.name == old_name;
    forget_trile_mesh(old_name);
    copy := trile.*;
    copy.name = sprint("%", new_name);
    set_trile(copy.name, copy);
    table_remove(*trile_table, old_name);
    if was_current  editor_current_trile = table_find_pointer(*trile_table, new_name);
}

delete_trile :: (name: string) {
    forget_trile_mesh(name);
    table_remove(*trile_table, name);
    if editor_current_trile != null && editor_current_trile.name == name {
        editor_current_trile = null;
    }
}

lstrile :: () -> string {
    count := 0;
    for v : trile_table {
        console_add_output_line(sprint("%", v.name));
        count += 1;
    }
    return tprint("% triles", count);
} @Command

striles :: () {
    Jaison :: #import "Jaison";
    sswatches();
    triles : [..]TrileSerialize;
    triles.allocator = temp;
    for v : trile_table {
        array_add(*triles, trile_to_serialize_form(v));
    }
    #if OS != .WASM {
        file :: #import "File";
        json := Jaison.json_write_string(triles, " ");
        file.write_entire_file(tprint("%/game_core/triles.json", GAME_RESOURCES_DIR), json);
        
    }
} @Command

ltriles :: () {
    Jaison :: #import "Jaison";
    lswatches();
    s := load_string_from_pack("game_core", "triles.json");
    success, triles := Jaison.json_parse_string(s, [..]TrileSerialize,, temp);
    for triles {
        set_trile(sprint("%",it.name), trile_from_serialize_form(it));
        log_debug("Loaded %", it.name);
    }
} @Command

MAX_SWATCHES :: 256;

// A colour and the material that goes with it. Trixels store the index into
// g_swatches; index 0 is never used and means empty.
Swatch :: struct {
    used      : bool;
    name      : string;
    color        : [3]u8;
    reflectivity : u8;     // how much of the floor reflection shows, 0..255
    gloss        : u8;     // strength and sharpness of the sun highlight, 0..255
    emittance    : u8;
    glass        : bool;   // lets sunlight through, but can't be seen through
}

g_swatches : [MAX_SWATCHES]Swatch;

swatch_add :: (name: string, color: [3]u8) -> u8, success: bool {
    for 1..MAX_SWATCHES-1 {
        if g_swatches[it].used  continue;
        g_swatches[it] = .{used = true, name = copy_string(name), color = color};
        swatch_changed(xx it);
        return cast(u8) it, true;
    }
    log_error("All % swatches are in use", MAX_SWATCHES - 1);
    return 0, false;
}

// 1 when there are no swatches yet, so the trixels still exist.
first_used_swatch :: () -> u8 {
    for 1..MAX_SWATCHES-1  if g_swatches[it].used  return xx it;
    return 1;
}

// New triles start as a solid cube, so the editor has something to click on.
trile_fill :: (trile: *Trile, swatch: u8) {
    for x: 0..15  for y: 0..15  for z: 0..15  trile.trixels[x][y][z] = swatch;
}

swatch_changed :: (id: u8) {
    s := g_swatches[id];
    swatch_set(id, s.color, s.reflectivity, s.gloss, s.emittance, s.glass);
}

swatch_color :: (id: u8) -> Vector3 {
    c := g_swatches[id].color;
    return .{c[0] / 255.0, c[1] / 255.0, c[2] / 255.0};
}

// How many trixels of each swatch the trile has, by swatch id.
trile_swatch_counts :: (trile: *Trile) -> [MAX_SWATCHES]s32 {
    counts : [MAX_SWATCHES]s32;
    for x: 0..15  for y: 0..15  for z: 0..15  counts[trile.trixels[x][y][z]] += 1;
    counts[0] = 0;
    return counts;
}

swatch_label :: (id: u8) -> string {
    if !g_swatches[id].used  return tprint("%: (missing)", id);
    return tprint("%: %", id, g_swatches[id].name);
}

swatch_in_use :: (id: u8) -> bool {
    for trile: trile_table {
        for x: 0..15  for y: 0..15  for z: 0..15 {
            if trile.trixels[x][y][z] == id  return true;
        }
    }
    return false;
}

Swatch_Serialize :: struct {
    id        : int;
    name      : string;
    color        : [3]u8;
    reflectivity : u8;
    gloss        : u8;
    emittance    : u8;
    glass        : bool;
}

sswatches :: () {
    Jaison :: #import "Jaison";
    list : [..]Swatch_Serialize;
    list.allocator = temp;
    for g_swatches {
        if !it.used  continue;
        array_add(*list, .{it_index, it.name, it.color, it.reflectivity, it.gloss, it.emittance, it.glass});
    }
    #if OS != .WASM {
        file :: #import "File";
        json := Jaison.json_write_string(list, " ");
        file.write_entire_file(tprint("%/game_core/swatches.json", GAME_RESOURCES_DIR), json);
    }
} @Command

lswatches :: () {
    Jaison :: #import "Jaison";
    for *g_swatches  it.* = .{};
    data, found := get_raw_file_from_pack("game_core", "swatches.json");
    if !found  return;
    _, list := Jaison.json_parse_string(xx data, [..]Swatch_Serialize,, temp);
    for list {
        if it.id < 1 || it.id >= MAX_SWATCHES  continue;
        g_swatches[it.id] = .{used = true, name = sprint("%", it.name), color = it.color, reflectivity = it.reflectivity, gloss = it.gloss, emittance = it.emittance, glass = it.glass};
    }
    for 0..MAX_SWATCHES-1  swatch_changed(xx it);
} @Command

Palette_Entry :: struct {
    name      : string;
    r         : float = 1.0;
    g         : float = 0.0;
    b         : float = 1.0;
}

Loaded_Palette :: struct {
    name    : string;
    entries : [..]Palette_Entry;
}

g_palettes : [..]Loaded_Palette;

// Adds a swatch for every colour in the palette that no swatch has yet.
swatch_import_palette :: (palette: Loaded_Palette) -> added: int {
    added := 0;
    for entry: palette.entries {
        color := u8.[
            cast(u8) clamp(entry.r * 255 + 0.5, 0, 255),
            cast(u8) clamp(entry.g * 255 + 0.5, 0, 255),
            cast(u8) clamp(entry.b * 255 + 0.5, 0, 255),
        ];
        exists := false;
        for g_swatches {
            if it.used && it.color[0] == color[0] && it.color[1] == color[1] && it.color[2] == color[2] {
                exists = true;
                break;
            }
        }
        if exists  continue;
        _, ok := swatch_add(entry.name, color);
        if !ok  break;
        added += 1;
    }
    return added;
}

Trile :: struct {
    name      : string = "test";
    is_opaque : bool   = true;
    trixels   : [16][16][16]u8;   // swatch ids, 0 = empty

    skip_collision : bool;
    
    // if the trile is something that should
    // be able to be used so that the player
    // moves in the Y direction, it needs to
    // be marked as stairs and a heightmap
    // in the Y axis is generated for it.
    is_stairs      : bool;
    heightmap      : [16][16]u8;

    cut            : Trile_Cut;   // what the camera may cut away indoors
};

TrileSerialize :: struct {
    name           : string = "test";
    is_opaque      : u8     = 1;
    is_stairs      : u8     = 0;
    skip_collision : u8     = 0;
    cut            : u8     = 0;
    trixels        : string;   // base64 of the 16^3 swatch ids
};

trile_to_serialize_form :: (t: Trile) -> TrileSerialize {
    return .{
        name           = t.name,
        is_opaque      = ifx t.is_opaque then cast(u8)1 else cast(u8)0,
        is_stairs      = ifx t.is_stairs then cast(u8)1 else cast(u8)0,
        skip_collision = ifx t.skip_collision then cast(u8)1 else cast(u8)0,
        cut            = xx t.cut,
        trixels        = base64_encode(.{size_of(type_of(t.trixels)), cast(*u8) *t.trixels},, temp),
    };
}

trile_from_serialize_form :: (ts: TrileSerialize) -> Trile {
    t := Trile.{ name = sprint("%", ts.name) };
    t.is_opaque      = ts.is_opaque != 0;
    t.is_stairs      = ts.is_stairs != 0;
    t.skip_collision = ts.skip_collision != 0;
    t.cut            = xx ts.cut;
    ids, ok := base64_decode(ts.trixels,, temp);
    if ok && ids.count == size_of(type_of(t.trixels)) {
        memcpy(*t.trixels, ids.data, ids.count);
    } else {
        log_error("Trile % has broken trixel data", ts.name);
    }
    trile_gen_heightmap(*t);
    return t;
}

#scope_file

#import "Base64";
