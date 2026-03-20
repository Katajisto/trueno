Ray :: struct {
    origin    : Vector3;
    direction : Vector3;
};

get_mouse_ray :: (cam: *Camera) -> Ray {
    sw, sh := get_window_size();

    x := (2.0 * input_mouse_x)/sw - 1.0;
    y := 1.0 - (2.0 * input_mouse_y)/sh;
    z := 1.0;

    deviceCoords := Vector3.{x,y,z};

    matView := create_lookat(cam);
    matProj := create_perspective(cam);

    nearPoint := unproject(.{deviceCoords.x, deviceCoords.y, 0.0}, matProj, matView);
    farPoint := unproject(.{deviceCoords.x, deviceCoords.y, 1.0}, matProj, matView);

    direction := normalize(farPoint - nearPoint);

    return .{
        cam.position,
        direction
    };
    
}


Collision_Cube :: struct {
    position : Vector3;
    size     : Vector3;
};

Ray_Collision :: struct {
    distance : float = 99999;
    hit      : bool  = false;
    point    : Vector3;
    normal   : Vector3;
}

// At which 2D XZ point does a ray hit the horizontal plane at plane_height.
// Works whether the camera is above or below the plane.
ray_plane_collision_point :: (ray: Ray, plane_height: float, acceptable_radius: float = -1) -> (bool, Vector2) {
    if abs(ray.direction.y) < 0.0001 then return false, .{0,0};  // parallel to plane
    multi := (plane_height - ray.origin.y) / ray.direction.y;
    if multi < 0 then return false, .{0,0};  // plane is behind the camera
    planePoint := ray.origin + ray.direction * multi;
    if acceptable_radius > 0 && length(Vector2.{planePoint.x, planePoint.z} - Vector2.{ray.origin.x, ray.origin.z}) > acceptable_radius {
        return false, .{};
    }
    return true, .{planePoint.x, planePoint.z};
}

// Ported over from Raylib.
does_ray_hit_cube :: (og_ray: Ray, cube: Collision_Cube) -> Ray_Collision {
    ray := og_ray;
    collision : Ray_Collision;
    bmin := cube.position;
    bmax := cube.position + cube.size;

    insideBox := (ray.origin.x > bmin.x) && (ray.origin.x < bmax.x) &&
                 (ray.origin.y > bmin.y) && (ray.origin.y < bmax.y) &&
                 (ray.origin.z > bmin.z) && (ray.origin.z < bmax.z);

    t : [11] float;

    t[8]  = 1.0/ray.direction.x;
    t[9]  = 1.0/ray.direction.y;
    t[10] = 1.0/ray.direction.z;
    
    t[0] = (bmin.x - ray.origin.x) * t[8];
    t[1] = (bmax.x - ray.origin.x) * t[8];
    t[2] = (bmin.y - ray.origin.y) * t[9];
    t[3] = (bmax.y - ray.origin.y) * t[9];
    t[4] = (bmin.z - ray.origin.z) * t[10];
    t[5] = (bmax.z - ray.origin.z) * t[10];
    t[6] = max(max(min(t[0], t[1]), min(t[2], t[3])), min(t[4], t[5]));
    t[7] = min(min(max(t[0], t[1]), max(t[2], t[3])), max(t[4], t[5]));

    collision.hit      = !((t[7] < 0) || (t[6] > t[7]));
    collision.distance = t[6];
    collision.point    = ray.origin + ray.direction * collision.distance;

    tx := min(t[0], t[1]);
    ty := min(t[2], t[3]);
    tz := min(t[4], t[5]);
    if tx >= ty && tx >= tz {
        collision.normal = .{ifx t[0] < t[1] then -1.0 else 1.0, 0, 0};
    } else if ty >= tx && ty >= tz {
        collision.normal = .{0, ifx t[2] < t[3] then -1.0 else 1.0, 0};
    } else {
        collision.normal = .{0, 0, ifx t[4] < t[5] then -1.0 else 1.0};
    }

    if insideBox {
        ray.direction      = -1.0 * ray.direction;
        collision.distance = -1.0 * collision.distance;
        collision.normal   = -1.0 * collision.normal;
    }

    return collision;
}

