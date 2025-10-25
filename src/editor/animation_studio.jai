#scope_file

current_sheet : s32 = 0;
current_sheet_last_frame : s32 = -1;
current_sheet_ptr : *Spritesheet;

step_offset_y : s32   = 0;
scale         : float = 5;

#scope_export

tick_animation_studio :: () {
	if input_button_states[Key_Code.ARROW_UP] & .START {
        step_offset_y -= 1;
	}
	if input_button_states[Key_Code.ARROW_DOWN] & .START {
        step_offset_y += 1;
	}

    scale += mouse_delta_z;
    scale = clamp(scale, 1, 10);

}

draw_animation_studio_ui :: (theme: *GR.Overall_Theme) {
    if g_spritesheets.count < 1 then return; 

    r := GR.get_rect(0, ui_h(5,0), ui_w(20, 0), ui_h(95, 0));
	ui_add_mouse_occluder(r);
    draw_bg_rectangle(r, theme);

    sheets : [..]string;
    sheets.allocator = temp;

    for v : g_spritesheets {
        array_add(*sheets, v.name);
    }

    r2 := r;
    r2.h = ui_h(5,0);
    r2.w = r.w;
    GR.dropdown(r2, sheets, *current_sheet, *theme.dropdown_theme);

    if current_sheet != current_sheet_last_frame {
        current_sheet_ptr = table_find_pointer(*g_spritesheets, sheets[current_sheet]);
    }

    number_theme : GR.Number_Input_Theme;

    r2.y += r2.h * 1.1;
    GR.label(r2, "Step X", *theme.label_theme);
    r2.y += r2.h * 1.1;
    GR.number_input(r2, tprint("%", current_sheet_ptr.step_x), *current_sheet_ptr.step_x, 0, 128, *number_theme); 
    r2.y += r2.h * 1.1;
    GR.label(r2, "Step Y", *theme.label_theme);
    r2.y += r2.h * 1.1;
    GR.number_input(r2, tprint("%", current_sheet_ptr.step_y), *current_sheet_ptr.step_y, 0, 128, *number_theme); 
    
    uiTex := New(Ui_Texture ,,temp);
    uiTex.tex = current_sheet_ptr.sheet; 
    if uiTex.tex.id != INVALID_ID {
        menu_offset := Vector2.{ui_w(20,0), ui_h(5,0)};
        zone_r := GR.get_rect(menu_offset.x, menu_offset.y, ui_w(80,0), ui_h(95,0));
        draw_rectangle(zone_r, .{1.0, 0.0, 1.0, 1.0});
    	set_shader_for_images(uiTex);
    
        img_r := zone_r;
        img_r.y -= step_offset_y * cast(s32)current_sheet_ptr.step_y * scale;
        img_r.w = current_sheet_ptr.w * scale;
        img_r.h = current_sheet_ptr.h * scale;
        
        immediate_quad(.{img_r.x, img_r.y}, .{img_r.x + img_r.w, img_r.y}, .{img_r.x + img_r.w, img_r.y + img_r.h}, .{img_r.x, img_r.y + img_r.h});
    	set_shader_for_color();
    }
}
