#scope_file

Picker :: enum {
    TRILE;
    WORLD;
}

current_picker      : Picker = .TRILE;
trile_search_text   : string;
trile_picker_scroll : float;

draw_trile_picker :: (r_in: GR.Rect, theme: *GR.Overall_Theme) {
    r := r_in;

    row_h   := ui_h(4, 4);
    clear_w := ui_w(3, 3);

    search_r   := r;
    search_r.h  = row_h;
    search_r.w  = r.w - clear_w;
    _, __, text_state := GR.text_input(search_r, trile_search_text, *theme.text_input_theme, 128);

    clear_r  := r;
    clear_r.h = row_h;
    clear_r.x = r.x + r.w - clear_w;
    clear_r.w = clear_w;
    if GR.button(clear_r, "x", *theme.button_theme) {
        if trile_search_text.data  free(trile_search_text);
        trile_search_text = .{};
        if text_state  GR.set_input(text_state, "");
    }

    r.y += row_h;
    r.h -= row_h;

    current_search := ifx text_state then text_state.text else trile_search_text;

    tpt := get_trile_table_ptr();

    filtered : [..] string;
    filtered.allocator = temp;
    for v : tpt {
        if !current_search.count || contains(v.name, current_search) {
            array_add(*filtered, v.name);
        }
    }

    padding : float = 3.0;
    name_h  := ui_h(1, 2);
    cols    : int = 3;

    btn_theme := theme.button_theme;
    btn_theme.surface_color       = .{0, 0, 0, 0};
    btn_theme.surface_color_over  = .{1, 1, 1, 0.15};
    btn_theme.surface_color_down  = .{1, 1, 1, 0.25};
    btn_theme.surface_color_flash = .{1, 1, 1, 0.15};
    btn_theme.frame_color         = .{0, 0, 0, 0};
    btn_theme.frame_color_over    = .{0, 0, 0, 0};
    btn_theme.frame_color_down    = .{0, 0, 0, 0};
    btn_theme.frame_color_flash   = .{0, 0, 0, 0};

    atlas_valid := g_thumbnail_atlas.tex.id != INVALID_ID;

    region, inside := GR.begin_scrollable_region(r, *theme.scrollable_region_theme);

    cell_w  := inside.w / cast(float)cols;
    thumb_h := cell_w - padding * 2.0;
    cell_h  := thumb_h + name_h + padding;

    row_count := (filtered.count + cols - 1) / cols;
    total_h   := cast(float)row_count * cell_h;

    for idx : 0..filtered.count-1 {
        name := filtered[idx];
        col  := idx % cols;
        row  := idx / cols;

        cx := inside.x + cast(float)col * cell_w;
        cy := inside.y - trile_picker_scroll + cast(float)row * cell_h;

        thumb_r := GR.Rect.{cx + padding, cy, cell_w - padding * 2.0, thumb_h};
        label_r := GR.Rect.{cx + padding, cy + thumb_h, cell_w - padding * 2.0, name_h};
        cell_r  := GR.Rect.{cx, cy, cell_w, cell_h};

        if atlas_valid {
            uv_min, uv_max, uv_found := get_thumbnail_uv(name);
            if uv_found {
                set_shader_for_images(*g_thumbnail_atlas);
                immediate_quad(
                    .{thumb_r.x,              thumb_r.y},
                    .{thumb_r.x + thumb_r.w,  thumb_r.y},
                    .{thumb_r.x + thumb_r.w,  thumb_r.y + thumb_r.h},
                    .{thumb_r.x,              thumb_r.y + thumb_r.h},
                    .{1, 1, 1, 1},
                    .{uv_min.x, uv_min.y}, .{uv_max.x, uv_min.y},
                    .{uv_max.x, uv_max.y}, .{uv_min.x, uv_max.y}
                );
                set_shader_for_color();
            }
        }

        is_selected := editor_current_trile != null && editor_current_trile.name == name;
        if is_selected {
            draw_rectangle(thumb_r, .{0.3, 0.5, 1.0, 0.35});
        }

        GR.label(label_r, name, *t_label_center(theme));

        if GR.button(cell_r, "", *btn_theme, cast(s32)idx) {
            editor_current_trile = get_trile(name);
        }
    }

    GR.end_scrollable_region(region, inside.x + inside.w, inside.y - trile_picker_scroll + total_h, *trile_picker_scroll);
}

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

    if current_picker == {
        case .TRILE;
            draw_trile_picker(r, theme);
        case .WORLD;
            draw_world_picker(r, theme);
    }
}
