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
            qlist := *quads[idx];
            array_add(qlist, .{});
            table_add(qlist[i], .{.{16,16}, .{0,0}}, true);
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

quad2d_add_to_quads_3d :: (quads2d: *[..]Vector2, quads3d: *[..]Vector3, side: Trile_Side, depth: int, normals: *[..]float) {
    x, y, z : float;
    normal  : [3]float;
    offset  : float = 0.0;
    
    ux, uy, uz = change_perspective(*x, *y, *z, side);

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
            Quad_Set :: Table(Quad, bool, quad_hash, quad_comp);
            Quads    :: [6][..]Quad_Set;
            for quad : quads[idx][it] {
                array_add(*quads2d, quad.bottomLeft);
                array_add(*quads2d, .{quad.bottomLeft.x, quad.topRight.y});
                array_add(*quads2d, quad.topRight);
                array_add(*quads2d, .{quad.topRight.x, quad.bottomLeft.y});
            }
            quad2_add_to_quads3d(*quads2d, *quads3d, side, it, normals);
        }
    }
}

/*

void quadsToVecs(Quads& quads, std::vector<float>& vecs, std::vector<float>& normals){
    std::vector<Vector3> quads3d;
    for(TrileSide side : TrileSideValues){
        for(int i=0; i<quads[side].size(); i++){
            std::vector<Vector2> quads2d;
            for(Quad quad : quads[side][i]){
                quads2d.push_back(quad.bottomLeft);
                quads2d.push_back({quad.bottomLeft.x,quad.topRight.y});
                quads2d.push_back(quad.topRight);
                quads2d.push_back({quad.topRight.x,quad.bottomLeft.y});
            }
            quad2dAddToQuads3d(quads2d,quads3d,side,i,normals);
        }
    }
    for(Vector3 quad : quads3d) {
        vecs.push_back(quad.x);
        vecs.push_back(quad.y);
        vecs.push_back(quad.z);
    }
}

bool isInsideOther(Quad a, Quad other){
    if( (other.topRight.x >= a.topRight.x) && (other.topRight.y >= a.topRight.y)){
        if( (other.bottomLeft.x <= a.bottomLeft.x) && (other.bottomLeft.y <= a.bottomLeft.y) ){
            return true;
        }
    }
    return false;
}

void removeQuad(Quad quad, std::set<Quad>& quadSet){
    auto parentIt = quadSet.lower_bound(quad);
    while(!isInsideOther(quad,*parentIt)){
        parentIt++; //The "parent"quad should always be found before reaching set end
    }
    Quad parent = *parentIt;
    quadSet.erase(parentIt);

    Vector2 topLeft = {quad.bottomLeft.x,quad.topRight.y};
    Vector2 bottomRight = {quad.topRight.x,quad.bottomLeft.y};

    if(quad.topRight.x != parent.topRight.x){
        quadSet.insert({parent.topRight,bottomRight});
    }
    if(quad.topRight.y != parent.topRight.y){
        quadSet.insert({quad.topRight.x,parent.topRight.y,parent.bottomLeft.x,quad.topRight.y});
    }
    if(quad.bottomLeft.y != parent.bottomLeft.y){
        quadSet.insert({parent.topRight.x,quad.bottomLeft.y,quad.bottomLeft.x,parent.bottomLeft.y});
    }
    if(quad.bottomLeft.x != parent.bottomLeft.x){
        quadSet.insert({topLeft,parent.bottomLeft});
    }
}

void removeNotSeen(Trile *trilept, Quads& quads){
    for(int x = 0; x < 16; x++) {
        for(int y = 0; y < 16; y++){
            for(int z = 0; z < 16; z++) {
                // Check for "air" contact on each side of the trixel.
                char exposure = SidesWithAirExposure(trilept, x, y, z);
                for(TrileSide side : TrileSideValues){
                    if( !(side & exposure)){
                        int *ux,*uy,*uz;
                        changePerspective(&x,&y,&z,ux,uy,uz,side);
                        removeQuad(Quad{(float)*ux+1,(float)*uy+1,(float)*ux,(float)*uy},quads[side][*uz]);
                    }
                }

            }
        }
    }
}

void generateOptimizedQuadMesh(Trile *trilept, std::vector<float>& vecs, std::vector<float>& normals){
    Quads quads;
    initQuads(quads);
    removeNotSeen(trilept,quads);
    quadsToVecs(quads,vecs,normals);
}


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
