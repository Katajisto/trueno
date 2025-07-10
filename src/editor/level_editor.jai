#scope_file

get_level_editor_camera :: () -> Camera {
    camera: Camera;
    camera.near = 0.1;
    camera.far  = 100;

	camera.position = .{5,5,5};
	camera.target   = .{0,0,0};
    return camera;
}

#scope_export

tick_level_editor :: () {
	
}

draw_level_editor :: () {
	draw_sky(*get_level_editor_camera());
	cam := get_level_editor_camera();
	mvp := create_viewproj(*cam);

	vs_params : Trile_Vs_Params;
	vs_params.mvp = mvp.floats;

	mesh := get_trile("test");

	sg_apply_pipeline(gPipelines.trile.pipeline);


	bindings : sg_bindings;
	bindings.vertex_buffers[0] = mesh.vertex_buffer;
	bindings.vertex_buffers[1] = mesh.normal_buffer;
	
	sg_apply_bindings(*bindings);
	sg_apply_uniforms(UB_trile_vs_params, *(sg_range.{ ptr = *vs_params, size = size_of(type_of(vs_params))}));

	sg_draw(0, cast(s32) mesh.vertex_count, 1);

	
}

draw_level_editor_ui :: (theme: *GR.Overall_Theme) {
}
