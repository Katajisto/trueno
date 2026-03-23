#scope_file

trile_gfx_table : Table(string, Trile_GFX);
trile_table     : Table(string, Trile);

#scope_export

editor_current_trile : *Trile = null;

Trile_GFX :: struct {
    trixel_colors : sg_image;
    vertex_buffer : sg_buffer;
    normal_buffer : sg_buffer;
    centre_buffer : sg_buffer;
    vertices      : []float;
    vertex_count  : s64;
};

get_trile_table_ptr :: () -> *Table(string, Trile) {
    return *trile_table;
}

// @Note: Creates the gfx things if they are not yet created.
// Could be a bad idea to do this implicitly. Think about it
// once it's more clear how this whole trile storage thing 
// will pan out. -ktjst
get_trile_gfx :: (name: string) -> (Trile_GFX, success: bool) {
    success, value := table_find(*trile_gfx_table, name);
    if !success {
        // Check if such a trile exists. 
        trile, success_with_trile := get_trile(name);
        if success_with_trile {
            // Okay, so we have the trile, let's generate the GFX stuff for it.
            gfx := generate_trile_gfx_matias(trile);         
            set_trile_gfx(name, gfx, true);
            return gfx, true;
        } else {
            return .{}, false;
        }
    }
    return value, success;
}

set_trile_gfx :: (name: string, gfx: Trile_GFX, skip_preexist_check: bool = false) {
    if !skip_preexist_check {
        old_gfx, success := get_trile_gfx(name);
        if success {
            sg_destroy_buffer(old_gfx.vertex_buffer);
            sg_destroy_buffer(old_gfx.normal_buffer);
            sg_destroy_buffer(old_gfx.centre_buffer);
            sg_destroy_image(old_gfx.trixel_colors);
            array_reset(*old_gfx.vertices);
            log_debug("Destroyed old GFX buffers for trile: %", name);
        }
    }
    table_set(*trile_gfx_table, name, gfx);
}

set_trile :: (name: string, trile: Trile) {
    log_debug("Setting trile with name: %", name);
    // Destroy and remove any cached GFX so it gets regenerated from new data.
    gfx_exists, old_gfx := table_find(*trile_gfx_table, name);
    if gfx_exists {
        sg_destroy_buffer(old_gfx.vertex_buffer);
        sg_destroy_buffer(old_gfx.normal_buffer);
        sg_destroy_buffer(old_gfx.centre_buffer);
        sg_destroy_image(old_gfx.trixel_colors);
        array_reset(*old_gfx.vertices);
        table_remove(*trile_gfx_table, name);
    }
    saved_editor_name: string;
    if editor_current_trile then saved_editor_name = editor_current_trile.name;
    table_set(*trile_table, name, trile);
    if saved_editor_name.count > 0 {
        editor_current_trile = table_find_pointer(*trile_table, saved_editor_name);
    }
}

get_trile :: (name: string) -> (*Trile, success: bool) {
    trileptr := table_find_pointer(*trile_table, name);
    if !trileptr {
        log_error("Failed to get trile with name: %", name);
        return null, false;
    }
    return trileptr, true;
}

get_trile_roughness_set :: (trile_name: string) -> u8 {
    trile, ok := get_trile(trile_name);
    if !ok then return 1 << 7;
    mask : u8 = 1 << 7;
    for x: 0..15 {
        for y: 0..15 {
            for z: 0..15 {
                if !trile.trixels[x][y][z].empty {
                    mask |= cast(u8)(1 << trile.trixels[x][y][z].material.roughness);
                }
            }
        }
    }
    return mask;
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
    triles : [..]TrileSerialize;
    triles.allocator = temp;
    for v : trile_table {
        array_add(*triles, trile_to_serialize_form(v));
    }
    #if OS != .WASM {
        file :: #import "File";
        json := Jaison.json_write_string(triles, " ");
        file.write_entire_file("./game/resources/game_core/triles.json", json);
        
    }
} @Command

