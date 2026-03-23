#scope_file

Random :: #import "Random";

TRANSITION_SPEED :: 7.0;
MAX_BLOBS :: 32;

Settings_Page :: enum {
    MAIN;
    SETTINGS;
    AUDIO;
}

Settings_State :: struct {
    open       : bool          = false;
    transition : float         = 0.0;
    page       : Settings_Page = .MAIN;
    cursor     : s32           = 0;
    title_font : *Font;
    item_font  : *Font;

    blobs      : [MAX_BLOBS]Blob;
    blob_count : s32 = 0;
}

Blob :: struct {
    cx     : float;
    cy     : float;
    radius : float;
    r, g, b: float;
    freq   : float;
    drift_x: float;
    drift_y: float;
    phase  : float;
}

g_settings : Settings_State;
g_settings_config : Settings_Menu_Config;

MAIN_ITEMS     :: string.["Resume", "Settings", "Exit"];
SETTINGS_ITEMS :: string.["Audio"];
AUDIO_LABELS   :: string.["Master Volume", "Music Volume", "Sound Effects"];

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

page_count :: () -> s32 {
    if g_settings.page == .MAIN     return MAIN_ITEMS.count;
    if g_settings.page == .SETTINGS return SETTINGS_ITEMS.count;
    if g_settings.page == .AUDIO    return AUDIO_LABELS.count;
    return 0;
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

        blob.cx     = rand_range(0.05, 0.95);
        blob.cy     = rand_range(0.15, 0.85);
        blob.radius = rand_range(cfg.radius_min, cfg.radius_max);
        blob.freq   = rand_range(cfg.freq_min, cfg.freq_max);
        blob.drift_x = rand_range(cfg.drift_min, cfg.drift_max);
        blob.drift_y = rand_range(cfg.drift_min, cfg.drift_max);
        blob.phase  = rand_range(0.0, 6.28);

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
    game_title      : string           = "TRUENO";
    credits         : string           = "Trueno engine by Tuomas Katajisto 2026";
    bg_color        : Vector4          = .{0.04, 0.04, 0.06, 1.0};
    title_color     : Vector4          = .{1.0, 1.0, 1.0, 1.0};
    item_color      : Vector4          = .{0.45, 0.45, 0.45, 1.0};
    selected_color  : Vector4          = .{1.0, 0.95, 0.65, 1.0};
    hint_color      : Vector4          = .{0.45, 0.45, 0.45, 1.0};
    credits_color   : Vector4          = .{0.3, 0.3, 0.3, 1.0};
    phosphenes      : Phosphene_Config;
}

set_settings_config :: (config: Settings_Menu_Config) {
    g_settings_config = config;
}

settings_menu_blocks_game :: () -> bool {
    return g_settings.open;
}

init_settings_menu :: () {
    // TODO: scale font sizes with screen resolution
    g_settings.title_font = get_font_at_size(60);
    g_settings.item_font  = get_font_at_size(30);
}

