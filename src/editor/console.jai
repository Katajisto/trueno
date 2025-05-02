Console_State :: enum {
    CLOSED;
    OPEN_HALF;
    OPEN_FULL; 
}

console_state : Console_State = .CLOSED;

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
}

console_input : string = "HELLO??";

draw_console :: (theme: *GR.Overall_Theme) {
    if console_h < 1 then return;
    r := GR.get_rect(0, 0, 100*vw, console_h);
    draw_rectangle(r, theme.text_input_theme.button_theme.surface_color);
    r.w = 102*vw;
    r.x -= 1*vw;
    r.y = r.h - ui_h(5, 4);
    r.h = ui_h(5, 4);
    GR.label(r, "HELLO?!! wTF=", *theme.label_theme);
    // a, new, state := GR.text_input(r, console_input, *theme.text_input_theme);

    // if !state.active then GR.activate(state);
}
