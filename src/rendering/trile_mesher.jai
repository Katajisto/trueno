mesh_trile :: (trile: *Trile) -> []Trile_Vertex {
    vertices : [..]Trile_Vertex;
    vertices.allocator = temp;

    for axis: 0..2  for sign: s32.[1, -1] {
        u_axis := (axis + 1) % 3;
        v_axis := (axis + 2) % 3;
        for depth: 0..15 {
            mask : [16][16]u8;
            for u: 0..15  for v: 0..15 {
                c : [3]s32;
                c[axis] = xx depth; c[u_axis] = xx u; c[v_axis] = xx v;
                swatch := trixel(trile, c);
                c[axis] += sign;
                if trixel(trile, c) == 0  mask[u][v] = swatch;
            }

            for u0: 0..15  for v0: 0..15 {
                swatch := mask[u0][v0];
                if !swatch  continue;
                v1 := v0 + 1;
                while v1 < 16 && mask[u0][v1] == swatch  v1 += 1;
                u1 := u0 + 1;
                while u1 < 16 && row_matches(*mask, u1, v0, v1, swatch)  u1 += 1;
                for u: u0..u1-1  for v: v0..v1-1  mask[u][v] = 0;

                plane := cast(float)(depth + ifx sign > 0 then 1 else 0);
                corner :: (axis: int, u_axis: int, v_axis: int, plane: float, u: int, v: int) -> Vector3 #expand {
                    p : Vector3;
                    p.component[axis]   = plane * TRIXEL_SIZE;
                    p.component[u_axis] = u * TRIXEL_SIZE;
                    p.component[v_axis] = v * TRIXEL_SIZE;
                    return p;
                }
                p0 := corner(axis, u_axis, v_axis, plane, u0, v0);
                p1 := corner(axis, u_axis, v_axis, plane, u1, v0);
                p2 := corner(axis, u_axis, v_axis, plane, u1, v1);
                p3 := corner(axis, u_axis, v_axis, plane, u0, v1);
                if sign < 0  p1, p3 = p3, p1;
                for Vector3.[p0, p1, p2, p0, p2, p3]  array_add(*vertices, .{it, xx swatch});
            }
        }
    }
    return vertices;
}

#scope_file

row_matches :: (mask: *[16][16]u8, u: int, v0: int, v1: int, swatch: u8) -> bool {
    for v: v0..v1-1  if mask.*[u][v] != swatch  return false;
    return true;
}

trixel :: (trile: *Trile, c: [3]s32) -> u8 {
    for c  if it < 0 || it > 15  return 0;
    return trile.trixels[c[0]][c[1]][c[2]];
}
