// The 24 axis-aligned cube rotations, encoded as 'face * 4 + twist' exactly as
// the trile shaders decode them (see get_orientation_matrix in
// shader_trile_shadow.glsl). Everything here mirrors that decode, so a rotation
// applied to a position on the CPU lines up with the geometry the GPU draws.
//
// Note the shaders build their mat3s from columns, which makes each of their
// rot_* helpers the transpose of the usual form. The matrices below are the
// effective row-major operators (v' = M * v), so they match what the shader
// actually does rather than what its helper names suggest.

ORIENTATION_COUNT :: 24;

Orientation_Matrix :: struct {
    m : [3][3]s8;
}

orientation_matrix :: (ori: u8) -> Orientation_Matrix {
    return ORIENTATION_MATRICES[ori % ORIENTATION_COUNT];
}

rotate_by_orientation :: (ori: u8, v: Vector3) -> Vector3 {
    m := orientation_matrix(ori).m;
    return .{
        cast(float)m[0][0] * v.x + cast(float)m[0][1] * v.y + cast(float)m[0][2] * v.z,
        cast(float)m[1][0] * v.x + cast(float)m[1][1] * v.y + cast(float)m[1][2] * v.z,
        cast(float)m[2][0] * v.x + cast(float)m[2][1] * v.y + cast(float)m[2][2] * v.z,
    };
}

// The orientation equal to applying 'inner' first and then 'outer'. Used to fold
// an entity's rotation into the orientation its parts were authored with.
compose_orientations :: (outer: u8, inner: u8) -> u8 {
    return ORIENTATION_COMPOSE[outer % ORIENTATION_COUNT][inner % ORIENTATION_COUNT];
}

// The quarter turn that carries 'u' onto 'v' and leaves 'n' alone, where u, v, n
// are a set of perpendicular unit axes. Taking the basis from the caller keeps
// the result consistent with whatever handedness the caller draws with, instead
// of relying on a sign convention agreed at a distance.
orientation_quarter_turn :: (u: Vector3, v: Vector3, n: Vector3) -> u8 {
    // M = v*uT - u*vT + n*nT sends u -> v, v -> -u, n -> n.
    m : Orientation_Matrix;
    ui := to_axis_ints(u);
    vi := to_axis_ints(v);
    ni := to_axis_ints(n);
    for i: 0..2 {
        for j: 0..2 {
            m.m[i][j] = vi[i]*ui[j] - ui[i]*vi[j] + ni[i]*ni[j];
        }
    }
    ori, ok := orientation_from_matrix(m);
    if !ok {
        log_error("Rotate gizmo basis is not axis-aligned; ignoring the turn.");
        return 0;
    }
    return ori;
}

orientation_from_matrix :: (m: Orientation_Matrix) -> (ori: u8, ok: bool) {
    for i: 0..ORIENTATION_COUNT-1 {
        if mat3_equal(m, ORIENTATION_MATRICES[i])  return cast(u8) i, true;
    }
    return 0, false;
}

#scope_file

ORIENTATION_MATRICES :: #run generate_orientation_matrices();
ORIENTATION_COMPOSE  :: #run generate_orientation_compose_table();

// Axis vectors only ever hold 0 or +-1 here, but they arrive as floats.
to_axis_ints :: (v: Vector3) -> [3]s8 {
    round_axis :: (f: float) -> s8 {
        if f >  0.5 then return  1;
        if f < -0.5 then return -1;
        return 0;
    }
    return .[round_axis(v.x), round_axis(v.y), round_axis(v.z)];
}

mat3_of :: (a: s8, b: s8, c: s8, d: s8, e: s8, f: s8, g: s8, h: s8, i: s8) -> Orientation_Matrix {
    r : Orientation_Matrix;
    r.m[0][0] = a; r.m[0][1] = b; r.m[0][2] = c;
    r.m[1][0] = d; r.m[1][1] = e; r.m[1][2] = f;
    r.m[2][0] = g; r.m[2][1] = h; r.m[2][2] = i;
    return r;
}

// (c, s) are cos and sin of the angle, always in {-1, 0, 1} here.
rot_x_effective :: (s: s8, c: s8) -> Orientation_Matrix { return mat3_of(1, 0, 0,  0, c, s,  0, -s, c); }
rot_y_effective :: (s: s8, c: s8) -> Orientation_Matrix { return mat3_of(c, 0, -s, 0, 1, 0,  s,  0, c); }
rot_z_effective :: (s: s8, c: s8) -> Orientation_Matrix { return mat3_of(c, s, 0, -s, c, 0,  0,  0, 1); }

