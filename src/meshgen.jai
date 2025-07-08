Trile_Side :: enum_flags u8 {
    TOP    :: 0x0;  // Larger Y
    LEFT   :: 0x1;  // Larger Z
    RIGHT  :: 0x4;  // Smaller Z
    FRONT  :: 0x8;  // Larger X
    BACK   :: 0x10; // Smaller X
    BOTTOM :: 0x20; // Smaller Ys
}

trileSideValues : [6]Trile_Side = .[.TOP, .LEFT, .RIGHT, .FRONT, .BACK, .BOTTOM];

sides_with_air_exposure :: (trileptr: *Trile, x: int, y: int, z: int) -> u8 {
    res : u8 = 0;
    if trileptr.trixels[x][y][z].empty then return res;

    // Top
    if y == 15 || trileptr.trixels[x][y+1][z].empty then res |= xx Trile_Side.TOP;
    // Bottom
    if y == 0  || trileptr.trixels[x][y-1][z].empty then res |= xx Trile_Side.BOTTOM;
    // Left
    if z == 15 || trileptr.trixels[x][y][z+1].empty then res |= xx Trile_Side.LEFT;
    // Right
    if z == 0  || trileptr.trixels[x][y][z-1].empty then res |= xx Trile_Side.RIGHT;
    // Front
    if x == 15 || trileptr.trixels[x+1][y][z].empty then res |= xx Trile_Side.FRONT;
    // Back
    if x == 0  || trileptr.trixels[x-1][y][z].empty then res |= xx Trile_Side.BACK;

    return res;
}

draw_trile_side_triangles :: (vecs: *[]float, normals: *[]float, index: *int, side: Trile_Side, x: int, y: int, z: int) {
    points : [4][3]float;
    normal : [3]float;

    if side == Trile_Side.TOP {
        points[0][0] = 1; points[0][1] = 1; points[0][2] = 1;
        points[1][0] = 1; points[1][1] = 1; points[1][2] = 0;
        points[2][0] = 0; points[2][1] = 1; points[2][2] = 1;
        points[3][0] = 0; points[3][1] = 1; points[3][2] = 0;
        normal[0] = 0; normal[1] = 1; normal[2] = 0;
    }    
    if side == Trile_Side.BOTTOM {
        points[0][0] = 1; points[0][1] = 0; points[0][2] = 1;
        points[2][0] = 1; points[2][1] = 0; points[2][2] = 0;
        points[1][0] = 0; points[1][1] = 0; points[1][2] = 1;
        points[3][0] = 0; points[3][1] = 0; points[3][2] = 0;
        normal[0] = 0; normal[1] = -1; normal[2] = 0;
    }
    if side == Trile_Side.FRONT {
        points[0][0] = 1; points[0][1] = 1; points[0][2] = 1;
        points[2][0] = 1; points[2][1] = 1; points[2][2] = 0;
        points[1][0] = 1; points[1][1] = 0; points[1][2] = 1;
        points[3][0] = 1; points[3][1] = 0; points[3][2] = 0;
        normal[0] = 1; normal[1] = 0; normal[2] = 0;
    }
    if side == Trile_Side.BACK {
        points[0][0] = 0; points[0][1] = 1; points[0][2] = 1;
        points[1][0] = 0; points[1][1] = 1; points[1][2] = 0;
        points[2][0] = 0; points[2][1] = 0; points[2][2] = 1;
        points[3][0] = 0; points[3][1] = 0; points[3][2] = 0;
        normal[0] = -1; normal[1] = 0; normal[2] = 0;
    }
    if side == Trile_Side.LEFT {
        points[0][0] = 1; points[0][1] = 1; points[0][2] = 1;
        points[2][0] = 1; points[2][1] = 0; points[2][2] = 1;
        points[1][0] = 0; points[1][1] = 1; points[1][2] = 1;
        points[3][0] = 0; points[3][1] = 0; points[3][2] = 1;
        normal[0] = 0; normal[1] = 0; normal[2] = 1;
    }
    if side == Trile_Side.RIGHT {
        points[0][0] = 1; points[0][1] = 1; points[0][2] = 0;
        points[1][0] = 1; points[1][1] = 0; points[1][2] = 0;
        points[2][0] = 0; points[2][1] = 1; points[2][2] = 0;
        points[3][0] = 0; points[3][1] = 0; points[3][2] = 0;
        normal[0] = 0; normal[1] = 0; normal[2] = -1;
    }

    for 0..2 {
        vecs.*[index.*] = (x + points[it][0]) * TRIXEL_SIZE;
        vecs.*[index.*+1] = (y + points[it][1]) * TRIXEL_SIZE;
        vecs.*[index.*+2] = (z + points[it][2]) * TRIXEL_SIZE;
        normals.*[index.*] = normal[0];
        normals.*[index.*+1] = normal[1];
        normals.*[index.*+2] = normal[2];
        index.* = index.* + 3;
    }
    
    for #v2 < 0..2 {
        vecs.*[index.*] = (x + points[it][0]) * TRIXEL_SIZE;
        vecs.*[index.*+1] = (y + points[it][1]) * TRIXEL_SIZE;
        vecs.*[index.*+2] = (z + points[it][2]) * TRIXEL_SIZE;
        normals.*[index.*] = normal[0];
        normals.*[index.*+1] = normal[1];
        normals.*[index.*+2] = normal[2];
        index.* = index.* + 3;
    }
}

