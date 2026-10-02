// Rendering. Everything outside this directory goes through the Scene API in
// scene.jai and text.jai.

#load "scene.jai";
#load "text.jai";
#load "camera.jai";
#load "debug_draw.jai";
#load "animation.jai";

#if RENDERER == "sokol" {
    #load "../renderer_sokol/renderer.jai";
} else {
    #assert false "Unknown renderer; build with renderer=sokol.";
}

render :: () {
    text_end_frame();
    w, h := get_window_size();
    scene_end_frame(w, h);
    g_debug_line_count   = 0;
    g_overlay_line_count = 0;
}

check_and_handle_window_resize :: () {
    w, h := get_window_size();
    if !initted {
        old_w = w;
        old_h = h;
        initted = true;
        return;
    }
    if w != old_w || h != old_h {
        old_w = w; old_h = h;
        // UI font sizes follow the window, so stale sizes would fill the atlas.
        text_reset_atlas();
    }
}

#scope_file

initted : bool;
old_w : int;
old_h : int;
