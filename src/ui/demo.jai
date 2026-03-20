#if FLAG_DEMO_BUILD {

demo_saved_ssao       : float = -1.0;
demo_saved_tonemap    : float = -1.0;
demo_saved_rdm_diff   : float = -1.0;
demo_saved_rdm_spec   : float = -1.0;

demo_toggle_float :: (val: *float, saved: *float, default: float) {
    if val.* > 0 {
        saved.* = val.*;
        val.* = 0.0;
    } else {
        val.* = ifx saved.* > 0 then saved.* else default;
    }
}

draw_demo_ui :: (theme: *GR.Overall_Theme) {
    r := GR.get_rect(ui_w(86,0), ui_h(1,0), ui_w(13,0), ui_h(3,0));

    rdm_diff_on := current_lighting_config.rdm_diff_scale > 0;
    if GR.button(r, ifx rdm_diff_on then "RDM Diffuse: ON" else "RDM Diffuse: OFF") {
        demo_toggle_float(*current_lighting_config.rdm_diff_scale, *demo_saved_rdm_diff, 1.0);
    }
    r.y += r.h * 1.3;

    rdm_spec_on := current_lighting_config.rdm_spec_scale > 0;
    if GR.button(r, ifx rdm_spec_on then "RDM Specular: ON" else "RDM Specular: OFF") {
        demo_toggle_float(*current_lighting_config.rdm_spec_scale, *demo_saved_rdm_spec, 1.0);
    }
    r.y += r.h * 1.3;

    if GR.button(r, ifx !bypass_shadows then "Shadows: ON" else "Shadows: OFF") {
        bypass_shadows = !bypass_shadows;
    }
    r.y += r.h * 1.3;

    if GR.button(r, ifx !bypass_reflections then "Reflections: ON" else "Reflections: OFF") {
        bypass_reflections = !bypass_reflections;
    }
    r.y += r.h * 1.3;

    ssao_on := current_post_process.ssao > 0;
    if GR.button(r, ifx ssao_on then "SSAO: ON" else "SSAO: OFF") {
        demo_toggle_float(*current_post_process.ssao, *demo_saved_ssao, 1.0);
    }
    r.y += r.h * 1.3;

    tonemap_on := current_post_process.tonemap > 0;
    if GR.button(r, ifx tonemap_on then "Tonemapping: ON" else "Tonemapping: OFF") {
        demo_toggle_float(*current_post_process.tonemap, *demo_saved_tonemap, 1.0);
    }
    r.y += r.h * 1.3;

    if GR.button(r, ifx !bypass_postprocess then "Post FX: ON" else "Post FX: OFF") {
        bypass_postprocess = !bypass_postprocess;
    }
}

} // #if FLAG_DEMO_BUILD
