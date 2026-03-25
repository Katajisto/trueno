#scope_file

Random :: #import "Random";

TRANSITION_SPEED :: 7.0;
MAX_BLOBS        :: 32;
CONFIG_PATH      :: "settings.cfg";

VOL_STEP_INIT  :: 0.05;
VOL_STEP_HELD  :: 0.25;
VOL_HOLD_DELAY :: 0.4;

Settings_Page :: enum {
    MAIN;
    SETTINGS;
    AUDIO;
    GRAPHICS;
}

Settings_State :: struct {
    open          : bool          = false;
    transition    : float         = 0.0;
    page          : Settings_Page = .MAIN;
    cursor        : s32           = 0;
    title_font    : *Font;
    item_font     : *Font;
    last_screen_h : s32 = 0;

    vol_hold_time : float = 0.0;
    vol_hold_dir  : s32   = 0;

    blobs         : [MAX_BLOBS]Blob;
    blob_count    : s32 = 0;
}

Blob :: struct {
    cx, cy, radius : float;
    r, g, b        : float;
    freq           : float;
    drift_x        : float;
    drift_y        : float;
    phase          : float;
}

g_settings : Settings_State;
g_settings_config : Settings_Menu_Config;

MAIN_ITEMS     :: string.["Resume", "Settings", "Exit"];
SETTINGS_ITEMS :: string.["Audio", "Graphics"];
AUDIO_LABELS   :: string.["Master Volume", "Music Volume", "Sound Effects"];
GRAPHICS_ITEMS :: string.["Fullscreen"];

page_items :: () -> []string {
    if g_settings.page == .MAIN      return MAIN_ITEMS;
    if g_settings.page == .SETTINGS  return SETTINGS_ITEMS;
    if g_settings.page == .AUDIO     return AUDIO_LABELS;
    if g_settings.page == .GRAPHICS  return GRAPHICS_ITEMS;
    return .[];
}

page_parent :: () -> Settings_Page {
    if g_settings.page == .AUDIO     return .SETTINGS;
    if g_settings.page == .GRAPHICS  return .SETTINGS;
    if g_settings.page == .SETTINGS  return .MAIN;
    return .MAIN;
}

page_hint :: () -> string {
    if g_settings.page == .MAIN     return "Up/Down navigate   Enter select";
    if g_settings.page == .SETTINGS return "Up/Down navigate   Enter select   Esc back";
    if g_settings.page == .AUDIO    return "Up/Down navigate   Left/Right or drag to adjust   Esc back";
    if g_settings.page == .GRAPHICS return "Enter toggle   Esc back";
    return "";
}

audio_get :: (i: s32) -> float {
    if i == 0 return g_mixer.config.masterVolume;
    if i == 1 return g_mixer.config.musicVolume;
    if i == 2 return g_mixer.config.soundEffectVolume;
    return 0.0;
}

audio_set :: (i: s32, v: float) {
    if i == 0 then g_mixer.config.masterVolume      = clamp(v, 0.0, 1.0);
    if i == 1 then g_mixer.config.musicVolume       = clamp(v, 0.0, 1.0);
    if i == 2 then g_mixer.config.soundEffectVolume = clamp(v, 0.0, 1.0);
}

rand_range :: (lo: float, hi: float) -> float {
    return lo + Random.random_get_zero_to_one() * (hi - lo);
}

generate_blobs :: () {
    cfg := *g_settings_config.phosphenes;
    count := clamp(cfg.blob_count, 0, MAX_BLOBS);
    g_settings.blob_count = count;

    for i: 0..count-1 {
        blob := *g_settings.blobs[i];
        blob.cx      = rand_range(0.05, 0.95);
        blob.cy      = rand_range(0.15, 0.85);
        blob.radius  = rand_range(cfg.radius_min, cfg.radius_max);
        blob.freq    = rand_range(cfg.freq_min, cfg.freq_max);
        blob.drift_x = rand_range(cfg.drift_min, cfg.drift_max);
        blob.drift_y = rand_range(cfg.drift_min, cfg.drift_max);
        blob.phase   = rand_range(0.0, 6.28);

        if cfg.palette.count > 0 {
            idx := cast(s32)(Random.random_get_zero_to_one() * cast(float)(cfg.palette.count - 1) + 0.5);
            idx = clamp(idx, 0, cast(s32)(cfg.palette.count - 1));
            base := cfg.palette[idx];
            blob.r = clamp(base.x + rand_range(-cfg.color_jitter, cfg.color_jitter), 0.0, 1.0);
            blob.g = clamp(base.y + rand_range(-cfg.color_jitter, cfg.color_jitter), 0.0, 1.0);
            blob.b = clamp(base.z + rand_range(-cfg.color_jitter, cfg.color_jitter), 0.0, 1.0);
        } else {
            blob.r = rand_range(0.1, 0.5);
            blob.g = rand_range(0.1, 0.5);
            blob.b = rand_range(0.1, 0.5);
        }
    }
}