mat3_mul :: (a: Orientation_Matrix, b: Orientation_Matrix) -> Orientation_Matrix {
    r : Orientation_Matrix;
    for i: 0..2 {
        for j: 0..2 {
            sum : s8 = 0;
            for k: 0..2  sum += a.m[i][k] * b.m[k][j];
            r.m[i][j] = sum;
        }
    }
    return r;
}

mat3_equal :: (a: Orientation_Matrix, b: Orientation_Matrix) -> bool {
    for i: 0..2  for j: 0..2  if a.m[i][j] != b.m[i][j]  return false;
    return true;
}

// Mirrors get_orientation_matrix: a face rotation followed by a twist about Y.
generate_orientation_matrices :: () -> [ORIENTATION_COUNT]Orientation_Matrix {
    identity  :: #run mat3_of(1, 0, 0, 0, 1, 0, 0, 0, 1);
    // sin/cos of face and twist angles, written out to keep this exact.
    faces : [6]Orientation_Matrix;
    faces[0] = identity;
    faces[1] = rot_x_effective( 0, -1);  // PI
    faces[2] = rot_z_effective(-1,  0);  // -PI/2
    faces[3] = rot_z_effective( 1,  0);  //  PI/2
    faces[4] = rot_x_effective( 1,  0);  //  PI/2
    faces[5] = rot_x_effective(-1,  0);  // -PI/2

    twists : [4]Orientation_Matrix;
    twists[0] = identity;
    twists[1] = rot_y_effective( 1,  0);
    twists[2] = rot_y_effective( 0, -1);
    twists[3] = rot_y_effective(-1,  0);

    result : [ORIENTATION_COUNT]Orientation_Matrix;
    for face: 0..5 {
        for twist: 0..3 {
            result[face * 4 + twist] = mat3_mul(faces[face], twists[twist]);
        }
    }
    return result;
}

generate_orientation_compose_table :: () -> [ORIENTATION_COUNT][ORIENTATION_COUNT]u8 {
    mats := generate_orientation_matrices();
    table : [ORIENTATION_COUNT][ORIENTATION_COUNT]u8;
    for a: 0..ORIENTATION_COUNT-1 {
        for b: 0..ORIENTATION_COUNT-1 {
            product := mat3_mul(mats[a], mats[b]);
            found := false;
            for c: 0..ORIENTATION_COUNT-1 {
                if mat3_equal(product, mats[c]) {
                    table[a][b] = cast(u8) c;
                    found = true;
                    break;
                }
            }
            assert(found, "Cube rotation % * % is not one of the 24 orientations", a, b);
        }
    }
    return table;
}


