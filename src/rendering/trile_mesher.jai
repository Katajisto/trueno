mesh_trile :: (trile: *Trile) -> vertices: []Trile_Vertex, indices: []u16 {
    vertices : [..]Trile_Vertex;
    indices  : [..]u16;
    vertices.allocator = temp;
    indices.allocator  = temp;

    for axis: 0..2  for sign: s32.[1, -1] {
        u_axis := (axis + 1) % 3;
        v_axis := (axis + 2) % 3;
        for depth: 0..15 {
            mask : [16][16]Face;
            for u: 0..15  for v: 0..15 {
                c : [3]s32;
                c[axis] = xx depth; c[u_axis] = xx u; c[v_axis] = xx v;
                swatch := trixel(trile, c);
                c[axis] += sign;
                if !swatch || trixel(trile, c)  continue;

                face := *mask[u][v];
                face.swatch = swatch;
                for corner: 0..3 {
                    side_u := c;  side_u[u_axis] += xx ifx corner == 1 || corner == 2 then 1 else -1;
                    side_v := c;  side_v[v_axis] += xx ifx corner >= 2 then 1 else -1;
                    diagonal := side_u;  diagonal[v_axis] = side_v[v_axis];
                    a := trixel(trile, side_u) != 0;
                    b := trixel(trile, side_v) != 0;
                    d := trixel(trile, diagonal) != 0;
                    face.ao[corner] = xx ifx a && b then 0 else 3 - cast(int) a - cast(int) b - cast(int) d;
                }
            }

            for u0: 0..15  for v0: 0..15 {
                face := mask[u0][v0];
                if !face.swatch  continue;
                // A face with an AO gradient keeps its own quad, so the gradient isn't stretched.
                u1, v1 := u0 + 1, v0 + 1;
                if flat(face) {
                    while v1 < 16 && mask[u0][v1] == face  v1 += 1;
                    while u1 < 16 && row_matches(*mask, u1, v0, v1, face)  u1 += 1;
                }
                for u: u0..u1-1  for v: v0..v1-1  mask[u][v] = .{};

                plane := cast(float)(depth + ifx sign > 0 then 1 else 0);
                normal := cast(u8)(axis * 2 + ifx sign < 0 then 1 else 0);
                corner :: (u: int, v: int, ao: u8) -> Trile_Vertex #expand {
                    p : Vector3;
                    p.component[`axis]   = `plane * TRIXEL_SIZE;
                    p.component[`u_axis] = u * TRIXEL_SIZE;
                    p.component[`v_axis] = v * TRIXEL_SIZE;
                    return .{p, `face.swatch, ao, `normal, 0};
                }
                q := Trile_Vertex.[
                    corner(u0, v0, face.ao[0]),
                    corner(u1, v0, face.ao[1]),
                    corner(u1, v1, face.ao[2]),
                    corner(u0, v1, face.ao[3]),
                ];
                if sign < 0  q[1], q[3] = q[3], q[1];
                // Split along the brighter diagonal so AO interpolates evenly.
                base := cast(u16) vertices.count;
                array_add(*vertices, ..q);
                if face.ao[0] + face.ao[2] < face.ao[1] + face.ao[3] {
                    for u16.[1, 2, 3, 1, 3, 0]  array_add(*indices, base + it);
                } else {
                    for u16.[0, 1, 2, 0, 2, 3]  array_add(*indices, base + it);
                }
            }
        }
    }
    return vertices, indices;
}

#scope_file

// ao is per corner in the order (u0, v0), (u1, v0), (u1, v1), (u0, v1); 3 = open.
Face :: struct {
    swatch : u8;
    ao     : [4]u8;
}

operator == :: (a: Face, b: Face) -> bool {
    return a.swatch == b.swatch && a.ao[0] == b.ao[0] && a.ao[1] == b.ao[1] && a.ao[2] == b.ao[2] && a.ao[3] == b.ao[3];
}

flat :: (face: Face) -> bool {
    return face.ao[0] == face.ao[1] && face.ao[1] == face.ao[2] && face.ao[2] == face.ao[3];
}

row_matches :: (mask: *[16][16]Face, u: int, v0: int, v1: int, face: Face) -> bool {
    for v: v0..v1-1  if mask.*[u][v] != face  return false;
    return true;
}

trixel :: (trile: *Trile, c: [3]s32) -> u8 {
    for c  if it < 0 || it > 15  return 0;
    return trile.trixels[c[0]][c[1]][c[2]];
}
