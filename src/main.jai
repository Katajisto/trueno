#import "Basic";
#import "Math";
#load "ui/ui.jai";
#load "pipelines.jai";
#load "time.jai";
#load "arbtri.jai";
#load "events.jai";
#load "load.jai";
#load "./shaders/jai/shader_triangle.jai";

state: struct {
    pass_action: sg_pass_action;
    dpi_scale: float;
    fons: *FONScontext;
    font_default: s32;
};

Window_Info :: struct {
    width: s32;
    height: s32;
    title: *u8;
};

get_window_info :: () -> Window_Info {
    return Window_Info.{
        1200,
        1200,
        "trueno!"
    };
}

round_pow2 :: (v: float) -> s32 {
    vi := (cast(u32) v) - 1;
    for i : 0..4 {
        vi |= (vi >> (1<<i));
    }
    return cast(s32) (vi + 1);
}

init :: () {
    sg_setup(*(sg_desc.{
        environment = cast,force(sg_environment) sglue_environment(),
        logger = .{ func = slog_func },
    }));
    sgl_setup(*(sgl_desc_t.{
        logger = .{ func = slog_func },
    }));
    sfetch_setup(*(sfetch_desc_t.{
        logger = .{ func = slog_func },
    }));
    stm_setup();
    state.dpi_scale = sapp_dpi_scale();
    atlas_dim := round_pow2(512.0 * state.dpi_scale);
    fons_context := sfons_create(*(sfons_desc_t.{
        width = atlas_dim,
        height = atlas_dim,
    }));
    state.fons = fons_context;
    state.font_default = FONS_INVALID;
        // file_data := read_entire_file("./");
        // state.font_default = fonsAddFontMem(state.fons, "sans", *file_data[0], xx file_data.count, 0);

    create_pipelines();

    // a pass action to clear framebuffer to black
    state.pass_action.colors[0] = .{ load_action = .CLEAR, clear_value = .{ r = 0.5, g = 0.5, b = 0.9, a = 1 } };
    init_ui();
    init_font_loads();
}

frame :: () {
    dpis := state.dpi_scale;

    sfetch_dowork();

    fonsClearState(state.fons);
    sgl_defaults();
    sgl_matrix_mode_projection();
    sgl_ortho(0.0, sapp_widthf(), sapp_heightf(), 0.0, -1.0, +1.0);
    black := sfons_rgba(0, 0, 0, 255);

    tick_ui();
    sg_begin_pass(*(sg_pass.{ action = state.pass_action, swapchain = cast,force(sg_swapchain) sglue_swapchain() }));
        render_ui();
        sfons_flush(state.fons);
        arb_tri_flush();
        sgl_draw();
    sg_end_pass();
    sg_commit();

    reset_temporary_storage();
}

cleanup :: () {
    sg_shutdown();
}

get_window_size :: () -> (s32, s32) {
    return sapp_width(), sapp_height();
}
