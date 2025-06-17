#import "Basic";
#import "Math";
#import "Input";
stbi :: #import "stb_image";

#load "trile.jai";
#load "ui/ui.jai";
#load "editor/editor.jai";
#load "pipelines.jai";
#load "time.jai";
#load "arbtri.jai";
#load "events.jai";
#load "load.jai";
#load "camera.jai";
#load "ray.jai";

last_frame_time : float64;
delta\    _time : float64;

V_MAJOR :: 0;
V_MINOR :: 3;

state: struct {
    pass_action_clear : sg_pass_action;
    pass_action       : sg_pass_action;
    dpi_scale         : float;
    fons              : *FONScontext;
    font_default      : Ui_Font;
};

Window_Info :: struct {
    width  : s32;
    height : s32;
    title  : *u8;
};

get_window_info :: () -> Window_Info {
    
    return Window_Info.{
        1920,
        1080,
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
    state.font_default.fons_font = FONS_INVALID;
    create_pipelines();

    state.pass_action_clear.colors[0] = .{ load_action = .CLEAR, clear_value = .{ r = 0.6, g = 0.7, b = 1.0, a = 1 } };
    state.pass_action.colors[0] = .{ load_action = .LOAD };
    init_font_loads();
}

init_after_mandatory_loads :: () {
    init_ui();
}

cam : Camera;

frame :: () {
    delta_time = get_time() - last_frame_time;
    last_frame_time = get_time();

    sfetch_dowork();

    if mandatory_loads_done() && !init_after_mandatory_done {
        init_after_mandatory_loads();
        init_after_mandatory_done = true;
    }

    if !mandatory_loads_done() then return;
    fonsClearState(state.fons);
    
    dpis := state.dpi_scale;

    fonsClearState(state.fons);
    for event: Input.events_this_frame {
        GR.getrect_handle_event(event);
    }
    

    sgl_defaults();
    sgl_matrix_mode_projection();
    sgl_ortho(0.0, sapp_widthf(), sapp_heightf(), 0.0, -1.0, +1.0);

    sg_begin_pass(*(sg_pass.{ action = state.pass_action_clear, swapchain = cast,force(sg_swapchain) sglue_swapchain() }));
    tick_ui();
    ui_pass();
    draw_trile();
    sg_end_pass();
    sg_commit();

    input_per_frame_event_and_flag_update();
    
    reset_temporary_storage();
}

cleanup :: () {
    sg_shutdown();
}

get_window_size :: () -> (s32, s32) {
    return sapp_width(), sapp_height();
}
