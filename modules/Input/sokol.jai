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


    if (key >= #char "a") && (key <= #char "z") return cast(Key_Code) (key - 0x20);
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

#scope_export

handle_sokol_event :: (event: *sapp_event) {
    new_event: Event;
    if event.type == {
        case .KEY_DOWN;
            mapped := get_key_code(event.key_code);
            new_event.type = .KEYBOARD;
            new_event.key_code = mapped;
            new_event.key_pressed = 1;
            input_button_states[mapped] = .START | .DOWN;
        case .KEY_UP;
            mapped := get_key_code(event.key_code);
            new_event.type = .KEYBOARD;
            new_event.key_code = mapped;
            new_event.key_pressed = 0;
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
    }
    array_add(*events_this_frame, new_event);
}
    
//     using Key_Code;

//     input_per_frame_event_and_flag_update();

//     display := x_global_display;
//     XLockDisplay(display);

//     key_press_repeat := false;
//     while XPending(display) {
//         xev: XEvent;
//         XNextEvent(display, *xev);

//         if XFilterEvent(*xev, None) continue;

//         if xev.type == {
//           case ClientMessage;
//             message_type := xev.xclient.message_type;
//             if message_type == XdndEnter {
//                 drop_handled := maybe_handle_xdnd_drop_events(display, *xev, *drop_info);
// 		        if drop_handled  continue;
//             } else if message_type == x_global_wm_protocols {
//                 message0 := cast(Atom) xev.xclient.data.l[0];

//                 // This can't be a switch, because the values are not constant!
//                 // Except come on guys, every single implementation of X11 in the universe
//                 // is going to agree on these values. Why are we pretending they are not constant?
//                 // How about if we just look them up once and then hardcode them into this program?
//                 // We'd save startup time...

//                 if message0 == x_global_wm_delete_window {
//                     event: Event;
//                     event.type = .QUIT;
//                     array_add(*events_this_frame, event);
//                 }
//             }
//         case KeyPress;
//             event: Event;

//             shift: u32;
//             if xev.xkey.state & ShiftMask
//                 shift = 1;
//             if xev.xkey.state & ControlMask
//                 event.ctrl_pressed = true;
//             if xev.xkey.state & Mod1Mask
//                 event.alt_pressed = true;

//             status: Status;
//             keysym: KeySym;
//             text: [16]u32;
//             lookup_count := XwcLookupString(x_global_input_context, *xev.xkey, xx text.data, xx text.count, *keysym, *status);

//             has_keysym := (status == XLookupKeySym || status == XLookupBoth);
//             has_text := (status == XLookupChars || status == XLookupBoth);

//             if has_keysym {
//                 if xev.xkey.state & ShiftMask   event.shift_pressed = true;
//                 if xev.xkey.state & ControlMask event.ctrl_pressed = true;
//                 if xev.xkey.state & Mod1Mask    event.alt_pressed = true;
//                 if xev.xkey.state & Mod4Mask    event.cmd_meta_pressed = true;

//                 event.type = .KEYBOARD;
//                 event.key_pressed = 1;
//                 event.key_code = get_key_code(keysym);

//                 for 0..lookup_count - 1 {
//                     utf32 := text[it];
//                     if utf32 >= 32 && utf32 != 127 event.text_input_count += 1;
//                 }
                
//                 if event.key_code == {
//                     case .SHIFT; event.shift_pressed = true;
//                     case .CTRL;  event.ctrl_pressed = true;
//                     case .ALT;   event.alt_pressed = true;
//                     case .META;  event.cmd_meta_pressed = true;
//                 }

//                 event.repeat = key_press_repeat;
//                 key_press_repeat = false;
                
//                 array_add(*events_this_frame, event);
//                 input_button_states[event.key_code] = .START | .DOWN;
//             }

//             event.shift_pressed = cast(bool) shift;

//             if has_text {
//                 for 0..lookup_count - 1 {
//                     utf32 := text[it];
//                     if utf32 < 32 || utf32 == 127 continue;

//                     char_event: Event;
//                     char_event.type = .TEXT_INPUT;
//                     char_event.key_pressed = 1;
//                     char_event.key_code = get_key_code(keysym);
//                     char_event.utf32 = utf32;

//                     array_add(*events_this_frame, char_event);
//                 }
//             }
//         case KeyRelease;
//             // For some odd reason X11 generates KeyRelease followed by a near identical KeyPress to simulate repeat events so we have to filter that out
//             if XEventsQueued(display, QueuedAfterReading) {
//                 nev: XEvent;
//                 XPeekEvent(display, *nev);

//                 if nev.type == KeyPress
//                     && nev.xkey.time == xev.xkey.time
//                     && nev.xkey.keycode == xev.xkey.keycode {

//                         // This is a repeat, so we ignore the KeyRelease and set the repeat flag.
//                     key_press_repeat = true;
//                     continue;
//                 }
//             }

//             event: Event;

//             shift: u32;
//             if xev.xkey.state & ShiftMask
//                 shift = 1;
//             if xev.xkey.state & ControlMask
//                 event.ctrl_pressed = true;
//             if xev.xkey.state & Mod1Mask
//                 event.alt_pressed = true;

//             keysym := XkbKeycodeToKeysym(display, xx xev.xkey.keycode, 0, 0 /* English lowercase group*/);
//             event.type = .KEYBOARD;
//             event.key_pressed = 0;
//             event.shift_pressed = cast(bool) shift;
//             event.key_code = get_key_code(keysym);
            
//             input_button_states[event.key_code] = .END;

//             array_add(*events_this_frame, event);
//         case ButtonPress;
//             event: Event;
//             event.type = .KEYBOARD;

//             event.key_pressed = 1;
//             button := xev.xbutton.button;

//             // 6/7 is horizontal/secondary wheel, don't handle it
//             if (button == 6) || (button == 7) continue;

//             // button 4/5 is mwheel up/down
//             if (button == 4) || (button == 5) {
//                 event.type = .MOUSE_WHEEL;
//                 event.typical_wheel_delta = WHEEL_DELTA;
//                 event.wheel_delta = event.typical_wheel_delta * ifx button & 1 then cast(s32) - 1 else 1;
//                 array_add(*events_this_frame, event);
//                 mouse_delta_z += event.wheel_delta;
//                 continue;
//             }
            
//             if button == Button1 {
//                 event.key_code = MOUSE_BUTTON_LEFT;
//             } else if button == Button2 {
//                 event.key_code = MOUSE_BUTTON_MIDDLE;
//             } else if button == Button3 {
//                 event.key_code = MOUSE_BUTTON_RIGHT;
//             }

//             input_button_states[event.key_code] = .START | .DOWN;

//             array_add(*events_this_frame, event);
//         case ButtonRelease;
//             // it seems that mouse input doesnt generate repeat events so we dont have to peek the queue
//             event: Event;
//             event.type = .KEYBOARD;

//             event.key_pressed = 0;
//             button := xev.xbutton.button;

//             if (button >= 4) && (button <= 7) continue;  // No action on button release of mouse wheels.
            
//             if button == Button1 {
//                 event.key_code = MOUSE_BUTTON_LEFT;
//             } else if button == Button2 {
//                 event.key_code = MOUSE_BUTTON_MIDDLE;
//             } else if button == Button3 {
//                 event.key_code = MOUSE_BUTTON_RIGHT;
//             }

//             input_button_states[event.key_code] = .END;

//             array_add(*events_this_frame, event);
//         case SelectionRequest;
//             selreq := cast(*XSelectionRequestEvent) *xev;

//             out: XEvent;
//             selnot := cast(*XSelectionEvent) *out;
//             selnot.type = SelectionNotify;
//             selnot.requestor = selreq.requestor;
//             selnot.selection = selreq.selection;
//             selnot.target = selreq.target;
//             selnot.time = selreq.time;
//             selnot.property = None;

//             if x_window_is_ours(x_global_display, selreq.owner) {
//                 if selreq.target == x_global_xa_utf8 {
//                     selnot.property = selreq.property;

//                     text_data := x_global_clipboard_buffer.text_data;
//                     XChangeProperty(selreq.display, selreq.requestor, selreq.property, selreq.target, 8, PropModeReplace,
//                                     text_data.data, cast(s32) text_data.count);
//                 } else if selreq.target == x_global_xa_targets {

//                     selnot.property = selreq.property;

//                     atoms: [..] Atom;
//                     array_add(*atoms, x_global_xa_utf8);
//                     array_add(*atoms, x_global_xa_targets);
//                     array_add(*atoms, x_global_xa_multiple);
//                     if x_global_clipboard_buffer.rgb_data {
//                         array_add(*atoms, x_global_image_bmp);
//                     }
//                     XChangeProperty(selreq.display, selreq.requestor, selreq.property, x_global_xa_atom, 32, PropModeReplace,
//                                     xx atoms.data, cast(s32) atoms.count);

//                     array_reset(*atoms);
//                 } else if selreq.target == x_global_image_bmp {
//                     #import "stb_image_write";

//                     Data :: struct {
//                         _context: *#Context;
//                         data: [..] u8;
//                     }

//                     write_func :: (data_pointer: *void, _data: *void, size: s32) #c_call {
//                         data := cast(*Data) data_pointer;
//                         push_context data._context.* {
//                             data8 := cast(*u8) _data;
//                             for 0..size-1 {
//                                 array_add(*data.data, data8[it]);
//                             }
//                         }
//                     }

//                     data: Data;
//                     data._context = *context;
//                     w := x_global_clipboard_buffer.width;
//                     h := x_global_clipboard_buffer.height;
//                     comp: s32 = 3;
//                     stride := x_global_clipboard_buffer.pitch;
//                     stbi_write_bmp_to_func(write_func, *data, w, h, comp, x_global_clipboard_buffer.rgb_data);

//                     selnot.property = selreq.property;
//                     XChangeProperty(selreq.display, selreq.requestor, selreq.property, selreq.target, 8, PropModeReplace,
//                                     xx data.data.data, cast(s32) data.data.count);

//                     array_reset(*data.data);
//                 } else {
//                     // print("GOT REQ: %\n", to_string(XGetAtomName(x_global_display, selreq.target)));
//                 }
//             }

//             XSendEvent(selreq.display, selreq.requestor, True, 0, *out);
//         case ConfigureNotify;
//             config := cast(*XConfigureEvent) *xev;
//             add_resize_record(config.window, config.width, config.height);
//         case FocusIn;
//             input_application_has_focus = true;
//         case FocusOut;
//             input_application_has_focus = false;
//         }
    // }
    // XUnlockDisplay(display);

WHEEL_DELTA :: 120;

/*

Copyright 2021, Thekla, Inc. Modified to work with Sokol by Tuomas Katajisto. 

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


*/
