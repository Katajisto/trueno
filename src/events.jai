mpos : Vector2;

handle_event :: (e: *sapp_event) {
    if e.type == .MOUSE_MOVE {
        mpos.x = e.mouse_x;
        mpos.y = e.mouse_y;
    }
    
}
