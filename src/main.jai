MEM_DEBUG :: false;

#if MEM_DEBUG {
    #import "Basic"()(MEMORY_DEBUGGER=true);
} else {
    #import "Basic";
}
#import "Math";
#import "Input";
#import "Hash_Table";
#import "Hash";
#import "Simple_Package_Reader";

String :: #import "String";
Jaison :: #import "Jaison";
stbi   :: #import "stb_image";

#load "trile.jai";
#load "rendering/rendering.jai";
#load "input/hotkeys.jai";
#load "ui/ui.jai";
#load "editor/editor.jai";
#load "time.jai";
#load "events.jai";
#load "load.jai";
#load "ray.jai";
#load "world.jai";
    
#if USE_SAMPLE_GAME {
    #load "../sample_game/game.jai";
} else {
    #load "../game/game.jai";
}

last_frame_time : float64; // timestamp of the last frame
delta\    _time : float64;

latest_frametime : float64; // latest frame generation duration

V_MAJOR :: 0;
V_MINOR :: 6;

state: struct {
    pass_action_clear : sg_pass_action;
    pass_action_clear_gbuf : sg_pass_action;
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

debug_font : *Font;

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

    state.pass_action_clear.colors[0] = .{ load_action = .CLEAR, clear_value = .{ r = 0, g = 0, b = 0, a = 0 } };
    state.pass_action_clear_gbuf.colors[0] = .{ load_action = .CLEAR, clear_value = .{ r = 0, g = 0, b = 1000, a = 0 } };
    state.pass_action.colors[0] = .{ load_action = .LOAD };

    init_asset_pack_load();
    useless_mem : [1]u8;
    debug_font = get_font_at_size(useless_mem, 15);
}

init_after_asset_pack :: () {
    init_plane_textures();
    add_font_from_pack("./resources/DroidSerif-Regular.ttf");
    ui_init_font_fields(*state.font_default);

    init_ui();
    ltriles();
    tt := get_trile_table_ptr();
    if tt.count == 0 {
        set_trile("test", Trile.{});
    } else {
        name : string;
        for v : tt {
            name = v.name;
            break;
        }
    }
    init_editor();
    lworlds();
    init_spritesheets();
    init_rendering();
    load_color_lut_images();
    load_post_process_from_pack();

    // We want to do this last.
    game_init();

    #if UNCAPPED_FRAMES then sapp_glx_swapinterval(0);
}

is_in_reflection_pass : bool = false;

delta_time_accumulator : float64 = 0;

frame :: () {
    check_and_handle_window_resize();
    delta_time = get_time() - last_frame_time;
    last_frame_time = get_time();


    sfetch_dowork();

    if mandatory_loads_done() && !init_after_mandatory_done {
        init_after_asset_pack();
        init_after_mandatory_done = true;
    }

    if !mandatory_loads_done() then return;
    fonsClearState(state.fons);
    
    frame_start_time := get_time();
    
    dpis := state.dpi_scale;

    #if OS != .WASM { tick_profiler(); }

    delta_time_accumulator += delta_time;
    
    if !in_editor_view {
        while delta_time_accumulator > (1.0/60.0) {
            game_tick(1.0/60.0);
            delta_time_accumulator -= (1.0/60.0);
            input_per_frame_event_and_flag_update();
        }
    }
    fonsClearState(state.fons);
    for event: Input.events_this_frame {
        GR.getrect_handle_event(event);
    }


    tick_ui();

    // This populates our render task queue.
    if !in_editor_view then game_draw();

    ui_clear_mouse_occluders();
    ui_pass();
    prepare_text(debug_font, tprint("frametime: % ms", latest_frametime * 1000));
    draw_prepared_text(debug_font, 10, 10, .{0.0, 1.0, 0.0, 1.0});
    draw_editor();
    render();
    #if MEM_DEBUG {
        memory_visualizer_per_frame_update();
    }

    #if OS != .WASM { profiler_update(); }
    reset_temporary_storage();
    frame_end_time := get_time();
    latest_frametime = frame_end_time - frame_start_time;
}

cleanup :: () {
    sg_shutdown();
}

get_window_size :: () -> (s32, s32) {
    return sapp_width(), sapp_height();
}
