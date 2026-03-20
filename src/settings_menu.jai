#scope_file

TRANSITION_SPEED :: 3.0;

Settings_Page :: enum {
    MAIN;
    AUDIO;
}

Settings_State :: struct {
    open       : bool          = false;
    transition : float         = 0.0;
    page       : Settings_Page = .MAIN;
    cursor     : s32           = 0;
    title_font : *Font;
    item_font  : *Font;
}

g_settings : Settings_State;

MAIN_ITEMS   :: string.["Audio"];
AUDIO_LABELS :: string.["Master Volume", "Music Volume", "Sound Effects"];

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
    if g_settings.page == .MAIN  return MAIN_ITEMS.count;
    if g_settings.page == .AUDIO return AUDIO_LABELS.count;
    return 0;
}

#scope_export

settings_menu_blocks_game :: () -> bool {
    return g_settings.open;
}

init_settings_menu :: () {
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
        } else if g_settings.page != .MAIN {
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

    bg := Vector4.{0.04, 0.04, 0.06, 1.0};
    set_shader_for_color();

    // Top eyelid sliding down
    immediate_quad(.{0, 0},        .{fw, 0},        .{fw, bar_h},    .{0, bar_h},    bg);
    immediate_flush();

    // Bottom eyelid sliding up
    bottom_y := fh - bar_h;
    immediate_quad(.{0, bottom_y}, .{fw, bottom_y}, .{fw, fh},       .{0, fh},       bg);
    immediate_flush();

    // Content fades in during the last quarter of the transition
    content_alpha := clamp((t - 0.75) / 0.25, 0.0, 1.0);
    if content_alpha < 0.01 then return;

    white    := Vector4.{1.0, 1.0, 1.0,  content_alpha};
    dim      := Vector4.{0.45, 0.45, 0.45, content_alpha};
    selected := Vector4.{1.0, 0.95, 0.65, content_alpha};

    // Game title
    prepare_text(g_settings.title_font, "BEACHBALL");
    title_x := (fw - cast(float) gPreppedTextWidth) * 0.5;
    draw_prepared_text(g_settings.title_font, xx title_x, xx (fh * 0.22), white);

    item_h := cast(float)(g_settings.item_font.character_height) * 1.7;

    if g_settings.page == .MAIN {
        total_h := MAIN_ITEMS.count * item_h;
        start_y := half_h - total_h * 0.5;
        for i: 0..MAIN_ITEMS.count-1 {
            col := ifx cast(s32)i == g_settings.cursor then selected else dim;
            prepare_text(g_settings.item_font, MAIN_ITEMS[i]);
            x := (fw - cast(float) gPreppedTextWidth) * 0.5;
            draw_prepared_text(g_settings.item_font, xx x, xx (start_y + cast(float)i * item_h), col);
        }
        hint_str := "↑↓ navigate   Enter select";
        prepare_text(g_settings.item_font, hint_str);
        hint_x := (fw - cast(float) gPreppedTextWidth) * 0.5;
        draw_prepared_text(g_settings.item_font, xx hint_x, xx (fh * 0.82), dim);

    } else if g_settings.page == .AUDIO {
        total_h := AUDIO_LABELS.count * item_h;
        start_y := half_h - total_h * 0.5;
        for i: 0..AUDIO_LABELS.count-1 {
            col  := ifx cast(s32)i == g_settings.cursor then selected else dim;
            pct  := cast(s32)(audio_get(cast(s32)i) * 100.0 + 0.5);
            bar  := make_volume_bar(pct, cast(s32)i == g_settings.cursor);
            label := tprint("%    %", AUDIO_LABELS[i], bar);
            prepare_text(g_settings.item_font, label);
            x := (fw - cast(float) gPreppedTextWidth) * 0.5;
            draw_prepared_text(g_settings.item_font, xx x, xx (start_y + cast(float)i * item_h), col);
        }
        hint_str := "↑↓ navigate   ← → adjust   Esc back";
        prepare_text(g_settings.item_font, hint_str);
        hint_x := (fw - cast(float) gPreppedTextWidth) * 0.5;
        draw_prepared_text(g_settings.item_font, xx hint_x, xx (fh * 0.82), dim);
    }
}

#scope_file

make_volume_bar :: (pct: s32, active: bool) -> string {
    STEPS :: 10;
    filled := (pct + 5) / STEPS;
    builder : String_Builder;
    append(*builder, "[ ");
    for i: 0..STEPS-1 {
        if i < filled then append(*builder, "■");
        else               append(*builder, "·");
    }
    append(*builder, tprint(" %", pct));
    append(*builder, " ]");
    return builder_to_string(*builder,, allocator = temp);
}