update_fonts_for_screen :: () {
    _, h := get_window_size();
    if h == g_settings.last_screen_h then return;
    g_settings.last_screen_h = h;
    g_settings.title_font = get_font_at_size(max(cast(s32)(cast(float)h * 0.055), 20));
    g_settings.item_font  = get_font_at_size(max(cast(s32)(cast(float)h * 0.028), 14));
}

save_settings :: () {
    file :: #import "File";
    builder : String_Builder;
    append(*builder, tprint("master_volume %\n", g_mixer.config.masterVolume));
    append(*builder, tprint("music_volume %\n", g_mixer.config.musicVolume));
    append(*builder, tprint("sfx_volume %\n", g_mixer.config.soundEffectVolume));
    append(*builder, tprint("fullscreen %\n", cast(s32) sapp_is_fullscreen()));
    file.write_entire_file(CONFIG_PATH, builder_to_string(*builder,, allocator = temp));
}

load_settings :: () {
    file :: #import "File";
    data, ok := file.read_entire_file(CONFIG_PATH,, allocator = temp);
    if !ok then return;

    text := cast(string) data;
    while text.count > 0 {
        line := consume_line(*text);
        if line.count == 0 then continue;
        key, val := split_first(line, #char " ");
        if key == "master_volume" then g_mixer.config.masterVolume      = parse_float(val);
        if key == "music_volume"  then g_mixer.config.musicVolume       = parse_float(val);
        if key == "sfx_volume"    then g_mixer.config.soundEffectVolume = parse_float(val);
        if key == "fullscreen" {
            if (parse_int(val) != 0) != sapp_is_fullscreen() then sapp_toggle_fullscreen();
        }
    }
}

consume_line :: (text: *string) -> string {
    s := text.*;
    for i: 0..s.count-1 {
        if s[i] == #char "\n" {
            line := string.{count = i, data = s.data};
            text.data  += i + 1;
            text.count -= i + 1;
            return line;
        }
    }
    result := s;
    text.count = 0;
    return result;
}

split_first :: (s: string, sep: u8) -> (string, string) {
    for i: 0..s.count-1 {
        if s[i] == sep {
            return string.{count = i, data = s.data},
                   string.{count = s.count - i - 1, data = s.data + i + 1};
        }
    }
    return s, "";
}

parse_float :: (s: string) -> float {
    val, ok := string_to_float(s);
    if ok return val;
    return 0.0;
}

parse_int :: (s: string) -> s64 {
    val, ok := string_to_int(s);
    if ok return val;
    return 0;
}

navigate_to :: (page: Settings_Page) {
    g_settings.page   = page;
    g_settings.cursor = 0;
}

go_back :: () {
    if g_settings.page == .MAIN {
        save_settings();
        g_settings.open = false;
    } else {
        navigate_to(page_parent());
    }
}

handle_enter :: (index: s32 = -1) {
    i := ifx index >= 0 then index else g_settings.cursor;
    if g_settings.page == {
        case .MAIN;
            if i == 0 { save_settings(); g_settings.open = false; }
            if i == 1 then navigate_to(.SETTINGS);
            if i == 2 { save_settings(); sapp_request_quit(); }
        case .SETTINGS;
            if i == 0 then navigate_to(.AUDIO);
            if i == 1 then navigate_to(.GRAPHICS);
        case .GRAPHICS;
            if i == 0 then sapp_toggle_fullscreen();
    }
}

empty_slider_format :: (prefix: string, suffix: string, value: float64, theme: *GR.Slider_Theme, state: *GR.Slider_State, mode: GR.Slider_Format_Text_Mode) -> string {
    return "";
}

#scope_export

Phosphene_Config :: struct {
    blob_count   : s32   = 12;
    alpha        : float = 0.06;
    layers       : s32   = 4;
    radius_min   : float = 0.08;
    radius_max   : float = 0.28;
    freq_min     : float = 0.1;
    freq_max     : float = 0.4;
    drift_min    : float = 0.02;
    drift_max    : float = 0.07;
    color_jitter : float = 0.1;
    palette      : []Vector3;
}

Settings_Menu_Config :: struct {
    game_title  : string           = "TRUENO";
    credits     : string           = "Trueno engine by Tuomas Katajisto 2026";
    phosphenes  : Phosphene_Config;
}

set_settings_config :: (config: Settings_Menu_Config) {
    g_settings_config = config;
}

settings_menu_blocks_game :: () -> bool {
    return g_settings.open;
}

