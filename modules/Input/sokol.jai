#import "String";  // @Cleanup: Remove this dependency on String?
#import,dir "../sokol-jai/sokol/app";

input_mouse_x : float;
input_mouse_y : float;

set_custom_cursor_handling :: (is_custom: bool) {
}

get_key_code :: (key: sapp_keycode) -> Key_Code {
    using Key_Code;
    // non-ascii ordered as in ./module.jai/Key_Code
    if key == .BACKSPACE
        return BACKSPACE;
    if key == .TAB
        return TAB;
    if key == .ENTER
        return ENTER;
    if key == .ESCAPE
        return ESCAPE;
    if key == .DELETE
        return DELETE;
    if key == .SPACE
        return SPACEBAR;


    if key == .UP
        return ARROW_UP;
    if key == .DOWN
        return ARROW_DOWN;
    if key == .LEFT
        return ARROW_LEFT;
    if key == .RIGHT
        return ARROW_RIGHT;


    if key == .PAGE_UP
        return PAGE_UP;
    if key == .PAGE_DOWN
        return PAGE_DOWN;


    if key == .HOME
        return HOME;
    if key == .END
        return END;

    if key == .INSERT
        return INSERT;

    if key == .PAUSE
        return PAUSE;
    if key == .SCROLL_LOCK
        return SCROLL_LOCK;

    if (key == .LEFT_ALT) || (key == .RIGHT_ALT)
        return ALT;
    
    if (key == .LEFT_CONTROL) || (key == .RIGHT_CONTROL)
        return CTRL;
    if (key == .LEFT_SHIFT) || (key == .RIGHT_SHIFT)
        return SHIFT;
    if (key == .LEFT_SUPER) || (key == .RIGHT_SUPER)
        return META;

    if key >= sapp_keycode.F1 && key <= sapp_keycode.F25
        return (cast(Key_Code) (key - sapp_keycode.F1))+F1;


    if key == .PRINT_SCREEN
        return PRINT_SCREEN;


    if (key >= #char "a") && (key <= #char "z") return cast(Key_Code) (key);
    if key > 32 && key < 127 return cast(Key_Code) key;

    return UNKNOWN;
}

get_key_code_for_mouse :: (mb: sapp_mousebutton) -> Key_Code {
    if mb == .LEFT
        return .MOUSE_BUTTON_LEFT;
    if mb == .RIGHT
        return .MOUSE_BUTTON_RIGHT;
    if mb == .MIDDLE
        return .MOUSE_BUTTON_MIDDLE;
    return .UNKNOWN;
}

add_modifier_info :: (sokol_event: *sapp_event, event: *Event) {
    if sokol_event.modifiers & MODIFIER_SHIFT {
        event.modifier_flags.shift_pressed = true;
    }
    if sokol_event.modifiers & MODIFIER_CTRL {
        event.modifier_flags.ctrl_pressed = true;
    }
    if sokol_event.modifiers & MODIFIER_ALT {
        event.modifier_flags.alt_pressed = true;
    }
    if sokol_event.modifiers & MODIFIER_SUPER {
        event.modifier_flags.cmd_meta_pressed = true;
    }
}

modifiers_cause_char_event_ignore :: (sokol_event: *sapp_event) -> bool {
    if sokol_event.modifiers & MODIFIER_CTRL  then return true;
    if sokol_event.modifiers & MODIFIER_ALT   then return true;
    if sokol_event.modifiers & MODIFIER_SUPER then return true;
    return false;
}

#scope_export

handle_sokol_event :: (event: *sapp_event) {
    new_event: Event;
    if event.type == {
        case .KEY_DOWN;
            mapped := get_key_code(event.key_code);    
            new_event.type = .KEYBOARD;
            new_event.key_code = mapped;
            new_event.key_pressed = 1;
            add_modifier_info(event, *new_event);
            input_button_states[mapped] = .START | .DOWN;
        case .KEY_UP;
            mapped := get_key_code(event.key_code);
            new_event.type = .KEYBOARD;
            new_event.key_code = mapped;
            new_event.key_pressed = 0;
            add_modifier_info(event, *new_event);
            input_button_states[mapped] = .END; 
        case .MOUSE_DOWN;
            mapped := get_key_code_for_mouse(event.mouse_button);
            new_event.type = .KEYBOARD;
            new_event.key_code = mapped;
            new_event.key_pressed = 1;
            input_button_states[mapped] = .START | .DOWN;
        case .MOUSE_UP;
            mapped := get_key_code_for_mouse(event.mouse_button);
            new_event.type = .KEYBOARD;
            new_event.key_code = mapped;
            new_event.key_pressed = 0;
            input_button_states[mapped] = .END; 
        case .CHAR;
            if modifiers_cause_char_event_ignore(event) then return;
            new_event.type = .TEXT_INPUT;
            new_event.utf32 = event.char_code;            
        case .FOCUSED;
            input_application_has_focus = true;
            return;
        case .UNFOCUSED;
            input_application_has_focus = false;
            return;
        case .MOUSE_MOVE;
            input_mouse_x = event.mouse_x;
            input_mouse_y = event.mouse_y;
            return;
        case .MOUSE_SCROLL;
            mouse_delta_z = cast(int) event.scroll_y;
    }
    array_add(*events_this_frame, new_event);
}


/*

Copyright 2021, Thekla, Inc. Modified to work with Sokol by Tuomas Katajisto. 

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


*/
