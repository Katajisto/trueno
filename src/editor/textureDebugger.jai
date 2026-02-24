#scope_file

subwindow         : GR.Subwindow_Info;
subwindow_initted : bool = false;

pp_subwindow         : GR.Subwindow_Info;
pp_subwindow_initted : bool = false;

lighting_subwindow         : GR.Subwindow_Info;
lighting_subwindow_initted : bool = false;
// @Hack: This is probably kinda a bad idea, I don't really know atm how else to get the theme into the subwindow.
theme_ptr         : GR.Overall_Theme;

current_pipeline : s32 = 0;
current_slot     : s32 = 0;
pipeline_names   : []string = .["shadowmap", "reflection", "main", "position", "normal", "ssao", "rdm_atlas (chunk)", "rdm_lookup (chunk)"];

draw_subwindow_texture_debug :: (state: *GR.Subwindow_State, r: GR.Rect, data: *void) {
    r2 := r;
    r2.h = ui_h(5,0);
    r2.w = r.w;
    GR.dropdown(r2, pipeline_names, *current_pipeline, *theme_ptr.dropdown_theme);

    r2.y = r.y + r2.h;
    r2.h = r.h - r2.h;
    r2.x = r.x;
    r2.w = r.w;

    uiTex := New(Ui_Texture ,,temp);

    image : sg_image; 
    if current_pipeline == {
        case 0; image = g_shadowmap_img;
        case 1; image = gPipelines.plane.bind.images[0];
        case 2; image = g_rendertex;
        case 3; image = g_gbuf_position;
        case 4; image = g_gbuf_normal;
        case 5; image = g_ssaobuf;
        case 6; #through;
        case 7;
            cw := get_current_world();
            for chunk: cw.world.chunks {
                if chunk.rdm_valid {
                    if current_pipeline == 6 then image = chunk.rdm_atlas;
                    else                          image = chunk.rdm_lookup;
                    break;
                }
            }
    }
    
    uiTex.tex = image; 
    
    if uiTex.tex.id != INVALID_ID {
    	set_shader_for_images(uiTex);
        immediate_quad(.{r2.x, r2.y}, .{r2.x + r2.w, r2.y}, .{r2.x + r2.w, r2.y + r2.h}, .{r2.x, r2.y + r2.h});
    	set_shader_for_color();
    }
    immediate_flush();
}

draw_subwindow_lighting :: (state: *GR.Subwindow_State, r: GR.Rect, data: *void) {
    ui_add_mouse_occluder(r);
    autoedit(r, *current_lighting_config, *theme_ptr);
}

draw_subwindow_post_process :: (state: *GR.Subwindow_State, r: GR.Rect, data: *void) {
    r2 := r;
	ui_add_mouse_occluder(r);
    r3 := r;
    r3.h =  ui_h(5,0);
    r2.h -= r3.h;
    r2.y += r3.h;
    if GR.button(r3, "Save postprocessing", *theme_ptr.button_theme) {
        #if OS != .WASM {
            file :: #import "File";
            save_post_process();
        }
    }
    r3.y += r3.h;
    r2.h -= r3.h;
    r2.y += r3.h;

    
    GR.dropdown(r3, LUT_name_list, *g_current_lut_texture_index, *theme_ptr.dropdown_theme);

    autoedit(r2, *current_post_process, *theme_ptr);
}

#scope_export

draw_texture_debug :: () {
}

toggle_texdebug :: () {
    subwindow.open = !subwindow.open;
} @Command

toggle_pp :: () {
    pp_subwindow.open = !pp_subwindow.open;
} @Command

toggle_lighting :: () {
    lighting_subwindow.open = !lighting_subwindow.open;
} @Command

draw_postprocess_popup :: (theme: *GR.Overall_Theme) {
    if !pp_subwindow.open then return;
    if !pp_subwindow_initted {
        theme_ptr = theme;
        r := GR.get_rect(ui_w(40, 0), ui_w(40, 0), ui_h(50,0), ui_h(50,0));
        pp_subwindow.rect        = r;
        pp_subwindow.draw        = draw_subwindow_post_process;
        pp_subwindow.title_text  = "Post Process";
        pp_subwindow.open        = false;
        pp_subwindow_initted = true;
    }
    if pp_subwindow.open {  // The Subwindow starts open, but pressing the Close button can close it.
        pp_subwindow_state := GR.add_subwindow(*pp_subwindow, *theme.subwindow_theme);
    }
}

draw_lighting_popup :: (theme: *GR.Overall_Theme) {
    if !lighting_subwindow.open then return;
    if !lighting_subwindow_initted {
        theme_ptr = theme;
        r := GR.get_rect(ui_w(55, 0), ui_w(40, 0), ui_h(50,0), ui_h(40,0));
        lighting_subwindow.rect       = r;
        lighting_subwindow.draw       = draw_subwindow_lighting;
        lighting_subwindow.title_text = "Lighting";
        lighting_subwindow.open       = false;
        lighting_subwindow_initted = true;
    }
    if lighting_subwindow.open {
        GR.add_subwindow(*lighting_subwindow, *theme.subwindow_theme);
    }
}

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
