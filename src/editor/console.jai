#scope_file

Console_State :: enum {
    CLOSED;
    OPEN_HALF;
    OPEN_FULL; 
}

MAX_REPORT_ROWS :: 5000;

console_state : Console_State = .CLOSED;

console_report : [..]string;

console_h             : float = 0.0;
console_move_speed    : float = 400.0;
console_scroll_offset : int   = 0;    // lines scrolled up from the most recent
console_at_bottom     : bool  = true; // auto-follow new lines unless user has scrolled

get_console_h_target_from_state :: (state: Console_State) -> float {
    if state == {
        case .OPEN_HALF;
            return 45 * vh;
        case .OPEN_FULL;
            return 95 * vh;
    }
    return 0;
}


console_input_start : string = "";


parse_argument_float :: (s: string) -> bool {
    return false;
}

#scope_export

string_to_bool :: (s: string) -> (bool, bool) {
    if s == {
        case "True"; #through;
        case "TRUE"; #through;
        case "1"; #through;
        case "true"; #through;
        case "t"; #through;
        case "T";
            return true, true;
        case "False"; #through;
        case "FALSE"; #through;
        case "0"; #through;
        case "false"; #through;
        case "f"; #through;
        case "F";
            return false, true;
        case;
            return false, false;
    }
    if s == "true" || s == "TRUE" return true, true;
    if s == "false" || s == "FALSE" return false, true;
    return false, false;
}

add :: (a: int, b: int) -> int {
    return a + b;
} @Command

add2 :: (a: int) -> int {
    return a + 2;
} @Command

console_command_procs : [..]([]string) -> string;
console_command_names : [..]string;

init_console :: () {
    register_commands();
}

verify_argument_count :: (range_start: s64, range_end: s64, count: s64) -> bool {
    return count >= range_start && count <= range_end;
}

tick_console :: () {
    if input_button_states[get_action_combo(Editor_Action.TOGGLE_CONSOLE).key] & .START {
        if console_state != .CLOSED {
            if input_button_states[Key_Code.SHIFT] & .DOWN {
                if console_state == .OPEN_FULL {
                    console_state = .OPEN_HALF;
                } else {
                    console_state = .OPEN_FULL;
                }
            } else {
                console_state = .CLOSED;
            }
        } else {
            if input_button_states[Key_Code.SHIFT] & .DOWN {
                console_state = .OPEN_FULL;
            } else {
                console_state = .OPEN_HALF;
            }
        }
    }

    t := get_console_h_target_from_state(console_state);
    if console_h < t {
        console_h += cast(float) (console_move_speed * vh * delta_time);
        if console_h > t {
            console_h = t;
        }
    }
    if console_h > t {
        console_h -= cast(float) (console_move_speed * vh * delta_time);
        if console_h < t {
            console_h = t;
        }
    }

    if console_state != .CLOSED {
        console_open_ignore_input = true;

        line_h      := ui_h(5, 4);
        max_visible := cast(int)((console_h - line_h) / line_h);
        max_scroll  := max(0, console_report.count - max_visible);

        scroll_delta := 0;
        if input_button_states[Key_Code.PAGE_UP]   & .START            scroll_delta = max_visible;
        if input_button_states[Key_Code.PAGE_DOWN] & .START            scroll_delta = -max_visible;

        if scroll_delta != 0 {
            console_scroll_offset = clamp(console_scroll_offset + scroll_delta, 0, max_scroll);
            console_at_bottom = (console_scroll_offset == 0);
        }
    } else {
        console_open_ignore_input = false;
    }
}

console_add_output_line :: (s: string) {   
    array_add(*console_report, s);
    while console_report.count > MAX_REPORT_ROWS {
        array_ordered_remove_by_index(*console_report, 0);
        if console_scroll_offset > 0 then console_scroll_offset -= 1;
    }
    if console_at_bottom then console_scroll_offset = 0;
}

draw_console :: (theme: *GR.Overall_Theme) {
    if console_h < 1 then return;
    r := GR.get_rect(0, 0, 100*vw, console_h);
    draw_rectangle(r, theme.text_input_theme.button_theme.surface_color);
    r.w = 102*vw;
    r.x -= 1*vw;
    r.y = r.h - ui_h(5, 4);
    r.h = ui_h(5, 4);

    a, new, state := GR.text_input(r, console_input_start, *theme.text_input_theme);
    if a & .ENTERED {
        array_add(*console_report, copy_string(tprint("> %", new)));
        state.text = console_input_start;
        found := false;
        args := split(trim(new), " ");
        if args.count < 1 then return;
        for it, idx : console_command_names {
            if it == args[0] {
                args.count -= 1;
                args.data += 1;
                array_add(*console_report, console_command_procs[idx](args));
                found = true;
                break;
            }
        }
        // array_reset(*args);
        if !found then array_add(*console_report, "Unknown command.");
    }

    max_visible := cast(int)((console_h - r.h) / r.h);
    max_scroll  := max(0, console_report.count - max_visible);
    console_scroll_offset = clamp(console_scroll_offset, 0, max_scroll);

    start_idx := console_report.count - 1 - console_scroll_offset;
    for i: 0..max_visible-1 {
        idx := start_idx - i;
        if idx < 0 break;
        r.y -= r.h;
        GR.label(r, console_report[idx], *t_label_left(theme));
    }

    if console_scroll_offset > 0 {
        r.y -= r.h;
        GR.label(r, tprint("[ ↑ % more ]", console_scroll_offset), *t_label_left(theme));
    }
    
    if !state.active then GR.activate(state);
}
