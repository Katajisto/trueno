#scope_file

subwindow         : GR.Subwindow_Info;
subwindow_initted : bool = false;
// @Hack: This is probably kinda a bad idea, I don't really know atm how else to get the theme into the subwindow.
theme_ptr         : GR.Overall_Theme;

current_pipeline : s32 = 0;
current_slot     : s32 = 0;
pipeline_names   : []string = .["arbtri", "trixel", "sky", "trile", "plane"];
slot_names       : []string = .["Slot 1","Slot 2","Slot 3","Slot 4","Slot 5","Slot 6","Slot 7","Slot 8"];

draw_subwindow_texture_debug :: (state: *GR.Subwindow_State, r: GR.Rect, data: *void) {
    r2 := r;
    r2.h = ui_h(5,0);
    r2.w = r.w * 0.75;
    GR.dropdown(r2, pipeline_names, *current_pipeline, *theme_ptr.dropdown_theme);
    r2.x += r2.w;
    r2.w = r.w * 0.25;
    GR.dropdown(r2, slot_names, *current_slot, *theme_ptr.dropdown_theme);

    r2.y = r.y + r2.h;
    r2.h = r.h - r2.h;
    r2.x = r.x;
    r2.w = r.w;

    uiTex := New(Ui_Texture ,,temp);

    bind : sg_bindings; 
    if current_pipeline == {
        case 0; bind = gPipelines.arbtri.bind;
        case 1; bind = gPipelines.trixel.bind;
        case 2; bind = gPipelines.sky.bind;
        case 3; bind = gPipelines.trile.bind;
        case 4; bind = gPipelines.plane.bind;
    }
    
    uiTex.tex = bind.images[current_slot]; 
    
    if uiTex.tex.id != INVALID_ID {
    	set_shader_for_images(uiTex);
        immediate_quad(.{r2.x, r2.y}, .{r2.x + r2.w, r2.y}, .{r2.x + r2.w, r2.y + r2.h}, .{r2.x, r2.y + r2.h});
    	set_shader_for_color();
    }
    immediate_flush();
}

#scope_export

draw_texture_debug :: () {
}

toggle_texdebug :: () {
    subwindow.open = !subwindow.open;
} @Command

draw_texture_debugger :: (theme: *GR.Overall_Theme) {
    if !subwindow.open then return;
    if !subwindow_initted {
        theme_ptr = theme;
        r := GR.get_rect(ui_w(40, 0), ui_w(40, 0), ui_h(50,0), ui_h(50,0));
        subwindow.rect        = r;
        subwindow.draw        = draw_subwindow_texture_debug;
        subwindow.title_text  = "Texture Debugger";
        subwindow.open        = false;
        subwindow_initted = true;
    }
    if subwindow.open {  // The Subwindow starts open, but pressing the Close button can close it.
        subwindow_state := GR.add_subwindow(*subwindow, *theme.subwindow_theme);
    }
}
