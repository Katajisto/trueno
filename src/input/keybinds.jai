Editor_Action :: enum {
    TOGGLE_CONSOLE;
    TOGGLE_EDITOR;
    TOGGLE_SETTINGS;
    HOT_RELOAD;
    // Level editor
    LEVEL_HEIGHT_UP;
    LEVEL_HEIGHT_DOWN;
    LEVEL_TWIST_CW;
    LEVEL_TWIST_CCW;
    LEVEL_CYCLE_FACE;
    // Trile editor — tools
    TRIXEL_TOOL_PAINT;
    TRIXEL_TOOL_ADD;
    TRIXEL_TOOL_REMOVE;
    // Trile editor — modes
    TRIXEL_MODE_POINT;
    TRIXEL_MODE_AREA;
    TRIXEL_MODE_BRUSH;
    // Trile editor — tabs
    TRIXEL_TAB_TOOLS;
    TRIXEL_TAB_MATERIAL;
    TRIXEL_TAB_INFO;
    // Level editor — tool modes
    LEVEL_TOOL_POINT;
    LEVEL_TOOL_BRUSH;
    LEVEL_TOOL_AREA;
    LEVEL_TOOL_LINE;
    LEVEL_TOOL_INSPECTOR;
    LEVEL_TOOL_VIEWER;
    // Level editor — tabs
    LEVEL_TAB_TOOLS;
    LEVEL_TAB_INFO;
    LEVEL_TAB_TACOMA;
    // Shared
    SAVE;
    // Top-level studio tabs
    STUDIO_TRILE;
    STUDIO_LEVEL;
    STUDIO_MATERIAL;
    // Trile editor — view modes
    TRIXEL_VIEW_LIT;
    TRIXEL_VIEW_NORMALS;
    TRIXEL_VIEW_ALBEDO;
    TRIXEL_VIEW_MIXED;
}

#scope_file;

EDITOR_ACTION_COUNT :: #run enum_highest_value(Editor_Action) + 1;

game_keybind_enum_type : Type;

Key_Combo :: struct {
    key   : Key_Code;
    ctrl  : bool;
    shift : bool;
}

// 5000 different actions ought to be enough for anything right?
keys : [5000]Key_Combo;

check_action :: (action: $T, status: Key_Current_State) -> bool {
    offset := 0;
    if T != Editor_Action {
        offset = EDITOR_ACTION_COUNT;
    }
    if console_open_ignore_input then return false;
    combo := keys[cast(s32)action + offset];
    ctrl_down  := cast(bool)(input_button_states[Key_Code.CTRL]  & .DOWN);
    shift_down := cast(bool)(input_button_states[Key_Code.SHIFT] & .DOWN);
    if combo.ctrl  != ctrl_down  then return false;
    if combo.shift != shift_down then return false;
    return cast(bool)(input_button_states[combo.key] & status);
}


#scope_export;

set_binding :: (action: $T, combo: Key_Combo) {
    offset := 0;
    if T != Editor_Action {
        offset = EDITOR_ACTION_COUNT;
    }

    keys[cast(s32)action + offset] = combo;
}

is_action_down :: (action: $T) -> bool {
    return check_action(action, .DOWN);
}

is_action_start :: (action: $T) -> bool {
    return check_action(action, .START);
}

init_keybinds :: () {
    set_default_bindings();
}

get_action_combo :: (action: $T) -> Key_Combo {
    offset := 0;
    #if T != Editor_Action {
        offset = EDITOR_ACTION_COUNT;
    }
    return keys[cast(s32)action + offset];
}

keybind_button :: (r: GR.Rect, label: string, action: Editor_Action, theme: *GR.Button_Theme, loc := #caller_location) -> bool {
    combo      := get_action_combo(action);
    full_label := tprint("% [%]", label, key_combo_string(combo));
    clicked    := GR.button(r, full_label, theme, loc = loc);
    return clicked || is_action_start(action);
}

key_combo_string :: (combo: Key_Combo) -> string {
    k := key_code_to_string(combo.key);
    if combo.ctrl && combo.shift return tprint("C+S+%", k);
    if combo.ctrl                return tprint("C+%", k);
    if combo.shift               return tprint("S+%", k);
    return k;
}

