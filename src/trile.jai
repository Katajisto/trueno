#load "meshgen.jai";

#scope_file

trile_gfx_table : Table(string, Trile_GFX);
trile_table     : Table(string, Trile);

#scope_export

Trile_GFX :: struct {
    vertex_buffer : sg_buffer;
    normal_buffer : sg_buffer;
    vertex_count  : s64;
};

// @Note: Creates the gfx things if they are not yet created.
// Could be a bad idea to do this implicitly. Think about it
// once it's more clear how this whole trile storage thing 
// will pan out. -ktjst
get_trile_gfx :: (name: string) -> (Trile_GFX, success: bool) {
    value, success := table_find(*trile_gfx_table, name);
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
        }
    }
    table_set(*trile_gfx_table, name, gfx);
}

set_trile :: (name: string, trile: Trile) {
    table_set(*trile_table, name, trile);
}

get_trile :: (name: string) -> (*Trile, success: bool) {
    trileptr := table_find_pointer(*trile_table, name);
    if !trileptr {
        print("Failed to get trile with name: %\n", name);
        return null, false;
    }
    return trileptr, true;
}

Material :: struct {
    roughness : float   = 0.5;
    metallic  : float   = 0;
    emittance : float   = 0;
    color     : Vector3 = .{1.0, 0.0, 1.0};
}

Trixel :: struct {
    material : Material;
    empty    : bool = false;
};

Trile  :: struct {
    trixels : [16][16][16] Trixel;  
};