ltriles :: () {
    Jaison :: #import "Jaison";
    s := load_string_from_pack("game_core", "triles.json");
    success, triles := Jaison.json_parse_string(s, [..]TrileSerialize,, temp);
    for triles {
        set_trile(sprint("%",it.name), trile_from_serialize_form(it));
        log_debug("Loaded %", it.name);
    }
} @Command

Material :: struct {
    addRoughness : u8 = 0;
    roughness : u8 = 4;
    metallic  : u8 = 0;
    emittance : u8 = 0;
    color     : Vector3 = .{1.0, 0.0, 1.0};
}

Trixel :: struct {
    material : Material;
    empty    : bool = false;
};

Trile :: struct {
    name    : string = "test";
    trixels : [16][16][16] Trixel;  
};

TrixelSerialize :: [5]u8;

TrileSerialize :: struct {
    name    : string = "test";
    trixels : [16][16][16] TrixelSerialize;  
};

trile_to_serialize_form :: (t: Trile) -> TrileSerialize {
    ts := TrileSerialize.{
        name = t.name,
    };
    for i: 0..15 {
        for j: 0..15 {
            for k: 0..15 {
                r,g,b,a := material_to_rgba(t.trixels[i][j][k].material);
                ts.trixels[i][j][k] = .[ifx t.trixels[i][j][k].empty then cast(u8)0 else cast(u8)1, r,g,b,a]; 
            }
        }
    }
    return ts;
}

trile_from_serialize_form :: (ts: TrileSerialize) -> Trile {
    t := Trile.{
        name = sprint("%",ts.name)
    };
    for i: 0..15 {
        for j: 0..15 {
            for k: 0..15 {
                matinfo := ts.trixels[i][j][k];
                mat := material_from_rgba(matinfo[1], matinfo[2], matinfo[3], matinfo[4]);
                t.trixels[i][j][k].material = mat;
                t.trixels[i][j][k].empty = matinfo[0] == 0;
            }
        }
    }
    return t;
}

material_encode_to_char :: (mat: Material) -> u8 {
    return (mat.addRoughness & 0x1) | ((mat.emittance & 0x3) << 1) |
            ((mat.metallic & 0x3) << 3) | ((mat.roughness & 0x7) << 5);
}

material_encode_to_float :: (mat: Material) -> float {
    return cast(float)(material_encode_to_char(mat)) / 255.0;
}

material_decode_from_char :: (packedMaterial: u8) -> Material {
    mat : Material;
    mat.emittance    = (packedMaterial >> 1) & 3;
    mat.roughness    = (packedMaterial >> 5) & 7;
    mat.metallic     = (packedMaterial >> 3) & 3;
    return mat;
}

material_to_rgba :: (mat: Material) -> (r: u8, g: u8, b: u8, a: u8) {
    r : u8 = cast(u8) (mat.color.x * 255.0);
    g : u8 = cast(u8) (mat.color.y * 255.0);
    b : u8 = cast(u8) (mat.color.z * 255.0);
    a : u8 = material_encode_to_char(mat);
    return r,g,b,a;
}

material_from_rgba :: (r: u8, g: u8, b: u8, a: u8) -> Material {
    mat := material_decode_from_char(a);
    mat.color.x = (cast(float) r)/255.0;
    mat.color.y = (cast(float) g)/255.0;
    mat.color.z = (cast(float) b)/255.0;
    return mat;
}

draw_trile_picker :: (r_in: GR.Rect, theme: *GR.Overall_Theme) {
    r   := r_in;
	tpt := get_trile_table_ptr();
	r.h = ui_h(4,4);
	count := 0;
	for v : tpt {
		if GR.button(r, v.name, *t_button_selectable(theme, editor_current_trile != null && editor_current_trile.name == v.name), count) {
			editor_current_trile = get_trile(v.name);
		}
		count += 1;
		r.y += r.h;
	}
}
