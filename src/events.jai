mpos : Vector2;

Queued_State_Set :: struct {
    code  : Input.Key_Code;
    state : Input.Key_Current_State;
    ticks : int;
};

state_set_queue : [..]Queued_State_Set;

state_set_queue_add :: (qss: Queued_State_Set) {
    array_add(*state_set_queue, qss);
}

handle_event :: (e: *sapp_event) {
    handle_sokol_event(xx,force e);
    // if e.type == .MOUSE_MOVE {
    //     mpos.x = e.mouse_x;
    //     mpos.y = e.mouse_y;
    // }
    // if e.type == .MOUSE_DOWN {
    //     GR.set_state_for_key(Input.Key_Code.MOUSE_BUTTON_LEFT, .START);
    //     state_set_queue_add(.{Input.Key_Code.MOUSE_BUTTON_LEFT, .DOWN, 2});
    // }
    // if e.type == .MOUSE_UP {
    //     GR.set_state_for_key(Input.Key_Code.MOUSE_BUTTON_LEFT, .END);
    //     state_set_queue_add(.{Input.Key_Code.MOUSE_BUTTON_LEFT, .NONE, 2});
    // }
}
