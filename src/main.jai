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

#if (FLAG_TEST_ENGINE || FLAG_TEST_EXE_ENGINE) { #load "tests/index.jai"; }

#load "logging.jai";
#load "pseudophysics/core.jai";
#load "pack_hotreload.jai";
#load "trile.jai";
#load "rendering/rendering.jai";
#load "input/hotkeys.jai";
#load "ui/ui.jai";
#load "editor/rdm_disk.jai";
#if !FLAG_RELEASE_BUILD { #load "editor/editor.jai"; }
#load "time.jai";
#load "events.jai";
#load "load.jai";
#load "ray.jai";
#load "profiling.jai";
#load "particles/particles.jai";
#load "world.jai";
#load "utils.jai";
#load "audio/audio.jai";
#load "assets/asset_manager.jai";
#load "settings_menu.jai";
#load "loading_screen.jai";
#load "ui/demo.jai";
    
#if !FLAG_TEST_EXE_ENGINE {
    #load "../game/game.jai";
} else {
    #load "../test_game/game.jai";
}

last_frame_time : float64; // timestamp of the last frame
delta\    _time : float64;

latest_frametime : float64; // latest frame generation duration

V_MAJOR :: 0;
V_MINOR :: 7;

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
        max_requests = 64,
        num_channels = 2,
        num_lanes    = 1,
        logger       = .{ func = slog_func },
    }));
    asset_manager_init();
    #if OS != .WASM { Thread.init(*g_mixer.mutex); }
    audio_init_thread_context();
    saudio_setup(*(saudio_desc.{
        logger = .{ func = slog_func },
        stream_cb = sokol_audio_callback,
    }));
    stm_setup();
    state.dpi_scale = sapp_dpi_scale();
    atlas_dim := round_pow2(1024.0 * state.dpi_scale);
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

    useless_mem : [1]u8;
    debug_font = get_font_at_size(useless_mem, 15);
    load_pack("boot", true, true);
    load_pack("core", true, false);
    load_pack("game_core", true, false);

    #if FLAG_TEST_EXE_ENGINE {
        engine_exe_tests_add();
    }
}

init_after_core :: () {
    init_plane_textures();
    init_brdf_lut();

    add_font_from_pack("boot", "DroidSerif-Regular.ttf");
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
    #if !FLAG_RELEASE_BUILD {
        init_editor();
    } else {
        init_keybinds();
        init_settings_menu();
    }
    init_rendering();
    load_post_process_from_pack();

    audio_init();

    // Let the game configure engine settings before full init.
    game_engine_config();

    init_world_system();
    // We want to do this last.
    game_init();

    // #if UNCAPPED_FRAMES then sapp_glx_swapinterval(0);
}

is_in_reflection_pass : bool = false;

delta_time_accumulator : float64 = 0;

frame :: () {
    clear_frame_profiling();
    check_and_handle_window_resize();
    delta_time = get_time() - last_frame_time;
    last_frame_time = get_time();

    asset_manager_tick();

    add_frame_profiling_point("After asset manager tick");
    
    if !mandatory_loads_done() {
        print("Mandatory loads not done!!\n");
        return;
    }

    if show_loading_screen() {
        input_per_frame_event_and_flag_update();
        if init_after_core_done {
            fonsClearState(state.fons);
            draw_loading_screen();
            tick_ui();
            ui_pass();
            render();
            reset_temporary_storage();
        }
        return;
    }

    if !init_after_core_done {
        init_after_core();
        init_after_core_done = true;
    }

    fonsClearState(state.fons);
    
    add_frame_profiling_point("After loading logic");
    
    #if FLAG_TEST_EXE_ENGINE {
       run_exe_tests();
    }
    
    frame_start_time := get_time();
    
    dpis := state.dpi_scale;

    #if OS != .WASM { tick_profiler(); }

    should_tick_game := #ifx FLAG_RELEASE_BUILD then true else !in_editor_view;

    if should_tick_game {
        delta_time_accumulator += delta_time;
        if delta_time_accumulator > (4.0/60.0) then delta_time_accumulator = 4.0/60.0;
    }

    if should_tick_game && !settings_menu_blocks_game() {
        while delta_time_accumulator > (1.0/480.0) {
            game_tick(1.0/480.0);
            tick_particles(1.0/480.0);
            delta_time_accumulator -= (1.0/480.0);
        }
    }
    fonsClearState(state.fons);
    for event: Input.events_this_frame {
        GR.getrect_handle_event(event);
    }


    add_frame_profiling_point("After game ticks");
    tick_ui();
    add_frame_profiling_point("After UI tick");

    // This populates our render task queue.
    if should_tick_game then game_draw();
    add_frame_profiling_point("After game draw");

    ui_clear_mouse_occluders();
    ui_pass();
    add_frame_profiling_point("After UI draw");

    #if !FLAG_RELEASE_BUILD {
        prepare_text(debug_font, tprint("frametime: % ms", delta_time * 1000));
        draw_prepared_text(debug_font, 10, 10, .{0.0, 1.0, 0.0, 1.0});
        draw_editor();
    }
   
    add_particle_render_tasks();
    add_frame_profiling_point("After editor draw");
    render();
    add_frame_profiling_point("After rendering");

    end_frame_profiling();
    #if MEM_DEBUG {
        memory_visualizer_per_frame_update();
    }

    #if OS != .WASM { profiler_update(); }
    reset_temporary_storage();
    frame_end_time := get_time();
    input_per_frame_event_and_flag_update();
}

cleanup :: () {
    log_info("Cleanup called....");
    audio_cleanup(); 
    sg_shutdown();
}

get_window_size :: () -> (s32, s32) {
    return sapp_width(), sapp_height();
}