key_code_to_string :: (key: Key_Code) -> string {
    if key == .ARROW_UP    return "↑";
    if key == .ARROW_DOWN  return "↓";
    if key == .ARROW_LEFT  return "←";
    if key == .ARROW_RIGHT return "→";
    if key == .F1  return "F1";  if key == .F2  return "F2";
    if key == .F3  return "F3";  if key == .F4  return "F4";
    if key == .F5  return "F5";  if key == .F6  return "F6";
    if key == .F7  return "F7";  if key == .F8  return "F8";
    if key == .F9  return "F9";  if key == .F10 return "F10";
    if key == .F11 return "F11"; if key == .F12 return "F12";
    v := cast(s64) key;
    if v >= 32 && v < 127 {
        buf   := cast(*u8) talloc(2);
        buf[0] = cast(u8) v;
        buf[1] = 0;
        return string.{ count = 1, data = buf };
    }
    return "?";
}

#scope_file

set_default_bindings :: () {
    set :: (a: Editor_Action, k: Key_Code, ctrl := false, shift := false) #expand {
        set_binding(a, .{ k, ctrl, shift });
    }
    set(.TOGGLE_CONSOLE,      .F1);
    set(.TOGGLE_EDITOR,       .F3);
    set(.TOGGLE_SETTINGS,     .ESCAPE);
    set(.HOT_RELOAD,          .F5);
    set(.LEVEL_HEIGHT_UP,     .ARROW_UP);
    set(.LEVEL_HEIGHT_DOWN,   .ARROW_DOWN);
    set(.LEVEL_TWIST_CW,      cast(Key_Code) #char "E");
    set(.LEVEL_TWIST_CCW,     cast(Key_Code) #char "Q");
    set(.LEVEL_CYCLE_FACE,    cast(Key_Code) #char "R");
    set(.TRIXEL_TOOL_PAINT,   cast(Key_Code) #char "P");
    set(.TRIXEL_TOOL_ADD,     cast(Key_Code) #char "-");
    set(.TRIXEL_TOOL_REMOVE,  cast(Key_Code) #char "/");
    set(.TRIXEL_MODE_POINT,   cast(Key_Code) #char "P", ctrl = true);
    set(.TRIXEL_MODE_AREA,    cast(Key_Code) #char "A", ctrl = true);
    set(.TRIXEL_MODE_BRUSH,   cast(Key_Code) #char "B", ctrl = true);
    set(.TRIXEL_TAB_TOOLS,    cast(Key_Code) #char "T");
    set(.TRIXEL_TAB_MATERIAL, cast(Key_Code) #char "M");
    set(.TRIXEL_TAB_INFO,     cast(Key_Code) #char "I");
    set(.LEVEL_TOOL_POINT,    cast(Key_Code) #char "1");
    set(.LEVEL_TOOL_BRUSH,    cast(Key_Code) #char "2");
    set(.LEVEL_TOOL_AREA,     cast(Key_Code) #char "3");
    set(.LEVEL_TOOL_LINE,     cast(Key_Code) #char "4");
    set(.LEVEL_TOOL_INSPECTOR, cast(Key_Code) #char "5");
    set(.LEVEL_TOOL_VIEWER,   cast(Key_Code) #char "6");
    set(.LEVEL_TAB_TOOLS,     cast(Key_Code) #char "T");
    set(.LEVEL_TAB_INFO,      cast(Key_Code) #char "I");
    set(.LEVEL_TAB_TACOMA,    cast(Key_Code) #char "X");
    set(.SAVE,                cast(Key_Code) #char "S", ctrl = true);
    set(.STUDIO_TRILE,        cast(Key_Code) #char "1", ctrl = true);
    set(.STUDIO_LEVEL,        cast(Key_Code) #char "2", ctrl = true);
    set(.STUDIO_MATERIAL,     cast(Key_Code) #char "3", ctrl = true);
    set(.TRIXEL_VIEW_LIT,     cast(Key_Code) #char "5");
    set(.TRIXEL_VIEW_NORMALS, cast(Key_Code) #char "6");
    set(.TRIXEL_VIEW_ALBEDO,  cast(Key_Code) #char "7");
    set(.TRIXEL_VIEW_MIXED,   cast(Key_Code) #char "8");
}
