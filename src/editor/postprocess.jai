#scope_file

world : World; // @ToDo: Actually load the world from somewhere once we have actual world management.


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
    create_set_cam_rendering_task(get_post_processing_camera());
	create_world_rendering_tasks(*world);
}

draw_post_process_editor_ui :: (theme: *GR.Overall_Theme) {
    
}
