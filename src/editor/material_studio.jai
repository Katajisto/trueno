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

    a, new_text := GR.text_input(r, ms_name_input, *theme.text_input_theme, 128);
    if a & .ENTERED {
        ms_name_input = copy_string(new_text);
        swatch.name   = copy_string(new_text);
    }
    r.y += row_h;

    r.h = ui_h(30, 0);
    color := swatch_color(ms_selected);
    GR.color_picker(r, *color, *theme.color_picker_theme);
    for 0..2  swatch.color[it] = cast(u8) clamp(color.component[it] * 255 + 0.5, 0, 255);
    r.y += r.h;

    r.h = ui_h(3, 2);
    GR.label(r, "Roughness", *t_label_left(theme));
    r.y += r.h;
    GR.slider(r, *swatch.roughness, 0, 7, 1, *theme.slider_theme);
    r.y += r.h;
    GR.label(r, "Metallic", *t_label_left(theme));
    r.y += r.h;
    GR.slider(r, *swatch.metallic, 0, 3, 1, *theme.slider_theme);
    r.y += r.h;
    GR.label(r, "Emittance", *t_label_left(theme));
    r.y += r.h;
    GR.slider(r, *swatch.emittance, 0, 127, 1, *theme.slider_theme);
    r.y += r.h * 2;

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
        ms_selected = 0;
    }
}
