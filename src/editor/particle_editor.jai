#scope_file

pe_selected_index : s32 = -1;
pe_preview_emitter : Particle_Emitter_Instance;

pe_cam : Camera = .{
    far = 2000.0,
    near = 1.0,
    target = .{0, 1, 0},
    position = .{5, 3, 0},
};

pe_scroll : float = 0;

pe_name_input_start : string = "";
pe_anim_input_start : string = "";

pe_label :: (r: *GR.Rect, text: string, theme: *GR.Overall_Theme) {
    GR.label(r.*, text, *t_label_left(theme));
    r.y += r.h;
}

pe_float :: (r: *GR.Rect, label: string, value: *float, lo: float, hi: float, step: float, theme: *GR.Overall_Theme, loc := #caller_location) {
    GR.label(r.*, label, *t_label_left(theme));
    r.y += r.h;
    GR.slider(r.*, value, lo, hi, step, *theme.slider_theme, loc = loc);
    r.y += r.h;
}

pe_vec3 :: (r: *GR.Rect, label: string, value: *Vector3, lo: float, hi: float, theme: *GR.Overall_Theme, loc := #caller_location) {
    number_theme : GR.Number_Input_Theme;
    GR.label(r.*, label, *t_label_left(theme));
    r.y += r.h;
    orig_w := r.w;
    orig_x := r.x;
    r.w = orig_w / 3;
    GR.number_input(r.*, tprint("%", value.x), *value.x, lo, hi, *number_theme, 0, loc);
    r.x += r.w;
    GR.number_input(r.*, tprint("%", value.y), *value.y, lo, hi, *number_theme, 1, loc);
    r.x += r.w;
    GR.number_input(r.*, tprint("%", value.z), *value.z, lo, hi, *number_theme, 2, loc);
    r.x = orig_x;
    r.w = orig_w;
    r.y += r.h;
}

pe_vec4 :: (r: *GR.Rect, label: string, value: *Vector4, lo: float, hi: float, theme: *GR.Overall_Theme, loc := #caller_location) {
    number_theme : GR.Number_Input_Theme;
    GR.label(r.*, label, *t_label_left(theme));
    r.y += r.h;
    orig_w := r.w;
    orig_x := r.x;
    r.w = orig_w / 4;
    GR.number_input(r.*, tprint("%", value.x), *value.x, lo, hi, *number_theme, 0, loc);
    r.x += r.w;
    GR.number_input(r.*, tprint("%", value.y), *value.y, lo, hi, *number_theme, 1, loc);
    r.x += r.w;
    GR.number_input(r.*, tprint("%", value.z), *value.z, lo, hi, *number_theme, 2, loc);
    r.x += r.w;
    GR.number_input(r.*, tprint("%", value.w), *value.w, lo, hi, *number_theme, 3, loc);
    r.x = orig_x;
    r.w = orig_w;
    r.y += r.h;
}

#scope_export