tick_settings_menu :: () {
    if in_editor_view then return;

    if is_action_start(Editor_Action.TOGGLE_SETTINGS) {
        if !g_settings.open {
            g_settings.open   = true;
            g_settings.page   = .MAIN;
            g_settings.cursor = 0;
            generate_blobs();
        } else if g_settings.page == .AUDIO {
            g_settings.page   = .SETTINGS;
            g_settings.cursor = 0;
        } else if g_settings.page == .SETTINGS {
            g_settings.page   = .MAIN;
            g_settings.cursor = 0;
        } else {
            g_settings.open = false;
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

    count := page_count();

    up    := cast(bool)(input_button_states[Key_Code.ARROW_UP]   & .START);
    down  := cast(bool)(input_button_states[Key_Code.ARROW_DOWN] & .START);
    left  := cast(bool)(input_button_states[Key_Code.ARROW_LEFT] & .START);
    right := cast(bool)(input_button_states[Key_Code.ARROW_RIGHT]& .START);
    enter := cast(bool)(input_button_states[Key_Code.ENTER]      & .START);

    if up   then g_settings.cursor = (g_settings.cursor - 1 + count) % count;
    if down then g_settings.cursor = (g_settings.cursor + 1) % count;

    if g_settings.page == .MAIN && enter {
        if g_settings.cursor == 0 {
            // Resume
            g_settings.open = false;
        } else if g_settings.cursor == 1 {
            // Settings
            g_settings.page   = .SETTINGS;
            g_settings.cursor = 0;
        } else if g_settings.cursor == 2 {
            // Exit
            sapp_request_quit();
        }
    } else if g_settings.page == .SETTINGS && enter {
        if g_settings.cursor == 0 {
            g_settings.page   = .AUDIO;
            g_settings.cursor = 0;
        }
    }

    if g_settings.page == .AUDIO {
        delta : float = 0.0;
        if left  then delta = -0.1;
        if right then delta =  0.1;
        if delta != 0.0 then audio_set(g_settings.cursor, audio_get(g_settings.cursor) + delta);
    }
}

draw_settings_menu :: (theme: *GR.Overall_Theme) {
    t := g_settings.transition;
    if t < 0.001 then return;

    fw     := vw * 100.0;
    fh     := vh * 100.0;
    half_h := fh * 0.5;
    bar_h  := t * half_h;

    cfg := *g_settings_config;
    bg := cfg.bg_color;
    set_shader_for_color();

    immediate_quad(.{0, 0},        .{fw, 0},        .{fw, bar_h},    .{0, bar_h},    bg);
    immediate_flush();

    bottom_y := fh - bar_h;
    immediate_quad(.{0, bottom_y}, .{fw, bottom_y}, .{fw, fh},       .{0, fh},       bg);
    immediate_flush();

    if t > 0.5 {
        phosphene_fade := clamp((t - 0.5) / 0.5, 0.0, 1.0);
        time := cast(float) get_time();
        draw_phosphenes(fw, fh, bar_h, bottom_y, time, phosphene_fade);
    }

    content_alpha := clamp((t - 0.75) / 0.25, 0.0, 1.0);
    if content_alpha < 0.01 then return;

    apply_alpha :: (base: Vector4, a: float) -> Vector4 {
        return .{base.x, base.y, base.z, base.w * a};
    }

    title_col    := apply_alpha(cfg.title_color, content_alpha);
    item_col     := apply_alpha(cfg.item_color, content_alpha);
    sel_col      := apply_alpha(cfg.selected_color, content_alpha);
    hint_col     := apply_alpha(cfg.hint_color, content_alpha);
    credits_col  := apply_alpha(cfg.credits_color, content_alpha);

    prepare_text(g_settings.title_font, cfg.game_title);
    title_x := (fw - cast(float) gPreppedTextWidth) * 0.5;
    draw_prepared_text(g_settings.title_font, xx title_x, xx (fh * 0.22), title_col);

    item_h := cast(float)(g_settings.item_font.character_height) * 1.7;

    if g_settings.page == .MAIN {
        draw_item_list(MAIN_ITEMS, item_h, fw, fh, item_col, sel_col);
        draw_hint("Up/Down navigate   Enter select", fw, fh, hint_col);

        if cfg.credits.count > 0 {
            prepare_text(g_settings.item_font, cfg.credits);
            cx := (fw - cast(float) gPreppedTextWidth) * 0.5;
            draw_prepared_text(g_settings.item_font, xx cx, xx (fh * 0.92), credits_col);
        }

    } else if g_settings.page == .SETTINGS {
        draw_item_list(SETTINGS_ITEMS, item_h, fw, fh, item_col, sel_col);
        draw_hint("Up/Down navigate   Enter select   Esc back", fw, fh, hint_col);

    } else if g_settings.page == .AUDIO {
        total_h := AUDIO_LABELS.count * item_h;
        start_y := fh * 0.5 - total_h * 0.5;
        for i: 0..AUDIO_LABELS.count-1 {
            col  := ifx cast(s32)i == g_settings.cursor then sel_col else item_col;
            pct  := cast(s32)(audio_get(cast(s32)i) * 100.0 + 0.5);
            bar  := make_volume_bar(pct, cast(s32)i == g_settings.cursor);
            label := tprint("%    %", AUDIO_LABELS[i], bar);
            prepare_text(g_settings.item_font, label);
            x := (fw - cast(float) gPreppedTextWidth) * 0.5;
            draw_prepared_text(g_settings.item_font, xx x, xx (start_y + cast(float)i * item_h), col);
        }
        draw_hint("Up/Down navigate   Left/Right adjust   Esc back", fw, fh, hint_col);
    }
}

#scope_file

draw_item_list :: (items: []string, item_h: float, fw: float, fh: float, item_col: Vector4, sel_col: Vector4) {
    total_h := items.count * item_h;
    start_y := fh * 0.5 - total_h * 0.5;
    for i: 0..items.count-1 {
        col := ifx cast(s32)i == g_settings.cursor then sel_col else item_col;
        prepare_text(g_settings.item_font, items[i]);
        x := (fw - cast(float) gPreppedTextWidth) * 0.5;
        draw_prepared_text(g_settings.item_font, xx x, xx (start_y + cast(float)i * item_h), col);
    }
}

draw_hint :: (text: string, fw: float, fh: float, color: Vector4) {
    prepare_text(g_settings.item_font, text);
    hint_x := (fw - cast(float) gPreppedTextWidth) * 0.5;
    draw_prepared_text(g_settings.item_font, xx hint_x, xx (fh * 0.82), color);
}

draw_phosphenes :: (fw: float, fh: float, bar_h: float, bottom_y: float, time: float, fade: float) {
    if g_settings.blob_count < 1 then return;

    set_shader_for_color();

    max_alpha  := g_settings_config.phosphenes.alpha;
    num_layers := g_settings_config.phosphenes.layers;
    if num_layers < 1 then num_layers = 4;

    for i: 0..g_settings.blob_count-1 {
        blob := g_settings.blobs[i];

        // Smooth, gentle pulse — stays in 0.6..1.0 range to avoid harsh pop
        pulse := 0.5 + 0.5 * sin(time * blob.freq * 6.28 + blob.phase);
        alpha := fade * max_alpha * (0.6 + 0.4 * pulse);

        cx := (blob.cx + sin(time * 0.3 + blob.phase) * blob.drift_x) * fw;
        cy := (blob.cy + cos(time * 0.2 + blob.phase * 1.3) * blob.drift_y) * fh;

        blob_r := blob.radius * fh;

        // Draw concentric layers for soft falloff
        for li: 0..num_layers-1 {
            frac := cast(float)(num_layers - li) / cast(float)num_layers;
            r := blob_r * frac;
            layer_alpha := alpha * (1.0 - frac * 0.7);
            col := Vector4.{blob.r, blob.g, blob.b, layer_alpha};
            immediate_quad(
                .{cx - r, cy - r},
                .{cx + r, cy - r},
                .{cx + r, cy + r},
                .{cx - r, cy + r},
                col
            );
        }
    }
    immediate_flush();
}

make_volume_bar :: (pct: s32, active: bool) -> string {
    STEPS :: 10;
    filled := (pct + 5) / STEPS;
    builder : String_Builder;
    append(*builder, "[ ");
    for i: 0..STEPS-1 {
        if i < filled then append(*builder, "=");
        else               append(*builder, "-");
    }
    append(*builder, tprint(" %\%%", pct));
    append(*builder, " ]");
    return builder_to_string(*builder,, allocator = temp);
}
