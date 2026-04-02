#if OS != .WASM {
    #load "iprof.jai";
    #load "trile_thumbnails.jai";
    #load "picker.jai";
    #load "trile_editor.jai";
    #load "level_editor.jai";
    #load "particle_editor.jai";
}
#if FLAG_TACOMA_ENABLED { #load "tacoma.jai"; }
#load "console.jai";
#load "textureDebugger.jai";

#scope_file

Editor_View :: enum {
    Closed_Editor;
    Trile_Editor;
    Level_Editor;
    Particle_Editor;
};

current_editor_view : Editor_View = .Trile_Editor;

#scope_export

in_editor_view : bool = false;

init_editor :: () {
    #if !FLAG_RELEASE_BUILD {
        #if OS != .WASM {
            init_profiler();
            init_trile_thumbnails();
        }
        init_console();
    }
    init_keybinds();
    init_settings_menu();
}

// Used when the console is open, so typing doesn't cause all sorts of stuff.
console_open_ignore_input : bool = false;


draw_editor_ui :: (theme: *GR.Overall_Theme) {
    #if OS != .WASM {
        if in_editor_view {
            r := GR.get_rect(0,0,0,0);
            r.x = 0; r.w = 100*vw;
            r.y = 0; r.h = ui_h(5, 0);
            draw_bg_rectangle(r, theme);
            r.w = 15*vw;
            GR.label(r, tprint("Trueno v%.%", V_MAJOR, V_MINOR), *t_label_left(theme));

            r.x = 100*vw - r.w;
            if keybind_button(r, "Level studio",    .STUDIO_LEVEL,    *t_button_selectable(theme, current_editor_view == .Level_Editor))    { clear_particles(); current_editor_view = .Level_Editor; }
            r.x -= r.w;
            if keybind_button(r, "Trile studio",    .STUDIO_TRILE,    *t_button_selectable(theme, current_editor_view == .Trile_Editor))    { clear_particles(); current_editor_view = .Trile_Editor; }
            r.x -= r.w;
            if keybind_button(r, "Particle studio", .STUDIO_MATERIAL, *t_button_selectable(theme, current_editor_view == .Particle_Editor)) { clear_particles(); current_editor_view = .Particle_Editor; }

            if current_editor_view == {
                case .Trile_Editor;
                    draw_trile_editor_ui(theme);
                case .Level_Editor;
                    draw_level_editor_ui(theme);
                case .Particle_Editor;
                    draw_particle_editor_ui(theme);
            }
        }
        draw_profiler();
    }
    draw_texture_debugger(theme);
    draw_postprocess_popup(theme);
    draw_lighting_popup(theme);
    GR.draw_popups();
    immediate_flush();
}

draw_editor :: () {
    #if OS != .WASM {
        if !in_editor_view then return;

        bypass_postprocess = (current_editor_view == .Trile_Editor);

        if current_editor_view == {
            case .Trile_Editor;
                draw_trile_editor();
            case .Level_Editor;
                draw_level_editor();
            case .Particle_Editor;
                draw_particle_editor();
        }
    }
}

tick_editor_ui :: () {
    if is_action_start(Editor_Action.TOGGLE_EDITOR) {
        in_editor_view = !in_editor_view;
        g_mixer.paused = in_editor_view;
        if !in_editor_view then bypass_postprocess = false;
        clear_particles();
    }

    #if !FLAG_RELEASE_BUILD && OS != .WASM {
        if is_action_start(Editor_Action.HOT_RELOAD) {
            g_asset_manager.pending_hot_reload = true;
            log_info("Hot-reload: queued, waiting for in-flight loads to finish...");
        }
    }

    #if OS != .WASM {
        if in_editor_view {
            if current_editor_view == {
                case .Trile_Editor;
                    tick_trile_editor();
                case .Level_Editor;
                    tick_level_editor();
                case .Particle_Editor;
                    tick_particle_editor();
            }
        }
    }

    tick_console();
    tick_settings_menu();
}
