MAX_FILE_SIZE :: 200_000;
buf : [MAX_FILE_SIZE]u8;

mandatory_loads_left      : s32  = 0;
init_after_mandatory_done : bool = false;

mandatory_loads_done :: () -> bool {
    return mandatory_loads_left <= 0;
}

init_font_loads :: () {
    mandatory_loads_left += 1;
    sfetch_send(*(sfetch_request_t.{
        path = "./resources/DroidSerif-Regular.ttf".data,
        callback = fontcb,
        buffer = .{
            ptr = buf.data,
            size = buf.count
        }
    }));
}

fontcb :: (res: *sfetch_response_t) #c_call {
    push_context,defer_pop default_context;
    state.font_default.fons_font = fonsAddFontMem(state.fons, "sans", res.data.ptr, xx res.data.size, 0);
    ui_init_font_fields(*state.font_default);
    mandatory_loads_left -= 1;
}