unproject :: (source: Vector3, projection: Matrix4, view: Matrix4) -> Vector3 {
    result : Vector3;

    // Calculate unprojected matrix (multiply view matrix by projection matrix) and invert it
    matViewProj := Matrix4.{      // MatrixMultiply(view, projection);
        view.floats[0]*projection.floats[0 ]+ view.floats[1]*projection.floats[4 ]+ view.floats[2]*projection.floats[8 ]+ view.floats[3]*projection.floats[12],
        view.floats[0]*projection.floats[1 ]+ view.floats[1]*projection.floats[5 ]+ view.floats[2]*projection.floats[9 ]+ view.floats[3]*projection.floats[13],
        view.floats[0]*projection.floats[2 ]+ view.floats[1]*projection.floats[6 ]+ view.floats[2]*projection.floats[10 ]+ view.floats[3]*projection.floats[14],
        view.floats[0]*projection.floats[3 ]+ view.floats[1]*projection.floats[7 ]+ view.floats[2]*projection.floats[11 ]+ view.floats[3]*projection.floats[15],
        view.floats[4]*projection.floats[0 ]+ view.floats[5]*projection.floats[4 ]+ view.floats[6]*projection.floats[8 ]+ view.floats[7]*projection.floats[12],
        view.floats[4]*projection.floats[1 ]+ view.floats[5]*projection.floats[5 ]+ view.floats[6]*projection.floats[9 ]+ view.floats[7]*projection.floats[13],
        view.floats[4]*projection.floats[2 ]+ view.floats[5]*projection.floats[6 ]+ view.floats[6]*projection.floats[10 ]+ view.floats[7]*projection.floats[14],
        view.floats[4]*projection.floats[3 ]+ view.floats[5]*projection.floats[7 ]+ view.floats[6]*projection.floats[11 ]+ view.floats[7]*projection.floats[15],
        view.floats[8]*projection.floats[0 ]+ view.floats[9]*projection.floats[4 ]+ view.floats[10]*projection.floats[8 ]+ view.floats[11]*projection.floats[12],
        view.floats[8]*projection.floats[1 ]+ view.floats[9]*projection.floats[5 ]+ view.floats[10]*projection.floats[9 ]+ view.floats[11]*projection.floats[13],
        view.floats[8]*projection.floats[2 ]+ view.floats[9]*projection.floats[6 ]+ view.floats[10]*projection.floats[10 ]+ view.floats[11]*projection.floats[14],
        view.floats[8]*projection.floats[3 ]+ view.floats[9]*projection.floats[7 ]+ view.floats[10]*projection.floats[11 ]+ view.floats[11]*projection.floats[15],
        view.floats[12]*projection.floats[0 ]+ view.floats[13]*projection.floats[4 ]+ view.floats[14]*projection.floats[8 ]+ view.floats[15]*projection.floats[12],
        view.floats[12]*projection.floats[1 ]+ view.floats[13]*projection.floats[5 ]+ view.floats[14]*projection.floats[9 ]+ view.floats[15]*projection.floats[13],
        view.floats[12]*projection.floats[2 ]+ view.floats[13]*projection.floats[6 ]+ view.floats[14]*projection.floats[10 ]+ view.floats[15]*projection.floats[14],
        view.floats[12]*projection.floats[3 ]+ view.floats[13]*projection.floats[7 ]+ view.floats[14]*projection.floats[11 ]+ view.floats[15]*projection.floats[15 ]};

    // Calculate inverted matrix -> MatrixInvert(matViewProj);
    // Cache the matrix values (speed optimization)
    a00 := matViewProj.floats[0]; a01 := matViewProj.floats[1]; a02 := matViewProj.floats[2]; a03 := matViewProj.floats[3];
    a10 := matViewProj.floats[4]; a11 := matViewProj.floats[5]; a12 := matViewProj.floats[6]; a13 := matViewProj.floats[7];
    a20 := matViewProj.floats[8]; a21 := matViewProj.floats[9]; a22 := matViewProj.floats[10]; a23 := matViewProj.floats[11];
    a30 := matViewProj.floats[12]; a31 := matViewProj.floats[13]; a32 := matViewProj.floats[14]; a33 := matViewProj.floats[15];

    b00 := a00*a11 - a01*a10;
    b01 := a00*a12 - a02*a10;
    b02 := a00*a13 - a03*a10;
    b03 := a01*a12 - a02*a11;
    b04 := a01*a13 - a03*a11;
    b05 := a02*a13 - a03*a12;
    b06 := a20*a31 - a21*a30;
    b07 := a20*a32 - a22*a30;
    b08 := a20*a33 - a23*a30;
    b09 := a21*a32 - a22*a31;
    b10 := a21*a33 - a23*a31;
    b11 := a22*a33 - a23*a32;

    // Calculate the invert determinant (inlined to avoid double-caching)
    invDet : float = 1.0/(b00*b11 - b01*b10 + b02*b09 + b03*b08 - b04*b07 + b05*b06);

    matViewProjInv := Matrix4.{
        (a11*b11 - a12*b10 + a13*b09)*invDet,
        (-a01*b11 + a02*b10 - a03*b09)*invDet,
        (a31*b05 - a32*b04 + a33*b03)*invDet,
        (-a21*b05 + a22*b04 - a23*b03)*invDet,
        (-a10*b11 + a12*b08 - a13*b07)*invDet,
        (a00*b11 - a02*b08 + a03*b07)*invDet,
        (-a30*b05 + a32*b02 - a33*b01)*invDet,
        (a20*b05 - a22*b02 + a23*b01)*invDet,
        (a10*b10 - a11*b08 + a13*b06)*invDet,
        (-a00*b10 + a01*b08 - a03*b06)*invDet,
        (a30*b04 - a31*b02 + a33*b00)*invDet,
        (-a20*b04 + a21*b02 - a23*b00)*invDet,
        (-a10*b09 + a11*b07 - a12*b06)*invDet,
        (a00*b09 - a01*b07 + a02*b06)*invDet,
        (-a30*b03 + a31*b01 - a32*b00)*invDet,
        (a20*b03 - a21*b01 + a22*b00)*invDet };

    // Create quaternion from source point
    quat: Quaternion = .{ source.x, source.y, source.z, 1.0 };

    // Multiply quat point by unprojecte matrix
    qtransformed : Quaternion = .{     // QuaternionTransform(quat, matViewProjInv)
        matViewProjInv.floats[0]*quat.x + matViewProjInv.floats[4]*quat.y + matViewProjInv.floats[8]*quat.z + matViewProjInv.floats[12]*quat.w,
        matViewProjInv.floats[1]*quat.x + matViewProjInv.floats[5]*quat.y + matViewProjInv.floats[9]*quat.z + matViewProjInv.floats[13]*quat.w,
        matViewProjInv.floats[2]*quat.x + matViewProjInv.floats[6]*quat.y + matViewProjInv.floats[10]*quat.z + matViewProjInv.floats[14]*quat.w,
        matViewProjInv.floats[3]*quat.x + matViewProjInv.floats[7]*quat.y + matViewProjInv.floats[11]*quat.z + matViewProjInv.floats[15]*quat.w };

    // Normalized world points in vectors
    result.x = qtransformed.x/qtransformed.w;
    result.y = qtransformed.y/qtransformed.w;
    result.z = qtransformed.z/qtransformed.w;

    return result;
}

