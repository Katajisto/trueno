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

// At which 2D XZ point does a ray hit the ground plane at a height of
// plane_height. Used for the level editor and maybe later the trile editor as well.
ray_plane_collision_point :: (ray: Ray, plane_height: float, acceptable_radius: float = -1) -> (bool, Vector2) {
    dist_to_plane := ray.origin.y - plane_height;
    if ray.direction.y >= 0 then return false, .{0,0};
    multi := dist_to_plane / abs(ray.direction.y);
    ray_to_plane := ray.direction * multi;
    planePoint := ray_to_plane + ray.origin;
    if acceptable_radius > 0 && abs(length(Vector2.{planePoint.x, planePoint.z} - Vector2.{ray.origin.x, ray.origin.z})) > acceptable_radius {
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

    collision.normal = lerp(bmin, bmax, 0.5);
    collision.normal = collision.point - collision.normal;

    collision.normal.x = cast(float) cast(s64) collision.normal.x;
    collision.normal.y = cast(float) cast(s64) collision.normal.y;
    collision.normal.z = cast(float) cast(s64) collision.normal.z;
    collision.normal   = normalize(collision.normal);

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