#if FLAG_TEST_ENGINE {
    v3_eq :: (a: Vector3, b: Vector3) -> bool {
        return abs(a.x - b.x) < 0.001 && abs(a.y - b.y) < 0.001 && abs(a.z - b.z) < 0.001;
    }

    test_orientation_set :: () {
        s := begin_suite("cube orientations");

        distinct := true;
        for i: 0..ORIENTATION_COUNT-1 {
            for j: i+1..ORIENTATION_COUNT-1 {
                if mat3_equal(ORIENTATION_MATRICES[i], ORIENTATION_MATRICES[j])  distinct = false;
            }
        }
        check(*s, "all 24 orientations are distinct", distinct);

        // Rotations preserve handedness, so every determinant must be +1. A -1
        // would mean the set had picked up a reflection.
        proper := true;
        for i: 0..ORIENTATION_COUNT-1 {
            m := ORIENTATION_MATRICES[i].m;
            det := cast(int)m[0][0] * (cast(int)m[1][1]*m[2][2] - cast(int)m[1][2]*m[2][1])
                 - cast(int)m[0][1] * (cast(int)m[1][0]*m[2][2] - cast(int)m[1][2]*m[2][0])
                 + cast(int)m[0][2] * (cast(int)m[1][0]*m[2][1] - cast(int)m[1][1]*m[2][0]);
            if det != 1  proper = false;
        }
        check(*s, "every orientation is a proper rotation", proper);

        check(*s, "orientation 0 is the identity",
            v3_eq(rotate_by_orientation(0, .{1, 2, 3}), .{1, 2, 3}));

        // Orientations 1..3 are the twists: rotations about Y, so Y is fixed.
        twists_about_y := true;
        for ori: 1..3 {
            if !v3_eq(rotate_by_orientation(cast(u8)ori, .{0, 1, 0}), .{0, 1, 0})  twists_about_y = false;
        }
        check(*s, "the twist orientations turn about Y", twists_about_y);

        // Rotations are rigid: lengths survive.
        lengths_kept := true;
        for ori: 0..ORIENTATION_COUNT-1 {
            r := rotate_by_orientation(cast(u8)ori, .{1, 2, 3});
            if abs(length(r) - length(Vector3.{1, 2, 3})) > 0.001  lengths_kept = false;
        }
        check(*s, "rotating preserves length", lengths_kept);

        // Pinned against the shader's decode. If these drift, entity part offsets
        // will rotate the opposite way from the trile geometry they belong to.
        // Orientation 1 is face 0 twist 1, the shader's rot_y(PI/2).
        check(*s, "orientation 1 (twist 90) sends X to Z",
            v3_eq(rotate_by_orientation(1, .{1, 0, 0}), .{0, 0, 1}));
        // Orientation 4 is face 1 twist 0, the shader's rot_x(PI).
        check(*s, "orientation 4 (face 1) flips Y and Z",
            v3_eq(rotate_by_orientation(4, .{0, 1, 1}), .{0, -1, -1}));
        // Orientation 16 is face 4 twist 0, the shader's rot_x(PI/2).
        check(*s, "orientation 16 (face 4) sends Y to -Z",
            v3_eq(rotate_by_orientation(16, .{0, 1, 0}), .{0, 0, -1}));
        end_suite(s);
    }

    test_orientation_compose :: () {
        s := begin_suite("orientation composition");

        identity_ok := true;
        for ori: 0..ORIENTATION_COUNT-1 {
            if compose_orientations(0, cast(u8)ori) != cast(u8)ori  identity_ok = false;
            if compose_orientations(cast(u8)ori, 0) != cast(u8)ori  identity_ok = false;
        }
        check(*s, "composing with orientation 0 changes nothing", identity_ok);

        // Composing a fixed orientation with each of the 24 must hit each exactly
        // once, or the table is not a group and some rotations are unreachable.
        permutation := true;
        for a: 0..ORIENTATION_COUNT-1 {
            seen : [ORIENTATION_COUNT]bool;
            for b: 0..ORIENTATION_COUNT-1 {
                r := compose_orientations(cast(u8)a, cast(u8)b);
                if seen[r]  permutation = false;
                seen[r] = true;
            }
        }
        check(*s, "every row of the compose table is a permutation", permutation);

        // compose(outer, inner) must mean "inner first, then outer".
        order_ok := true;
        v := Vector3.{1, 2, 3};
        for a: 0..ORIENTATION_COUNT-1 {
            for b: 0..ORIENTATION_COUNT-1 {
                combined := rotate_by_orientation(compose_orientations(cast(u8)a, cast(u8)b), v);
                stepwise := rotate_by_orientation(cast(u8)a, rotate_by_orientation(cast(u8)b, v));
                if !v3_eq(combined, stepwise)  order_ok = false;
            }
        }
        check(*s, "composing matches applying inner then outer", order_ok);
        end_suite(s);
    }

    test_orientation_quarter_turn :: () {
        s := begin_suite("orientation quarter turns");
        X :: Vector3.{1, 0, 0};
        Y :: Vector3.{0, 1, 0};
        Z :: Vector3.{0, 0, 1};

        q := orientation_quarter_turn(X, Z, Y);  // turn X toward Z about Y
        check(*s, "a quarter turn carries u onto v",     v3_eq(rotate_by_orientation(q, X), Z));
        check(*s, "a quarter turn carries v onto -u",    v3_eq(rotate_by_orientation(q, Z), .{-1, 0, 0}));
        check(*s, "a quarter turn leaves its axis alone", v3_eq(rotate_by_orientation(q, Y), Y));

        four := compose_orientations(q, compose_orientations(q, compose_orientations(q, q)));
        check(*s, "four quarter turns return to the start", four == 0);

        // Dragging the ring back the other way must undo the turn exactly.
        back := orientation_quarter_turn(Z, X, Y);
        check(*s, "the reverse turn cancels the forward one", compose_orientations(q, back) == 0);

        all_valid := true;
        for pair: Vector3.[X, Y, Z] {
            u := pair;
            v := ifx v3_eq(u, X) then Y else ifx v3_eq(u, Y) then Z else X;
            n := cross(u, v);
            t := orientation_quarter_turn(u, v, n);
            if !v3_eq(rotate_by_orientation(t, u), v)  all_valid = false;
        }
        check(*s, "quarter turns work on every axis pair", all_valid);
        end_suite(s);
    }

    #run {
        test_orientation_set();
        test_orientation_compose();
        test_orientation_quarter_turn();
    }
}
