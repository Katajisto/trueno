#scope_file

subwindow         : GR.Subwindow_Info;
subwindow_initted : bool = false;

current_pipeline : s32 = 0;
current_slot     : s32 = 0;
pipeline_names   : []string = .["arbtri", "trixel", "sky", "trile", "plane"];
slot_names       : []string = .["Slot 1","Slot 2","Slot 3","Slot 4","Slot 5","Slot 6","Slot 7","Slot 8"];


draw_subwindow_texture_debug :: (state: *GR.Subwindow_State, r: GR.Rect, data: *void) {
    r2 := r;
    r2.h = ui_h(5,0);
    r2.w = r.w * 0.75;
    GR.dropdown(r2, pipeline_names, *current_pipeline, null);
    r2.x += r2.w;
    r2.w = r.w * 0.25;
    GR.dropdown(r2, slot_names, *current_slot, null);

    r2.h = r.h - r2.h;
    r2.y = r.y + r2.h;
    immediate_flush();
}

#scope_export

draw_texture_debug :: () {
	uiTex := Ui_Texture.{gPipelines.plane.bind.images[0]};
	set_shader_for_images(*uiTex);
    immediate_quad(.{0, 0}, .{0 + 500, 0}, .{0 + 500, 0 + 500}, .{0, 0 + 500});
	set_shader_for_color();
}

toggle_texdebug :: () {
    subwindow.open = !subwindow.open;
} @Command

draw_texture_debugger :: (theme: *GR.Overall_Theme) {
    if !subwindow.open then return;
    if !subwindow_initted {
        r := GR.get_rect(ui_w(40, 0), ui_w(40, 0), ui_h(50,0), ui_h(50,0));
        subwindow.rect        = r;
        subwindow.draw        = draw_subwindow_texture_debug;
        subwindow.title_text  = "Texture Debugger";
        subwindow_initted = true;
    }
    if subwindow.open {  // The Subwindow starts open, but pressing the Close button can close it.
        subwindow_state := GR.add_subwindow(*subwindow, *theme.subwindow_theme);
    }
}