draw_trile_side_quad :: (vecs: *[..]float, norms: *[..]float, side: Trile_Side, x: int, y: int, z: int) {
    points : [4][3]float;
    normal : [3]float;

    if side == {
        case Trile_Side.TOP;
            points[0][0] =  1; points[0][1] =  1; points[0][2] =  1;
            points[1][0] =  1; points[1][1] =  1; points[1][2] =  0;
            points[2][0] =  0; points[2][1] =  1; points[2][2] =  1;
            points[3][0] =  0; points[3][1] =  1; points[3][2] =  0;
            normal[0]    =  0; normal[1]    =  1; normal[2]    =  0;
        case Trile_Side.BOTTOM;
            points[0][0] =  1; points[0][1] =  0; points[0][2] =  1;
            points[2][0] =  1; points[2][1] =  0; points[2][2] =  0;
            points[1][0] =  0; points[1][1] =  0; points[1][2] =  1;
            points[3][0] =  0; points[3][1] =  0; points[3][2] =  0;
            normal[0]    =  0; normal[1]    = -1; normal[2]    =  0;
        case Trile_Side.FRONT;
            points[0][0] =  1; points[0][1] =  1; points[0][2] =  1;
            points[2][0] =  1; points[2][1] =  1; points[2][2] =  0;
            points[1][0] =  1; points[1][1] =  0; points[1][2] =  1;
            points[3][0] =  1; points[3][1] =  0; points[3][2] =  0;
            normal[0]    =  1; normal[1]    =  0; normal[2]    =  0;
        case Trile_Side.BACK;
            points[0][0] =  0; points[0][1] =  1; points[0][2] =  1;
            points[1][0] =  0; points[1][1] =  1; points[1][2] =  0;
            points[2][0] =  0; points[2][1] =  0; points[2][2] =  1;
            points[3][0] =  0; points[3][1] =  0; points[3][2] =  0;
            normal[0]    = -1; normal[1]    =  0; normal[2]    =  0;
        case Trile_Side.LEFT;
            points[0][0] =  1; points[0][1] =  1; points[0][2] =  1;
            points[2][0] =  1; points[2][1] =  0; points[2][2] =  1;
            points[1][0] =  0; points[1][1] =  1; points[1][2] =  1;
            points[3][0] =  0; points[3][1] =  0; points[3][2] =  1;
            normal[0]    =  0; normal[1]    =  0; normal[2]    =  1;
        case Trile_Side.RIGHT;
            points[0][0] =  1; points[0][1] =  1; points[0][2] =  0;
            points[1][0] =  1; points[1][1] =  0; points[1][2] =  0;
            points[2][0] =  0; points[2][1] =  1; points[2][2] =  0;
            points[3][0] =  0; points[3][1] =  0; points[3][2] =  0;
            normal[0]    =  0; normal[1]    =  0; normal[2]    = -1;
    }
    
    order  : [4]int = .[0,1,3,2];
    coords : [3]int = .[x,y,z];
    for i: 0..3 {
        for j: 0..2 {
            array_add(vecs, (coords[j]+points[order[i]][j])*TRIXEL_SIZE);
            array_add(norms, normal[j]);
        }
    }
}

generate_basic_quad_mesh :: (trileptr: *Trile, vecs: *[..]float, norms: *[..]float) {
    for x: 0..15 {
        for y: 0..15 {
            for z: 0..15 {
                exposure: u8 = sides_with_air_exposure(trileptr, x, y, z);
                for trileSideValues {
                    if (cast(u8)it) & exposure then draw_trile_side_quad(vecs, norms, it, x, y, z);
                }
            }
        }
    }
}

