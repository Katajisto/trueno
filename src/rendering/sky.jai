draw_sky :: (cam: *Camera, worldConfig: *World_Config = null) {
    mvp := create_viewproj(cam);
    vs_params : Sky_Vs_Params;

    world_conf : Sky_World_Config;

    wc : *World_Config = ifx worldConfig == null then *(World_Config.{}) else worldConfig;

    world_config_to_shader_type(wc, *world_conf);

    vs_params.mvp = mvp.floats;
    sg_apply_pipeline(gPipelines.sky.pipeline);
    sg_apply_bindings(*gPipelines.sky.bind);
    sg_apply_uniforms(UB_sky_vs_params, *(sg_range.{ ptr = *vs_params, size = size_of(type_of(vs_params)) }));
    sg_apply_uniforms(UB_sky_world_config, *(sg_range.{ptr = *world_conf, size = size_of(type_of(world_conf))}));
    sg_draw(0, 36, 1);
}

get_frustum_corners :: (cam: *Camera) -> [8]Vector3 {
    mat_view := create_lookat(cam);
    mat_proj := create_perspective(cam);

    corners : [8]Vector3;
    corners[0] = unproject(Vector3.{-1, -1, -1}, mat_proj, mat_view);
    corners[1] = unproject(Vector3.{1, -1, -1}, mat_proj, mat_view);
    corners[2] = unproject(Vector3.{1, 1, -1}, mat_proj, mat_view);
    corners[3] = unproject(Vector3.{-1, 1, -1}, mat_proj, mat_view);
    corners[4] = unproject(Vector3.{-1, -1, 1}, mat_proj, mat_view);
    corners[5] = unproject(Vector3.{1, -1, 1}, mat_proj, mat_view);
    corners[6] = unproject(Vector3.{1, 1, 1}, mat_proj, mat_view);
    corners[7] = unproject(Vector3.{-1, 1, 1}, mat_proj, mat_view);
    return corners;
}

create_shadow_viewproj :: (cam: *Camera, conf: *World_Config) -> Matrix4 {
	up: Vector3 = .{0, 1, 0};
	targetToPos := conf.sunPosition;
	A := normalize(targetToPos);
	B := normalize(cross(up, A));
	C := cross(A, B);
    
	camcpy := cam.*;
	camcpy.far = 50;
	camcpy.near = 0.5;
	
    frustum_corners := get_frustum_corners(*camcpy);

	avg : Vector3;
	for frustum_corners {
		avg += it;
	}
	avg /= 8.0;
    sunCameraPosition := -targetToPos * 50.0;

	view := Matrix4.{
		B.x, C.x, A.x, 0,
		B.y, C.y, A.y, 0,
		B.z, C.z, A.z, 0,
		-dot(B, sunCameraPosition), -dot(C, sunCameraPosition), -dot(A, sunCameraPosition), 1
	};
    proj := matrix_ortho(-15, 15, -15, 15, 0, 100);
    return view*proj;
}

// taken from raymath.h
matrix_ortho :: (left: float, right: float, bottom: float, top: float, near: float, far: float) -> Matrix4 {
	rl := right - left;
	tb := top - bottom;
	fn := far - near;

	return Matrix4.{
		2.0/rl,0,0,0,
		0,2.0/tb,0,0,
		0,0,-2/fn,0,
		-(left + right)/rl, -(top+bottom)/tb, (far+near)/fn, 1
	};
	
}
