Ray :: struct {
    origin    : Vector3;
    direction : Vector3;
};

get_mouse_ray :: (cam: *Camera) -> Ray {
    sw, sh := get_window_size();
    normalized_mouse_x := (2.0 * input_mouse_x) / sw - 1.0;
    normalized_mouse_y := 1.0 - (2.0 * input_mouse_y) / sh;

    ray_clip : Vector4 = .{normalized_mouse_x, normalized_mouse_y, -1.0, 1.0};

    cam := get_trile_editor_camera();
    
    viewmat  := create_lookat(*cam);
    projmat  := create_perspective(*cam);
    ray_eye  := inverse(projmat) * ray_clip;
    ray_eye.z = -1.0;
    ray_eye.w =  0.0;

    ray_world_4d := (inverse(viewmat) * ray_eye);
    ray_world    :  Vector3 = .{ray_world_4d.x, ray_world_4d.y, ray_world_4d.z};
    ray_world     = normalize(ray_world);

    return .{
        origin    = cam.position,
        direction = ray_world
    };
}

Collision_Cube :: struct {
    position : Vector3;
    size     : Vector3;
};

does_ray_hit_cube :: (ray: Ray, cube: Collision_Cube) -> bool {
    cube_min := cube.position;
    cube_max := cube.position + cube.size;
    tMin := (cube_min - ray.origin) / ray.direction;
    tMax := (cube_max - ray.origin) / ray.direction;
    t1   := min(tMin, tMax);
    t2   := max(tMin, tMax);
    
    tNear := max(max(t1.x, t1.y), t1.z);
    tFar  := min(min(t2.x, t2.y), t2.z);

    return tNear > tFar;
}
