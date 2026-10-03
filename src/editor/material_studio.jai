#scope_file

ms_selected   : u8;
ms_scroll     : float;
ms_name_input : string;

#scope_export

draw_material_studio_ui :: (theme: *GR.Overall_Theme) {
    panel := GR.get_rect(0, ui_h(5,0), ui_w(20, 20), ui_h(95, 0));
    ui_add_mouse_occluder(panel);
    draw_bg_rectangle(panel, theme);
    row_h := ui_h(4, 0);

    r := panel;
    r.h = row_h;
    if GR.button(r, "New material", *theme.button_theme) {
        id, ok := swatch_add("new", u8.[255, 255, 255]);
        if ok {
            ms_selected   = id;
            ms_name_input = copy_string(g_swatches[id].name);
        }
    }
    r.y += row_h;

    // .hex palettes in a pack, one RRGGBB per line.
    for g_palettes {
        if GR.button(r, tprint("Import % (% colours)", it.name, it.entries.count), *theme.button_theme, it_index) {
            log_info("Imported % new materials from %", swatch_import_palette(it), it.name);
        }
        r.y += row_h;
    }

    grid := r;
    grid.h = ui_h(25, 0);
    previous := ms_selected;
    region, inside := GR.begin_scrollable_region(grid, *theme.scrollable_region_theme);
    end_y := draw_swatch_grid(inside, *ms_scroll, *ms_selected, theme);
    GR.end_scrollable_region(region, inside.x + inside.w, end_y, *ms_scroll);
    if ms_selected != previous  ms_name_input = copy_string(g_swatches[ms_selected].name);
    r.y += grid.h + row_h * 0.5;

    if ms_selected == 0 || !g_swatches[ms_selected].used  return;
    swatch := *g_swatches[ms_selected];

    GR.label(r, tprint("Material %", ms_selected), *t_label_left(theme));
    r.y += row_h;
    a, new_text := GR.text_input(r, ms_name_input, *theme.text_input_theme, 128);
    if a & .ENTERED {
        ms_name_input = copy_string(new_text);
        swatch.name   = copy_string(new_text);
    }
    r.y += row_h;

    r.h = ui_h(3, 2);
    GR.label(r, "Reflectivity", *t_label_left(theme));
    r.y += r.h;
    GR.slider(r, *swatch.reflectivity, 0, 255, 1, *theme.slider_theme);
    r.y += r.h;
    GR.label(r, "Gloss", *t_label_left(theme));
    r.y += r.h;
    GR.slider(r, *swatch.gloss, 0, 255, 1, *theme.slider_theme);
    r.y += r.h;
    GR.label(r, "Emittance", *t_label_left(theme));
    r.y += r.h;
    GR.slider(r, *swatch.emittance, 0, 127, 1, *theme.slider_theme);
    r.y += r.h;
    if GR.base_checkbox(r, "Glass (lets sunlight through)", swatch.glass, *theme.checkbox_theme)  swatch.glass = !swatch.glass;
    r.y += r.h * 2;

    // The colour gets its own panel on the right, so the picker has room.
    color_panel := GR.get_rect(100*vw - panel.w, panel.y, panel.w, ui_h(45, 0));
    ui_add_mouse_occluder(color_panel);
    draw_bg_rectangle(color_panel, theme);
    picker := color_panel;
    picker.h = ui_h(40, 0);
    color := swatch_color(ms_selected);
    GR.color_picker(picker, *color, *theme.color_picker_theme);
    for 0..2  swatch.color[it] = cast(u8) clamp(color.component[it] * 255 + 0.5, 0, 255);
    picker.y += picker.h;
    picker.h  = row_h;
    GR.label(picker, tprint("#%", hex_color(swatch.color)), *t_label_left(theme));

    used_panel := GR.get_rect(color_panel.x, color_panel.y + color_panel.h, color_panel.w, ui_h(45, 0));
    ui_add_mouse_occluder(used_panel);
    draw_bg_rectangle(used_panel, theme);
    line := used_panel;
    line.h = row_h;
    GR.label(line, "Used by", *t_label_left(theme));
    line.y += row_h;
    for trile: get_trile_table_ptr() {
        count := trile_swatch_counts(*trile)[ms_selected];
        if count == 0  continue;
        GR.label(line, tprint("%  (%)", trile.name, count), *t_label_left(theme));
        line.y += row_h;
    }

    swatch_changed(ms_selected);

    r.h = row_h;
    if GR.button(r, "Save", *theme.button_theme) {
        striles();
        for trile: get_trile_table_ptr()  update_trile_thumbnail(trile.name);
    }
    r.y += row_h;

    if swatch_in_use(ms_selected) {
        GR.label(r, "In use, can't delete", *t_label_left(theme));
    } else if GR.button(r, "Delete", *theme.button_theme) {
        swatch.* = .{};
        swatch_changed(ms_selected);
        ms_selected = 0;
    }
}

#scope_file

hex_color :: (c: [3]u8) -> string {
    digits :: "0123456789abcdef";
    out := talloc_string(6);
    for 0..2 {
        out[it * 2]     = digits[c[it] >> 4];
        out[it * 2 + 1] = digits[c[it] & 0xf];
    }
    return out;
}
