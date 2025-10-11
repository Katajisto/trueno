#scope_file

get_post_processing_camera :: () -> Camera {
    camera : Camera;
    camera.target = Vector3.{0,0,0};
    camera.position = Vector3.{5,5,5};
    camera.near = 1.0;
    camera.far = 2000.0;
    return camera;
}

#scope_export

tick_post_process_editor :: () {
    
}

draw_post_process_editor :: () {
    curworld := get_current_world();
    if !curworld.valid then return;
    create_set_cam_rendering_task(get_post_processing_camera());
	create_world_rendering_tasks(curworld.world);
}

draw_post_process_editor_ui :: (theme: *GR.Overall_Theme) {
    draw_picker(theme);  
    r := GR.get_rect(0, ui_h(5,0), ui_w(20, 20), ui_h(95, 0));
	ui_add_mouse_occluder(r);
    draw_bg_rectangle(r, theme);
    autoedit(r, *current_post_process, theme);
}
