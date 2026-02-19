#if OS != .WASM {
    #load "iprof.jai";
    #load "picker.jai";
    #load "trile_editor.jai";
    #load "level_editor.jai";
}
#if HAS_TACOMA { #load "tacoma.jai"; }
#load "console.jai";
#load "textureDebugger.jai";

#scope_file

Editor_View :: enum {
    Closed_Editor;
    Trile_Editor;
    Level_Editor; 
    Material_Editor;
};

current_editor_view : Editor_View = .Trile_Editor;

#scope_export

in_editor_view : bool = false;

init_editor :: () {
    #if OS != .WASM {init_profiler();}
    init_console();
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
            if GR.button(r, "Level studio", *t_button_selectable(theme, current_editor_view == .Level_Editor)) 
                then current_editor_view = .Level_Editor;

            r.x -= r.w;
            if GR.button(r, "Trile studio", *t_button_selectable(theme, current_editor_view == .Trile_Editor)) 
                then current_editor_view = .Trile_Editor;
        
            r.x -= r.w;
            if GR.button(r, "Material studio", *t_button_selectable(theme, current_editor_view == .Material_Editor)) 
                then current_editor_view = .Material_Editor;
    

            if current_editor_view == {
                case .Trile_Editor;
                    draw_trile_editor_ui(theme);
                case .Level_Editor;
                    draw_level_editor_ui(theme);
            }
        }
        draw_profiler();
    }
    draw_console(theme);
    draw_texture_debugger(theme);
    draw_postprocess_popup(theme);
    GR.draw_popups();
    immediate_flush();
}

draw_editor :: () {
    #if OS != .WASM {
        if !in_editor_view then return;

        if current_editor_view == {
            case .Trile_Editor;
                draw_trile_editor();
            case .Level_Editor;
                draw_level_editor();
        }
    }
}

tick_editor_ui :: () {
    if input_button_states[Key_Code.F3] & .START {
        in_editor_view = !in_editor_view;
        g_mixer.paused = in_editor_view;
    }

    #if OS != .WASM {
        if in_editor_view {
            if current_editor_view == {
                case .Trile_Editor;
                    tick_trile_editor();
                case .Level_Editor;
                    tick_level_editor();
            }
        }
    }

    tick_console();
}