init_settings_menu :: () {
    g_settings.title_font = get_font_at_size(60);
    g_settings.item_font  = get_font_at_size(30);
    load_settings();
}

tick_settings_menu :: () {
    if in_editor_view then return;
    update_fonts_for_screen();

    if is_action_start(Editor_Action.TOGGLE_SETTINGS) {
        if !g_settings.open {
            g_settings.open = true;
            navigate_to(.MAIN);
            generate_blobs();
        } else {
            go_back();
        }
    }

    dt := cast(float) delta_time;
    if g_settings.open {
        g_settings.transition = min(g_settings.transition + TRANSITION_SPEED * dt, 1.0);
    } else {
        g_settings.transition = max(g_settings.transition - TRANSITION_SPEED * dt, 0.0);
    }

    if !g_settings.open then return;
    if console_open_ignore_input then return;

    count := cast(s32) page_items().count;

    up   := cast(bool)(input_button_states[Key_Code.ARROW_UP]   & .START);
    down := cast(bool)(input_button_states[Key_Code.ARROW_DOWN] & .START);
    if up   then g_settings.cursor = (g_settings.cursor - 1 + count) % count;
    if down then g_settings.cursor = (g_settings.cursor + 1) % count;

    enter := cast(bool)(input_button_states[Key_Code.ENTER] & .START);
    if enter then handle_enter();

    if g_settings.page == .AUDIO {
        left       := cast(bool)(input_button_states[Key_Code.ARROW_LEFT]  & .START);
        right      := cast(bool)(input_button_states[Key_Code.ARROW_RIGHT] & .START);
        left_held  := cast(bool)(input_button_states[Key_Code.ARROW_LEFT]  & .DOWN);
        right_held := cast(bool)(input_button_states[Key_Code.ARROW_RIGHT] & .DOWN);

        if left  { audio_set(g_settings.cursor, audio_get(g_settings.cursor) - VOL_STEP_INIT); g_settings.vol_hold_time = 0; g_settings.vol_hold_dir = -1; }
        if right { audio_set(g_settings.cursor, audio_get(g_settings.cursor) + VOL_STEP_INIT); g_settings.vol_hold_time = 0; g_settings.vol_hold_dir =  1; }

        dir : s32 = 0;
        if left_held  then dir = -1;
        if right_held then dir =  1;

        if dir != 0 && dir == g_settings.vol_hold_dir {
            g_settings.vol_hold_time += dt;
            if g_settings.vol_hold_time > VOL_HOLD_DELAY {
                audio_set(g_settings.cursor, audio_get(g_settings.cursor) + cast(float)dir * VOL_STEP_HELD * dt);
            }
        } else if dir == 0 {
            g_settings.vol_hold_time = 0;
            g_settings.vol_hold_dir  = 0;
        }
    }
}