quads_to_triangles :: (quadVecs: *[..]float, triangleVecs: *[..]float, quadNorms: *[..]float, triangleNorms: *[..]float) {
    assert(quadVecs.count % (3*4) == 0);
    assert(quadVecs.count == quadNorms.count);   
    i := 0;
    while i < quadVecs.count {
        quadStart : *float = *(quadVecs.*[i]);
        normStart : *float = *(quadNorms.*[i]);
        for j : 0..4 {
            for k : 0..2 {
                array_add(triangleVecs, quadStart[(j%4)*3+k]);
                array_add(triangleNorms, normStart[(j%4)*3+k]);
            }
            if j == 2 {
                for k : 0..2 {
                    //add the third point twice to get 2 triangles
                    array_add(triangleVecs, quadStart[(j%4)*3+k]);
                    array_add(triangleNorms, normStart[(j%4)*3+k]);
                }
            }
        }
        i += 3*4;
    }
}

Quad :: struct {
    topRight   : Vector2;
    bottomLeft : Vector2;
};

operator < :: (a: Quad, b: Quad) -> bool {
    if a.topRight.x == b.topRight.x then return a.topRight.y < b.topRight.y;
    return a.topRight.x < b.topRight.x;
}

quad_comp :: (a: Quad, b: Quad) -> bool {
    if a.topRight != b.topRight then return false;
    if a.bottomLeft != b.bottomLeft then return false;
    return true;
}

quad_hash :: (q: Quad) -> u32 {
    return sdbm_hash(*q, size_of(Quad));
}

Quad_Set :: Table(Quad, bool, quad_hash, quad_comp);
Quads    :: [6][..]Quad_Set;

side_to_quad_list_index :: (side: Trile_Side) -> s32 {
    if #complete side == {
        case Trile_Side.TOP;
            return 0;
        case Trile_Side.BOTTOM;
            return 1;
        case Trile_Side.FRONT;
            return 2;
        case Trile_Side.BACK;
            return 3;
        case Trile_Side.LEFT;
            return 4;
        case Trile_Side.RIGHT;
            return 5;
    }
}

init_quads :: (quads: *Quads) { // NOTE: unsure about if this is correctly ported.
    for side : trileSideValues {
        idx := side_to_quad_list_index(side);
        for i : 0..15 {
            quadset : Quad_Set;
            table_add(*quadset, .{.{16,16}, .{0,0}}, true);
            array_add(*quads.*[idx], quadset);
        }
    }
}

// Looking at the side, what axis should be used as x,y and z,
// so that x and z are parallel to the side.
// (And not all of it seems to work when the used x and y and normal of the side abide by the left hand rule)
change_perspective :: (x: *$T, y: *T, z: *T, side: Trile_Side) -> (*T,*T,*T) {
    if #complete side == {
        case Trile_Side.TOP;
            return y, x, z;
        case Trile_Side.BOTTOM;
            return y, z, x;
        case Trile_Side.FRONT;
            return x, z, y;
        case Trile_Side.BACK;
            return x, y, z;
        case Trile_Side.LEFT;
            return z, y, x;
        case Trile_Side.RIGHT;
            return z, x, y;
    }
}

quad2d_add_to_quads3d :: (quads2d: *[..]Vector2, quads3d: *[..]Vector3, side: Trile_Side, depth: int, normals: *[..]float) {
    x, y, z : float;
    normal  : [3]float;
    offset  : float = 0.0;
    
    ux, uy, uz := change_perspective(*x, *y, *z, side);

    if side == {
        case Trile_Side.TOP;
            normal[0] =  0;
            normal[1] =  1;
            normal[2] =  0;
            offset    =  1;
        case Trile_Side.BOTTOM;
            normal[0] =  0;
            normal[1] = -1;
            normal[2] =  0;
        case Trile_Side.FRONT;
            normal[0] =  1;
            normal[1] =  0;
            normal[2] =  0;
            offset    =  1;
        case Trile_Side.BACK;
            normal[0] = -1;
            normal[1] =  0;
            normal[2] =  0;
        case Trile_Side.LEFT;
            normal[0] =  0;
            normal[1] =  0;
            normal[2] =  1;
            offset    =  1;
        case Trile_Side.RIGHT;
            normal[0] =  0;
            normal[1] =  0;
            normal[2] = -1;
    }

    for quad : quads2d.* {
        uz.* = (depth + offset) * TRIXEL_SIZE;
        ux.* = quad.x           * TRIXEL_SIZE;
        uy.* = quad.y           * TRIXEL_SIZE;

        array_add(quads3d, .{x,y,z});
        array_add(normals, normal[0]);
        array_add(normals, normal[1]);
        array_add(normals, normal[2]);
    }
}

quads_to_vecs :: (quads: *Quads, vecs: *[..]float, normals: *[..]float) {
    quads3d : [..]Vector3;

    for side : trileSideValues {
        idx := side_to_quad_list_index(side);
        for 0..quads[idx].count-1 {
            quads2d : [..]Vector2;
            table := quads.*[idx][it];
            for k, v : table {
                array_add(*quads2d, v.bottomLeft);
                array_add(*quads2d, .{v.bottomLeft.x, v.topRight.y});
                array_add(*quads2d, v.topRight);
                array_add(*quads2d, .{v.topRight.x, v.bottomLeft.y});
            }
            quad2d_add_to_quads3d(*quads2d, *quads3d, side, it, normals);
        }
    }
    for quad : quads3d {
        array_add(vecs, quad.x);
        array_add(vecs, quad.y);
        array_add(vecs, quad.z);
    }
}

