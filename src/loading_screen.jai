Loading_Screen_Config :: struct {
    loading_text : string = "LOADING";
}

loading_screen_config : Loading_Screen_Config;

#scope_file

Loading_Screen_State :: struct {
    font          : *Font;
    last_screen_h : s32;
}

ls_state : Loading_Screen_State;

update_font :: () {
    _, h := get_window_size();
    if h == ls_state.last_screen_h then return;
    ls_state.last_screen_h = h;
    ls_state.font = get_font_at_size(max(cast(s32)(cast(float)h * 0.055), 20));
}

#scope_export

set_loading_screen_config :: (config: Loading_Screen_Config) {
    loading_screen_config = config;
}

draw_loading_screen :: () {
    update_font();

    w, h := get_window_size();
    fw := cast(float) w;
    fh := cast(float) h;
    vc := g_voxel_theme_config;
    t  := cast(float) get_time();

    set_shader_for_color();
    immediate_quad(.{0, 0}, .{fw, 0}, .{fw, fh}, .{0, fh}, vc.bg_color);
    immediate_flush();

    bar_w  := fw * 0.3;
    bar_h  := max(2.0, fh * 0.007);
    bar_x  := (fw - bar_w) * 0.5;
    bar_y  := fh * 0.62;

    track_col := Vector4.{vc.bg_color.x + 0.06, vc.bg_color.y + 0.06, vc.bg_color.z + 0.08, 1.0};
    immediate_quad(.{bar_x, bar_y}, .{bar_x + bar_w, bar_y},
                   .{bar_x + bar_w, bar_y + bar_h}, .{bar_x, bar_y + bar_h}, track_col);

    sweep := (sin(t * 1.8) + 1.0) * 0.5;
    seg_w := bar_w * 0.35;
    seg_x := bar_x + sweep * (bar_w - seg_w);
    immediate_quad(.{seg_x, bar_y}, .{seg_x + seg_w, bar_y},
                   .{seg_x + seg_w, bar_y + bar_h}, .{seg_x, bar_y + bar_h}, vc.primary_color);
    immediate_flush();

    if ls_state.font {
        prepare_text(ls_state.font, loading_screen_config.loading_text);
        draw_prepared_text(ls_state.font,
            xx ((fw - cast(float)gPreppedTextWidth) * 0.5),
            xx (fh * 0.52),
            vc.primary_color);
    }
}
