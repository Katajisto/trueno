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