a_is_inside_b :: (a: Quad, b: Quad) -> bool {
    if (b.topRight.x >= a.topRight.x) && (b.topRight.y >= a.topRight.y) {
        if (b.bottomLeft.x <= a.bottomLeft.x) && (b.bottomLeft.y <= a.bottomLeft.y) {
            return true;
        }
    }
    return false;
}


remove_quad :: (quad: Quad, quadSet: *Quad_Set) {
    parent : Quad;
    for k,v : quadSet {
        if v < quad then continue;
        if a_is_inside_b(quad, v) {
            table_remove(quadSet, v);
            parent = v;
            break;
        }
    }
    
    topLeft     : Vector2 = .{quad.bottomLeft.x,quad.topRight.y};
    bottomRight : Vector2 = .{quad.topRight.x,quad.bottomLeft.y};

    if quad.topRight.x != parent.topRight.x {
        table_add(quadSet, .{parent.topRight,bottomRight}, true);
    }

    if quad.topRight.y != parent.topRight.y {
        table_add(quadSet, .{.{quad.topRight.x,parent.topRight.y},.{parent.bottomLeft.x,quad.topRight.y}}, true);
    }
    if quad.bottomLeft.y != parent.bottomLeft.y {
        table_add(quadSet, .{.{parent.topRight.x,quad.bottomLeft.y},.{quad.bottomLeft.x,parent.bottomLeft.y}}, true);
    }
    if quad.bottomLeft.x != parent.bottomLeft.x {
        table_add(quadSet, .{topLeft,parent.bottomLeft}, true);
    }
}

remove_not_seen :: (trilept: *Trile, quads: *Quads) {
    for x: 0..15 {
        for y: 0..15 {
            for z: 0..15 {
                exposure: u8 = sides_with_air_exposure(trilept, x, y, z);
                for side: trileSideValues {
                    if !((cast(u8)side) & exposure) {
                        ux, uy, uz := change_perspective(*x, *y, *z, side);
                        remove_quad(.{.{cast(float)ux.*+1, cast(float)uy.*+1}, .{cast(float)ux.*, cast(float)uy.*}}, *quads.*[side_to_quad_list_index(side)][uz.*]);
                    }
                }
            }
        }
    }
}

generate_optimized_quad_mesh :: (trilept: *Trile, vecs: *[..]float, normals: *[..]float) {
    quads : Quads;
    init_quads(*quads);
    remove_not_seen(trilept, *quads);
    quads_to_vecs(*quads, vecs, normals);
}

Pool        :: #import "Pool";
meshgenpool :  Pool.Pool;

generate_mesh_matias :: (trileptr : *Trile) {
    Pool.set_allocators(*meshgenpool);
    new_context := context;
    new_context.allocator = .{Pool.pool_allocator_proc, *meshgenpool};
    push_context new_context {
        triangleVecs  : [..]float;
        triangleNorms : [..]float;
        quadVecs      : [..]float;
        quadNorms     : [..]float;

        generate_basic_quad_mesh(trileptr,*quadVecs,*quadNorms);
        print("Quad vecs size: %\n", quadVecs.count);

        quads_to_triangles(*quadVecs, *triangleVecs,*quadNorms, *triangleNorms);
        
        print("Triangle vecs size: %\n", triangleVecs.count);
    }
    Pool.reset(*meshgenpool);
}

/*

Mesh GenerateMeshMatias(Trile *trileptr){
    std::vector<float> quadVecs;
    std::vector<float> triangleVecs;
    std::vector<float> quadNorms;
    std::vector<float> triangleNorms;
    Mesh temp = {};

    generateOptimizedQuadMesh(trileptr,quadVecs,quadNorms);

    //generateBasicQuadMesh(trileptr,quadVecs,quadNorms);
    quadsToTriangles(quadVecs, triangleVecs,quadNorms, triangleNorms);

    temp.vertexCount = triangleVecs.size() / 3;
    temp.triangleCount = temp.vertexCount / 3;

    float* vecs = new float[triangleVecs.size()];
    float* norms = new float[triangleNorms.size()];
    for(int i=0; i<triangleVecs.size(); i++){
        vecs[i] = triangleVecs[i];
        norms[i] = triangleNorms[i];
    }

    temp.vertices = vecs;
    temp.normals = norms;

    return temp;
}
*/