draw_settings_menu :: () {
    t := g_settings.transition;
    if t < 0.001 then return;

    fw    := vw * 100.0;
    fh    := vh * 100.0;
    bar_h := t * fh * 0.5;

    vc  := g_voxel_theme_config;
    cfg := *g_settings_config;

    set_shader_for_color();
    immediate_quad(.{0, 0}, .{fw, 0}, .{fw, bar_h}, .{0, bar_h}, vc.bg_color);
    immediate_flush();
    bottom_y := fh - bar_h;
    immediate_quad(.{0, bottom_y}, .{fw, bottom_y}, .{fw, fh}, .{0, fh}, vc.bg_color);
    immediate_flush();

    if t > 0.5 {
        draw_phosphenes(fw, fh, cast(float) get_time(), clamp((t - 0.5) / 0.5, 0.0, 1.0));
    }

    content_alpha := clamp((t - 0.75) / 0.25, 0.0, 1.0);
    if content_alpha < 0.01 then return;

    apply_alpha :: (base: Vector4, a: float) -> Vector4 {
        return .{base.x, base.y, base.z, base.w * a};
    }

    title_col   := apply_alpha(vc.primary_color, content_alpha);
    hint_col    := apply_alpha(.{vc.text_color.x, vc.text_color.y, vc.text_color.z, 0.6}, content_alpha);
    credits_col := apply_alpha(.{vc.text_color.x, vc.text_color.y, vc.text_color.z, 0.4}, content_alpha);

    prepare_text(g_settings.title_font, cfg.game_title);
    draw_prepared_text(g_settings.title_font, xx ((fw - cast(float)gPreppedTextWidth) * 0.5), xx (fh * 0.22), title_col);

    vt := get_voxel_theme();

    btn_h   := cast(float)(g_settings.item_font.character_height) * 1.8;
    btn_w   := fw * 0.28;
    row_gap := btn_h * 0.25;

    if g_settings.page == .AUDIO {
        lbl_w   := fw * 0.22;
        sld_w   := fw * 0.28;
        col_gap := fw * 0.015;
        sld_h   := btn_h * 0.65;
        row_h   := sld_h + row_gap;
        total_h := cast(float)AUDIO_LABELS.count * row_h - row_gap;
        start_y := fh * 0.48 - total_h * 0.5;
        row_w   := lbl_w + col_gap + sld_w;
        lbl_x   := (fw - row_w) * 0.5;
        sld_x   := lbl_x + lbl_w + col_gap;

        sld_theme := vt.slider_theme;
        sld_theme.foreground.font   = g_settings.item_font;
        sld_theme.format_text_float = empty_slider_format;

        for i: 0..AUDIO_LABELS.count-1 {
            row_y := start_y + cast(float)i * row_h;
            lbl_r := GR.get_rect(lbl_x, row_y, lbl_w, sld_h);
            sld_r := GR.get_rect(sld_x, row_y, sld_w, sld_h);

            is_focused := cast(s32)i == g_settings.cursor;
            lbl_theme := t_label_left(*vt);
            lbl_theme.text_color = apply_alpha(
                ifx is_focused then vc.primary_color else vc.text_color,
                content_alpha
            );
            lbl_theme.font = g_settings.item_font;

            val := audio_get(cast(s32)i);
            pct := cast(s32)(val * 100.0 + 0.5);
            GR.label(lbl_r, tprint("%: %\%", AUDIO_LABELS[i], pct), *lbl_theme);

            changed, _ := GR.slider(sld_r, *val, 0.0, 1.0, VOL_STEP_INIT, *sld_theme,
                                     identifier = cast(s64)i);
            if changed then audio_set(cast(s32)i, val);
        }
    } else {
        items   := page_items();
        total_h := cast(float)items.count * (btn_h + row_gap) - row_gap;
        start_y := fh * 0.48 - total_h * 0.5;
        start_x := (fw - btn_w) * 0.5;

        for i: 0..items.count-1 {
            r := GR.get_rect(start_x, start_y + cast(float)i * (btn_h + row_gap), btn_w, btn_h);

            is_selected := cast(s32)i == g_settings.cursor;
            bt := t_button_ghost(*vt);
            bt.text_color       = apply_alpha(ifx is_selected then vc.primary_color else vc.text_color, content_alpha);
            bt.text_color_over  = apply_alpha(vc.primary_color, content_alpha);
            bt.label_theme.font = g_settings.item_font;
            bt.label_theme.alignment = GR.Text_Alignment.Center;

            label := items[i];
            if g_settings.page == .GRAPHICS && i == 0
                label = tprint("Fullscreen: %", ifx sapp_is_fullscreen() then "On" else "Off");

            pressed, _, _ := GR.button(r, label, *bt, identifier = cast(s64)i);
            if pressed then handle_enter(cast(s32)i);
        }
    }

    draw_centered_text(g_settings.item_font, page_hint(), fw, fh * 0.82, hint_col);

    if g_settings.page == .MAIN && cfg.credits.count > 0 {
        draw_centered_text(g_settings.item_font, cfg.credits, fw, fh * 0.92, credits_col);
    }
}

#scope_file

draw_centered_text :: (font: *Font, text: string, fw: float, y: float, color: Vector4) {
    prepare_text(font, text);
    draw_prepared_text(font, xx ((fw - cast(float)gPreppedTextWidth) * 0.5), xx y, color);
}

draw_phosphenes :: (fw: float, fh: float, time: float, fade: float) {
    if g_settings.blob_count < 1 then return;
    set_shader_for_color();

    max_alpha  := g_settings_config.phosphenes.alpha;
    num_layers := g_settings_config.phosphenes.layers;
    if num_layers < 1 then num_layers = 4;

    for i: 0..g_settings.blob_count-1 {
        blob := g_settings.blobs[i];
        pulse := 0.5 + 0.5 * sin(time * blob.freq * 6.28 + blob.phase);
        alpha := fade * max_alpha * (0.6 + 0.4 * pulse);
        cx := (blob.cx + sin(time * 0.3 + blob.phase) * blob.drift_x) * fw;
        cy := (blob.cy + cos(time * 0.2 + blob.phase * 1.3) * blob.drift_y) * fh;
        blob_r := blob.radius * fh;

        for li: 0..num_layers-1 {
            frac := cast(float)(num_layers - li) / cast(float)num_layers;
            r := blob_r * frac;
            layer_alpha := alpha * (1.0 - frac * 0.7);
            col := Vector4.{blob.r, blob.g, blob.b, layer_alpha};
            immediate_quad(.{cx - r, cy - r}, .{cx + r, cy - r}, .{cx + r, cy + r}, .{cx - r, cy + r}, col);
        }
    }
    immediate_flush();
}
