#load "meshgen.jai";

#scope_file

trile_table : Table(string, Mesh);

#scope_export

Mesh :: struct {
    vertex_buffer : sg_buffer;
    normal_buffer : sg_buffer;
    vertex_count  : s64;
};

get_trile :: (name: string) -> (Mesh, success: bool) {
    success, value := table_find(*trile_table, name);
    return success, value;
}

set_trile :: (name: string, meshptr: Mesh) {
    // @ToDo: free old mesh...
    // @ToDo: consider if string should be copied..
    table_set(*trile_table, name, meshptr);
}

Material :: struct {
    roughness : float   = 0.5;
    metallic  : float   = 0;
    emittance : float   = 0;
    color     : Vector3 = .{0.5, 1.0, 0.5};
}

Trixel :: struct {
    material : Material;
    empty    : bool = false;
};

Trile  :: struct {
    trixels : [16][16][16] Trixel;  
};