draw_particle_editor_ui :: (theme: *GR.Overall_Theme) {
    panel_w := ui_w(20, 20);
    row_h := ui_h(3, 0);

    list_r := GR.get_rect(ui_w(80, 20), ui_h(5,0), panel_w, ui_h(95, 0));
    ui_add_mouse_occluder(list_r);
    draw_bg_rectangle(list_r, theme);

    r := list_r;
    r.h = row_h;

    if GR.button(r, "New Emitter", *theme.button_theme) {
        def : Particle_Emitter_Config;
        def.name = sprint("emitter_%", g_emitter_defs.count);
        array_add(*g_emitter_defs, def);
        pe_selected_index = cast(s32)(g_emitter_defs.count - 1);
    }
    r.y += r.h;

    for def, idx : g_emitter_defs {
        if r.y > list_r.y + list_r.h - row_h * 3 then break;
        selected := (cast(s32)idx == pe_selected_index);
        if GR.button(r, def.name, *t_button_selectable(theme, selected), cast(s32)idx) {
            pe_selected_index = cast(s32)idx;
            pe_name_input_start = def.name;
            pe_anim_input_start = def.animation_name;
        }
        r.y += r.h;
    }

    r.y = list_r.y + list_r.h - row_h * 2;
    half_w := r.w / 2;
    orig_w := r.w;
    r.w = half_w;
    if keybind_button(r, "Save", .SAVE, *theme.button_theme) {
        save_particle_defs();
    }
    r.x += half_w;
    if GR.button(r, "Delete", *theme.button_theme) {
        if pe_selected_index >= 0 && pe_selected_index < cast(s32)g_emitter_defs.count {
            array_ordered_remove_by_index(*g_emitter_defs, pe_selected_index);
            if pe_selected_index >= cast(s32)g_emitter_defs.count then pe_selected_index -= 1;
        }
    }
    r.w = orig_w;

    if pe_selected_index < 0 || pe_selected_index >= cast(s32)g_emitter_defs.count then return;

    def := *g_emitter_defs[pe_selected_index];

    edit_r := GR.get_rect(0, ui_h(5,0), panel_w, ui_h(95, 0));
    ui_add_mouse_occluder(edit_r);
    draw_bg_rectangle(edit_r, theme);

    region, inside := GR.begin_scrollable_region(edit_r, *theme.scrollable_region_theme);
    er := inside;
    er.y -= pe_scroll;
    er.h = row_h;

    pe_label(*er, "Name", theme);
    a, new_name, _ := GR.text_input(er, pe_name_input_start, *theme.text_input_theme, 0);
    if a & .ENTERED {
        def.name = copy_string(new_name);
        pe_name_input_start = def.name;
    }
    er.y += er.h;

    pe_label(*er, "Animation", theme);
    a2, new_anim, _ := GR.text_input(er, pe_anim_input_start, *theme.text_input_theme, 1);
    if a2 & .ENTERED {
        def.animation_name = copy_string(new_anim);
        pe_anim_input_start = def.animation_name;
    }
    er.y += er.h;

    pe_float(*er, tprint("Emission Rate: %", def.emission_rate), *def.emission_rate, 0, 200, 1, theme);
    pe_float(*er, tprint("Lifetime Min: %", def.lifetime_min), *def.lifetime_min, 0, 10, 0.1, theme);
    pe_float(*er, tprint("Lifetime Max: %", def.lifetime_max), *def.lifetime_max, 0, 10, 0.1, theme);
    pe_vec3(*er, "Velocity", *def.velocity, -50, 50, theme);
    pe_vec3(*er, "Velocity Spread", *def.velocity_spread, 0, 50, theme);
    pe_vec3(*er, "Position Spread", *def.position_spread, 0, 10, theme);
    pe_float(*er, tprint("Size Start: %", def.size_start), *def.size_start, 0, 10, 0.05, theme);
    pe_float(*er, tprint("Size End: %", def.size_end), *def.size_end, 0, 10, 0.05, theme);
    pe_vec4(*er, "Color Start", *def.color_start, 0, 1, theme);
    pe_vec4(*er, "Color End", *def.color_end, 0, 1, theme);
    pe_float(*er, tprint("Gravity: %", def.gravity), *def.gravity, -20, 20, 0.1, theme);

    pe_label(*er, tprint("Blend Mode: %", def.blend_mode), theme);
    orig_w2 := er.w;
    er.w = orig_w2 / 2;
    if GR.button(er, "Additive", *t_button_selectable(theme, def.blend_mode == .ADDITIVE), 100) then def.blend_mode = .ADDITIVE;
    er.x += er.w;
    if GR.button(er, "Alpha", *t_button_selectable(theme, def.blend_mode == .ALPHA), 101) then def.blend_mode = .ALPHA;
    er.x -= er.w;
    er.w = orig_w2;
    er.y += er.h;

    er.y += er.h;

    alive_count : s32 = 0;
    for p : g_particles {
        if p.alive then alive_count += 1;
    }
    pe_label(*er, tprint("Alive particles: %", alive_count), theme);
    pe_label(*er, tprint("Emitter defs: %", g_emitter_defs.count), theme);
    pe_label(*er, tprint("Preview active: %", pe_preview_emitter.active), theme);
    pe_label(*er, tprint("Preview def: %", pe_preview_emitter.definition != null), theme);
    anim := get_animation_from_string(def.animation_name);
    if anim != null {
        pe_label(*er, tprint("Animation: % frames", anim.frames.count), theme);
    } else {
        pe_label(*er, tprint("Animation: not found ('%')", def.animation_name), theme);
    }
    pe_label(*er, tprint("Spawn accum: %", pe_preview_emitter.spawn_accumulator), theme);

    GR.end_scrollable_region(region, er.x + er.w, er.y, *pe_scroll);
}

draw_particle_editor :: () {
    create_set_cam_rendering_task(pe_cam, 0.0);

    if pe_selected_index >= 0 && pe_selected_index < cast(s32)g_emitter_defs.count {
        def := *g_emitter_defs[pe_selected_index];
        pe_preview_emitter.definition = def;
        pe_preview_emitter.position = .{0, 1, 0};
        pe_preview_emitter.active = true;
        tick_emitter_instance(*pe_preview_emitter, cast(float)delta_time);
    }
}

tick_particle_editor :: () {
    tick_particles_physics(cast(float)delta_time);
}
