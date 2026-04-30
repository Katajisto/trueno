// LOD bake for triles. Independent of meshgen.jai's quad-mesh path.
//
// Approach:
//   1. Downsample the 16^3 source trixels into a smaller N^3 grid of LOD voxels
//      (avg color across non-empty source trixels in each block, empty if all empty).
//   2. Bake a cube-grid mesh: one cube per non-empty LOD voxel, only emit faces whose
//      neighbor in the LOD grid is empty (or out of bounds). Color is baked into the
//      vertex color buffer.
//   3. The result feeds a separate trile_lod pipeline that uses vertex color and skips
//      texture sampling, ray-march, SSAO, shadow, SH, etc.

LOD_Voxel :: struct {
    color : Vector3;
    empty : bool;
}

downsample_trile :: (src: *Trile, target_size: int) -> []LOD_Voxel {
    block := 16 / target_size;  // source trixels per LOD voxel along one axis
    out := NewArray(target_size * target_size * target_size, LOD_Voxel,, temp);
    for lx: 0..target_size-1 {
        for ly: 0..target_size-1 {
            for lz: 0..target_size-1 {
                sum_r, sum_g, sum_b : float;
                count : int = 0;
                for dx: 0..block-1 {
                    for dy: 0..block-1 {
                        for dz: 0..block-1 {
                            sx := lx * block + dx;
                            sy := ly * block + dy;
                            sz := lz * block + dz;
                            if src.trixels[sx][sy][sz].empty  continue;
                            c := src.trixels[sx][sy][sz].material.color;
                            sum_r += c.x;
                            sum_g += c.y;
                            sum_b += c.z;
                            count += 1;
                        }
                    }
                }
                idx := (lx * target_size + ly) * target_size + lz;
                if count == 0 {
                    out[idx].empty = true;
                } else {
                    out[idx].color = .{ sum_r / count, sum_g / count, sum_b / count };
                    out[idx].empty = false;
                }
            }
        }
    }
    return out;
}

bake_lod_cube_mesh :: (lod: []LOD_Voxel, target_size: int) -> Trile_GFX_LOD {
    inv_n := 1.0 / cast(float)target_size;

    verts   : [..]float;
    norms   : [..]float;
    colors  : [..]float;
    verts.allocator   = temp;
    norms.allocator   = temp;
    colors.allocator  = temp;

    voxel_at :: (lod: []LOD_Voxel, n: int, x: int, y: int, z: int) -> LOD_Voxel #expand {
        idx := (x * n + y) * n + z;
        return lod[idx];
    }

    // Each face: 4 corners (offsets in [0,1] within a unit voxel) + outward normal.
    Face :: struct {
        nx, ny, nz : float;
        ax, ay, az : float;
        bx, by, bz : float;
        cx, cy, cz : float;
        dx, dy, dz : float;
    }
    // Order: -X, +X, -Y, +Y, -Z, +Z. CCW winding when viewed from outside.
    faces :: Face.[
        .{ -1, 0, 0,  0,0,0, 0,0,1, 0,1,1, 0,1,0 },
        .{  1, 0, 0,  1,0,0, 1,1,0, 1,1,1, 1,0,1 },
        .{  0,-1, 0,  0,0,0, 1,0,0, 1,0,1, 0,0,1 },
        .{  0, 1, 0,  0,1,0, 0,1,1, 1,1,1, 1,1,0 },
        .{  0, 0,-1,  0,0,0, 0,1,0, 1,1,0, 1,0,0 },
        .{  0, 0, 1,  1,0,1, 1,1,1, 0,1,1, 0,0,1 },
    ];
    neighbor_offsets :: int.[ -1, 1, -1, 1, -1, 1 ];
    neighbor_axes    :: int.[  0, 0,  1, 1,  2, 2 ]; // 0=x, 1=y, 2=z

    for lx: 0..target_size-1 {
        for ly: 0..target_size-1 {
            for lz: 0..target_size-1 {
                v := voxel_at(lod, target_size, lx, ly, lz);
                if v.empty  continue;

                base_x := cast(float)lx * inv_n;
                base_y := cast(float)ly * inv_n;
                base_z := cast(float)lz * inv_n;

                for f: 0..5 {
                    nx, ny, nz := lx, ly, lz;
                    if neighbor_axes[f] == 0  nx += neighbor_offsets[f];
                    else if neighbor_axes[f] == 1  ny += neighbor_offsets[f];
                    else                            nz += neighbor_offsets[f];

                    visible := false;
                    if nx < 0 || nx >= target_size || ny < 0 || ny >= target_size || nz < 0 || nz >= target_size {
                        visible = true;
                    } else {
                        if voxel_at(lod, target_size, nx, ny, nz).empty  visible = true;
                    }
                    if !visible  continue;

                    face := faces[f];
                    push_vert :: (px: float, py: float, pz: float) #expand {
                        array_add(*verts, base_x + px * inv_n);
                        array_add(*verts, base_y + py * inv_n);
                        array_add(*verts, base_z + pz * inv_n);
                        array_add(*norms, face.nx);
                        array_add(*norms, face.ny);
                        array_add(*norms, face.nz);
                        array_add(*colors, v.color.x);
                        array_add(*colors, v.color.y);
                        array_add(*colors, v.color.z);
                    }
                    // tri 1: a b c
                    push_vert(face.ax, face.ay, face.az);
                    push_vert(face.bx, face.by, face.bz);
                    push_vert(face.cx, face.cy, face.cz);
                    // tri 2: a c d
                    push_vert(face.ax, face.ay, face.az);
                    push_vert(face.cx, face.cy, face.cz);
                    push_vert(face.dx, face.dy, face.dz);
                }
            }
        }
    }

    out : Trile_GFX_LOD;
    out.vertex_count = verts.count / 3;
    if out.vertex_count == 0  return out;

    out.vertex_buffer = sg_make_buffer(*(sg_buffer_desc.{ data = .{ ptr = verts.data,  size = xx (verts.count  * 4) } }));
    out.normal_buffer = sg_make_buffer(*(sg_buffer_desc.{ data = .{ ptr = norms.data,  size = xx (norms.count  * 4) } }));
    out.color_buffer  = sg_make_buffer(*(sg_buffer_desc.{ data = .{ ptr = colors.data, size = xx (colors.count * 4) } }));
    return out;
}

destroy_trile_gfx_lod :: (lod: *Trile_GFX_LOD) {
    if lod.vertex_count == 0  return;
    sg_destroy_buffer(lod.vertex_buffer);
    sg_destroy_buffer(lod.normal_buffer);
    sg_destroy_buffer(lod.color_buffer);
    lod.vertex_count = 0;
}
