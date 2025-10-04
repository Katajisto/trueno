#load "groundplane.jai";
#load "sky.jai";

#scope_file

initted : bool;
old_w : int;
old_h : int;

on_window_resize :: () {
    create_plane_pipeline_reflection_images();
}

#scope_export

check_and_handle_window_resize :: () {
    w,h := get_window_size();
    if !initted {
        old_w = w;
        old_h = h;
        initted = true;
        return;
    }
    if w != old_w || h != old_h {
        old_w = w; old_h = h;
        on_window_resize();
    }
}
