#load "console.jai";

draw_editor_ui :: (theme: *GR.Overall_Theme) {
    r := GR.get_rect(0,0,0,0);
    r.x = 0; r.w = 100*vw;
    r.y = 0; r.h = ui_h(5, 0);
    draw_bg_rectangle(r, theme);
    r.w = 15*vw;
    GR.label(r, tprint("Trueno v%.%", V_MAJOR, V_MINOR), *t_label_left(theme));
    r = GR.get_rect(0, ui_h(5,0), ui_w(20, 20), ui_h(95, 0));
    draw_bg_rectangle(r, theme);

    draw_console(theme);
}

tick_editor_ui :: () {
    tick_console();
}
