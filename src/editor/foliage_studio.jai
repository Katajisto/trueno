#scope_file

fs_selected_index : s32 = -1;
fs_scroll         : float = 0;

fs_name_input_start : string = "";
fs_anim_input_start : string = "";

fs_label :: (r: *GR.Rect, text: string, theme: *GR.Overall_Theme) {
    GR.label(r.*, text, *t_label_left(theme));
    r.y += r.h;
}

fs_float :: (r: *GR.Rect, label: string, value: *float, lo: float, hi: float, step: float, theme: *GR.Overall_Theme, loc := #caller_location) {
    GR.label(r.*, label, *t_label_left(theme));
    r.y += r.h;
    GR.slider(r.*, value, lo, hi, step, *theme.slider_theme, loc = loc);
    r.y += r.h;
}

fs_select_def :: (idx: s32) {
    fs_selected_index = idx;
    if idx >= 0 && idx < cast(s32) g_foliage_defs.count {
        fs_name_input_start = g_foliage_defs[idx].name;
        fs_anim_input_start = g_foliage_defs[idx].animation_name;
    }
}

#scope_export

draw_foliage_studio_ui :: (theme: *GR.Overall_Theme) {
    panel_w := ui_w(20, 20);
    row_h := ui_h(3, 0);

    list_r := GR.get_rect(ui_w(80, 20), ui_h(5,0), panel_w, ui_h(95, 0));
    ui_add_mouse_occluder(list_r);
    draw_bg_rectangle(list_r, theme);

    r := list_r;
    r.h = row_h;

    half_w := r.w / 2;
    orig_w := r.w;
    r.w = half_w;
    if GR.button(r, "New", *theme.button_theme) {
        def : Foliage_Def;
        def.name = sprint("foliage_%", g_foliage_defs.count);
        array_add(*g_foliage_defs, def);
        fs_select_def(cast(s32)(g_foliage_defs.count - 1));
    }
    r.x += half_w;
    if GR.button(r, "Duplicate", *theme.button_theme) {
        if fs_selected_index >= 0 && fs_selected_index < cast(s32) g_foliage_defs.count {
            def := g_foliage_defs[fs_selected_index];
            def.name = sprint("%_copy", def.name);
            def.animation_name = copy_string(def.animation_name);
            array_add(*g_foliage_defs, def);
            fs_select_def(cast(s32)(g_foliage_defs.count - 1));
        }
    }
    r.x -= half_w;
    r.w = orig_w;
    r.y += r.h;

    for def, idx : g_foliage_defs {
        if r.y > list_r.y + list_r.h - row_h * 3 then break;
        selected := (cast(s32)idx == fs_selected_index);
        if GR.button(r, def.name, *t_button_selectable(theme, selected), cast(s32)idx) {
            fs_select_def(cast(s32)idx);
        }
        r.y += r.h;
    }

    r.y = list_r.y + list_r.h - row_h * 2;
    r.w = half_w;
    if keybind_button(r, "Save", .SAVE, *theme.button_theme) {
        save_foliage_defs();
    }
    r.x += half_w;
    if GR.button(r, "Delete", *theme.button_theme) {
        if fs_selected_index >= 0 && fs_selected_index < cast(s32) g_foliage_defs.count {
            array_ordered_remove_by_index(*g_foliage_defs, fs_selected_index);
            if fs_selected_index >= cast(s32) g_foliage_defs.count then fs_selected_index -= 1;
            fs_select_def(fs_selected_index);
        }
    }
    r.w = orig_w;

    if fs_selected_index < 0 || fs_selected_index >= cast(s32) g_foliage_defs.count then return;

    def := *g_foliage_defs[fs_selected_index];

    edit_r := GR.get_rect(0, ui_h(5,0), panel_w, ui_h(95, 0));
    ui_add_mouse_occluder(edit_r);
    draw_bg_rectangle(edit_r, theme);

    region, inside := GR.begin_scrollable_region(edit_r, *theme.scrollable_region_theme);
    er := inside;
    er.y -= fs_scroll;
    er.h = row_h;

    fs_label(*er, "Name", theme);
    a, new_name, _ := GR.text_input(er, fs_name_input_start, *theme.text_input_theme, 0);
    if a & .ENTERED {
        def.name = copy_string(new_name);
        fs_name_input_start = def.name;
    }
    er.y += er.h;

    fs_label(*er, "Animation (pack.anim)", theme);
    a2, new_anim, _ := GR.text_input(er, fs_anim_input_start, *theme.text_input_theme, 1);
    if a2 & .ENTERED {
        def.animation_name = copy_string(new_anim);
        fs_anim_input_start = def.animation_name;
    }
    er.y += er.h;

    anim := get_animation_from_string(def.animation_name);
    if anim != null {
        fs_label(*er, tprint("Animation: % frames", anim.frames.count), theme);
    } else {
        fs_label(*er, tprint("Animation: not found ('%')", def.animation_name), theme);
    }

    orig_w2 := er.w;
    er.w = orig_w2 / 2;

    fs_label(*er, "Type", theme);
    if GR.button(er, "Grass", *t_button_selectable(theme, def.type == .GRASS), 100) then def.type = .GRASS;
    er.x += er.w;
    if GR.button(er, "Tree",  *t_button_selectable(theme, def.type == .TREE),  101) then def.type = .TREE;
    er.x -= er.w;
    er.y += er.h;

    fs_label(*er, "Frames", theme);
    if GR.button(er, "Variant", *t_button_selectable(theme, def.frame_mode == .VARIANT), 102) then def.frame_mode = .VARIANT;
    er.x += er.w;
    if GR.button(er, "Loop",    *t_button_selectable(theme, def.frame_mode == .LOOP),    103) then def.frame_mode = .LOOP;
    er.x -= er.w;
    er.y += er.h;

    er.w = orig_w2;

    if def.type == .GRASS {
        fs_float(*er, tprint("Density: %", def.density), *def.density, 0, 1, 0.05, theme);
        fs_float(*er, tprint("Jitter: %", def.jitter), *def.jitter, 0, 0.5, 0.05, theme);
    }
    fs_float(*er, tprint("Scale Min: %", def.scale_min), *def.scale_min, 0.1, 4, 0.05, theme);
    fs_float(*er, tprint("Scale Max: %", def.scale_max), *def.scale_max, 0.1, 4, 0.05, theme);
    if def.scale_max < def.scale_min then def.scale_max = def.scale_min;
    fs_float(*er, tprint("Sway Intensity: %", def.sway_intensity), *def.sway_intensity, 0, 1, 0.05, theme);
    fs_float(*er, tprint("Sway Speed: %", def.sway_speed), *def.sway_speed, 0, 5, 0.1, theme);

    GR.end_scrollable_region(region, er.x + er.w, er.y, *fs_scroll);
}