#if FLAG_TEST_ENGINE {
    eps :: 0.001;
    approx  :: (a: float,   b: float)   -> bool { return abs(a - b) < eps; }
    approx3 :: (a: Vector3, b: Vector3) -> bool {
        return abs(a.x - b.x) < eps && abs(a.y - b.y) < eps && abs(a.z - b.z) < eps;
    }

    test_ray_cube_hit :: () {
        s := begin_suite("ray cube hit");
        ray  := Ray.{ origin = .{0, 0, -5}, direction = .{0, 0, 1} };
        cube := Collision_Cube.{ position = .{-1, -1, -1}, size = .{2, 2, 2} };
        col  := does_ray_hit_cube(ray, cube);
        check(*s, "ray along +Z hits cube",          col.hit);
        check(*s, "distance to front face is 4.0",   approx(col.distance, 4.0));
        check(*s, "hit point lands on front face",   approx3(col.point, .{0, 0, -1}));
        end_suite(s);
    }

    test_ray_cube_miss :: () {
        s := begin_suite("ray cube miss");
        {
            ray  := Ray.{ origin = .{3, 0, -5}, direction = .{0, 0, 1} };
            cube := Collision_Cube.{ position = .{-1, -1, -1}, size = .{2, 2, 2} };
            col  := does_ray_hit_cube(ray, cube);
            check(*s, "ray offset in X misses cube", !col.hit);
        }
        {
            ray  := Ray.{ origin = .{0, 0, 5}, direction = .{0, 0, 1} };
            cube := Collision_Cube.{ position = .{-1, -1, -1}, size = .{2, 2, 2} };
            col  := does_ray_hit_cube(ray, cube);
            check(*s, "ray pointing away misses cube", !col.hit);
        }
        end_suite(s);
    }

    // Face normals using size-2 cubes centered at origin.
    // NOTE: the current integer-truncation normal computation breaks for cubes
    // smaller than size 2 (e.g. trixel-sized cubes). Fix does_ray_hit_cube to
    // use the entry-face t-value comparison instead of truncating to s64.
    test_ray_cube_normals :: () {
        s    := begin_suite("ray cube face normals");
        cube := Collision_Cube.{ position = .{-1, -1, -1}, size = .{2, 2, 2} };

        col_neg_z := does_ray_hit_cube(Ray.{ origin = .{0, 0, -5}, direction = .{0,  0,  1} }, cube);
        col_pos_z := does_ray_hit_cube(Ray.{ origin = .{0, 0,  5}, direction = .{0,  0, -1} }, cube);
        col_pos_y := does_ray_hit_cube(Ray.{ origin = .{0, 5,  0}, direction = .{0, -1,  0} }, cube);
        col_neg_y := does_ray_hit_cube(Ray.{ origin = .{0,-5,  0}, direction = .{0,  1,  0} }, cube);
        col_pos_x := does_ray_hit_cube(Ray.{ origin = .{ 5, 0, 0}, direction = .{-1, 0,  0} }, cube);
        col_neg_x := does_ray_hit_cube(Ray.{ origin = .{-5, 0, 0}, direction = .{ 1, 0,  0} }, cube);

        check(*s, "-Z face normal is ( 0, 0,-1)", col_neg_z.hit && approx3(col_neg_z.normal, .{ 0,  0, -1}));
        check(*s, "+Z face normal is ( 0, 0, 1)", col_pos_z.hit && approx3(col_pos_z.normal, .{ 0,  0,  1}));
        check(*s, "+Y face normal is ( 0, 1, 0)", col_pos_y.hit && approx3(col_pos_y.normal, .{ 0,  1,  0}));
        check(*s, "-Y face normal is ( 0,-1, 0)", col_neg_y.hit && approx3(col_neg_y.normal, .{ 0, -1,  0}));
        check(*s, "+X face normal is ( 1, 0, 0)", col_pos_x.hit && approx3(col_pos_x.normal, .{ 1,  0,  0}));
        check(*s, "-X face normal is (-1, 0, 0)", col_neg_x.hit && approx3(col_neg_x.normal, .{-1,  0,  0}));
        end_suite(s);
    }

    // ray_plane_collision_point returns Vector2.{world_x, world_z}
    test_ray_plane :: () {
        s := begin_suite("ray plane collision");
        {
            ray := Ray.{ origin = .{3, 5, 2}, direction = .{0, -1, 0} };
            hit, point := ray_plane_collision_point(ray, 0.0);
            check(*s, "downward ray hits horizontal plane", hit);
            check(*s, "hit world-X matches ray origin X",  approx(point.x, 3.0));
            check(*s, "hit world-Z matches ray origin Z",  approx(point.y, 2.0));
        }
        {
            ray := Ray.{ origin = .{0, 0, 0}, direction = .{0, 1, 0} };
            hit, point := ray_plane_collision_point(ray, 10.0);
            check(*s, "upward ray hits plane above",  hit);
            check(*s, "hit world-X is 0",             approx(point.x, 0.0));
            check(*s, "hit world-Z is 0",             approx(point.y, 0.0));
        }
        {
            ray := Ray.{ origin = .{0, 5, 0}, direction = .{1, 0, 0} };
            hit, _ := ray_plane_collision_point(ray, 0.0);
            check(*s, "ray parallel to plane misses", !hit);
        }
        {
            ray := Ray.{ origin = .{0, 5, 0}, direction = .{0, 1, 0} };
            hit, _ := ray_plane_collision_point(ray, 0.0);
            check(*s, "ray pointing away misses", !hit);
        }
        // acceptable_radius is XZ distance from ray origin to hit point — needs a diagonal ray
        {
            ray := Ray.{ origin = .{0, 5, 0}, direction = normalize(Vector3.{0.1, -1, 0}) };
            hit, _ := ray_plane_collision_point(ray, 0.0, acceptable_radius = 10.0);
            check(*s, "hit within acceptable_radius succeeds", hit);
        }
        {
            ray := Ray.{ origin = .{0, 1, 0}, direction = normalize(Vector3.{100, -1, 0}) };
            hit, _ := ray_plane_collision_point(ray, 0.0, acceptable_radius = 1.0);
            check(*s, "hit outside acceptable_radius fails", !hit);
        }
        end_suite(s);
    }

    test_ray_trixel_normals :: () {
        s    := begin_suite("ray trixel-sized cube face normals");
        TS   : float : 1.0/16.0;  // TRIXEL_SIZE
        // Trixel at grid position (4,7,3): position = (4*TS, 7*TS, 3*TS)
        cube := Collision_Cube.{ position = .{4*TS, 7*TS, 3*TS}, size = .{TS, TS, TS} };
        cx   := 4*TS + TS*0.5;
        cy   := 7*TS + TS*0.5;
        cz   := 3*TS + TS*0.5;

        col_neg_z := does_ray_hit_cube(Ray.{ origin = .{cx, cy, cz - 1}, direction = .{0,  0,  1} }, cube);
        col_pos_z := does_ray_hit_cube(Ray.{ origin = .{cx, cy, cz + 1}, direction = .{0,  0, -1} }, cube);
        col_pos_y := does_ray_hit_cube(Ray.{ origin = .{cx, cy + 1, cz}, direction = .{0, -1,  0} }, cube);
        col_neg_y := does_ray_hit_cube(Ray.{ origin = .{cx, cy - 1, cz}, direction = .{0,  1,  0} }, cube);
        col_pos_x := does_ray_hit_cube(Ray.{ origin = .{cx + 1, cy, cz}, direction = .{-1, 0,  0} }, cube);
        col_neg_x := does_ray_hit_cube(Ray.{ origin = .{cx - 1, cy, cz}, direction = .{ 1, 0,  0} }, cube);

        check(*s, "-Z face normal is ( 0, 0,-1)", col_neg_z.hit && approx3(col_neg_z.normal, .{ 0,  0, -1}));
        check(*s, "+Z face normal is ( 0, 0, 1)", col_pos_z.hit && approx3(col_pos_z.normal, .{ 0,  0,  1}));
        check(*s, "+Y face normal is ( 0, 1, 0)", col_pos_y.hit && approx3(col_pos_y.normal, .{ 0,  1,  0}));
        check(*s, "-Y face normal is ( 0,-1, 0)", col_neg_y.hit && approx3(col_neg_y.normal, .{ 0, -1,  0}));
        check(*s, "+X face normal is ( 1, 0, 0)", col_pos_x.hit && approx3(col_pos_x.normal, .{ 1,  0,  0}));
        check(*s, "-X face normal is (-1, 0, 0)", col_neg_x.hit && approx3(col_neg_x.normal, .{-1,  0,  0}));
        end_suite(s);
    }

    #run {
        test_ray_cube_hit();
        test_ray_cube_miss();
        test_ray_cube_normals();
        test_ray_trixel_normals();
        test_ray_plane();
    }
}
