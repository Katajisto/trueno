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

sun_shadowmap_viewproj :: (cam: *Camera, conf: *World_Config) -> Matrix4 {
	up: Vector3 = .{0, 1, 0};
	targetToPos := conf.sunPosition;
	A := normalize(targetToPos);
	B := normalize(cross(up, A));
	C := cross(A, B);
    
    sunCameraPosition := cam.target + 20*A;

	view := Matrix4.{
		B.x, C.x, A.x, 0,
		B.y, C.y, A.y, 0,
		B.z, C.z, A.z, 0,
		-dot(B, sunCameraPosition), -dot(C, sunCameraPosition), -dot(A, sunCameraPosition), 1
	};

    top := 10.0; right := 10.0;
    proj := orthographic_projection_matrix(-right, right, -top, top, 5, 100, true);
    return view * proj;
}
