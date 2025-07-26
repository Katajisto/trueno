#scope_file

Console_State :: enum {
    CLOSED;
    OPEN_HALF;
    OPEN_FULL; 
}

MAX_REPORT_ROWS :: 100;

console_state : Console_State = .CLOSED;

console_report : [..]string;

console_h          : float = 0.0;
console_move_speed : float = 400.0;

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

command_add :: (a: int, b: int) -> int {
    return a + b;
}

command_add_front :: (args: []string) {
    if verify_argument_count(2,2,args.count) {
        array_add(*console_report, sprint("Argument count error: count = % not in range %..%.", args.count, 2, 2));
        return;
    }
} 

#scope_export

console_command_procs : [..]([]string) -> string;
console_command_names : [..]string;

init_console :: () {
    register_commands();
}

verify_argument_count :: (range_start: s64, range_end: s64, count: s64) -> bool {
    return count >= range_start && count <= range_end;
}

tick_console :: () {
    if input_button_states[Key_Code.F1] & .START {
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

    while console_report.count > MAX_REPORT_ROWS {
        array_ordered_remove_by_index(*console_report, 0);
    }

    if console_state != .CLOSED {
        console_open_ignore_input = true;
    } else {
        console_open_ignore_input = false;
    }
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
        for it, idx : console_command_names {
            print("%\n", it);
            if it == new {
                array_add(*console_report, console_command_procs[idx](.[]));
                found = true;
            }
        }
        if !found then array_add(*console_report, "Unknown command.");
    }

    for < console_report {
        r.y -= r.h;
        GR.label(r, it, *t_label_left(theme));
    }
    
    if !state.active then GR.activate(state);
}
