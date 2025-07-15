#load "console.jai";
#load "trile_editor.jai";
#load "level_editor.jai";

#scope_file

Editor_View :: enum {
    Closed_Editor;
    Trile_Editor;
    Level_Editor; 
};

current_editor_view : Editor_View = .Trile_Editor;

#scope_export

// Used when the console is open, so typing doesn't cause all sorts of stuff.
console_open_ignore_input : bool = false;


draw_editor_ui :: (theme: *GR.Overall_Theme) {
    r := GR.get_rect(0,0,0,0);
    r.x = 0; r.w = 100*vw;
    r.y = 0; r.h = ui_h(5, 0);
    draw_bg_rectangle(r, theme);
    r.w = 15*vw;
    GR.label(r, tprint("Trueno v%.%", V_MAJOR, V_MINOR), *t_label_left(theme));

    r.x = 100*vw - r.w;
    if GR.button(r, "Level editor", *t_button_selectable(theme, current_editor_view == .Level_Editor)) 
        then current_editor_view = .Level_Editor;

    r.x -= r.w;
    if GR.button(r, "Trile editor", *t_button_selectable(theme, current_editor_view == .Trile_Editor)) 
        then current_editor_view = .Trile_Editor;
    

    if current_editor_view == {
        case .Trile_Editor;
            draw_trile_editor_ui(theme);
        case .Level_Editor;
            draw_level_editor_ui(theme);
    }
    draw_console(theme);
}

draw_editor :: () {
    if current_editor_view == {
        case .Trile_Editor;
            draw_trile_editor();
        case .Level_Editor;
            draw_level_editor();
    }
    
}

tick_editor_ui :: () {
    if current_editor_view == {
        case .Trile_Editor;
            tick_trile_editor();
        case .Level_Editor;
            tick_level_editor();
    }
    tick_console();
}
