Trile_Side :: enum_flags u8 {
    TOP    :: 0x1;  // Larger Y
    LEFT   :: 0x2;  // Larger Z
    RIGHT  :: 0x4;  // Smaller Z
    FRONT  :: 0x8;  // Larger X
    BACK   :: 0x10; // Smaller X
    BOTTOM :: 0x20; // Smaller Ys
}

trileSideValues : [6]Trile_Side = .[.TOP, .LEFT, .RIGHT, .FRONT, .BACK, .BOTTOM];

swap_xyz_for_side :: (x: int, y: int, z: int, Trile_Side) -> (int, int, int) {
    
}

sides_with_air_exposure :: (trileptr: *Trile, x: int, y: int, z: int) -> u8 {
    res : u8 = 0;
    if trileptr.trixels[x][y][z].empty then return res;

    if y == 15 || trileptr.trixels[x][y+1][z].empty then res |= xx Trile_Side.TOP;
    if y == 0  || trileptr.trixels[x][y-1][z].empty then res |= xx Trile_Side.BOTTOM;
    if z == 15 || trileptr.trixels[x][y][z+1].empty then res |= xx Trile_Side.LEFT;
    if z == 0  || trileptr.trixels[x][y][z-1].empty then res |= xx Trile_Side.RIGHT;
    if x == 15 || trileptr.trixels[x+1][y][z].empty then res |= xx Trile_Side.FRONT;
    if x == 0  || trileptr.trixels[x-1][y][z].empty then res |= xx Trile_Side.BACK;

    return res;
}

meshgen :: (trile: *Trile) {
    for trileSideValues {
        
    }
}
