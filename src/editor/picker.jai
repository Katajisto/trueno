#scope_file

Picker :: enum {
    TRILE;
    WORLD;
}

current_picker : Picker = .TRILE;

#scope_export

draw_picker :: (theme: *GR.Overall_Theme) {
    r := GR.get_rect(ui_w(85,0), ui_h(5,0), ui_w(15, 0), ui_h(95, 0));
    draw_bg_rectangle(r, theme);
	ui_add_mouse_occluder(r);
    
    tab_r := r;
    tab_r.h = ui_h(3,0);
    tab_r.w = r.w / 2;

    if GR.button(tab_r, "Triles", *t_button_tab(theme, current_picker == .TRILE)) {
		current_picker = .TRILE;
    }
    tab_r.x += tab_r.w;
    if GR.button(tab_r, "Worlds", *t_button_tab(theme, current_picker == .WORLD)) {
		current_picker = .WORLD;
    }

    r.y += tab_r.h;
    r.h -= tab_r.h;

    // @ToDo: Add a scrollable zone here so that
    // our triles or worlds can overflow.
    if current_picker == {
        case .TRILE;
            draw_trile_picker(r, theme);
        case .WORLD;
            draw_world_picker(r, theme);
    }
}
