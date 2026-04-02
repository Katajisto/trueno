/*

    The rendering pipeline.

    @ToDo: Write something smart about our rendering
           architecture. 

*/

#load "sky.jai";
#load "ssao.jai";
#load "core.jai";
#load "tasks.jai";
#load "camera.jai";
#load "arbtri.jai";
#load "debug_draw.jai";
#load "meshgen.jai";
#load "helpers.jai";
#load "animation.jai";
#load "pipelines.jai";
#load "post_processing.jai";
#load "backend_sokol_helpers.jai";

#scope_file

initted : bool;
old_w : int;
old_h : int;

on_window_resize :: () {
    // Recreate textures that are rendering targets and dependent on window size.
    create_plane_pipeline_reflection_images();
    create_final_image();
    create_ssao_images();
    // Reset glyph cache so stale sizes from resizing don't fill the atlas.
    w, h : s32;
    fonsGetAtlasSize(state.fons, *w, *h);
    fonsResetAtlas(state.fons, w, h);
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
