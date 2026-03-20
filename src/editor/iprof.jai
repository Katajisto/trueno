#if FLAG_IPROF_ENABLED == false {

init_profiler :: () {}

draw_profiler :: () {}

profiler_update :: () {}

tick_profiler :: () {}

} else {
#scope_file 

iprof_conf : __Iprof.Config;
iprof_font : Ui_Font;

Profiler_Mode :: enum {
	CLOSED;
	TEXT_ONLY;
	FULL;
}

profiler_mode : Profiler_Mode = .CLOSED;

draw_text :: (x: float, y: float, text: string, color: Vector4) {
	prepare_text(*iprof_font, text);
	draw_prepared_text(*iprof_font, xx x, xx y, color);
}

draw_line :: (p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, color: Vector4) {
	immediate_quad(p0, p1, p2, p3, color);
}

text_width :: (text: string) -> float {
    if text.count < 1 {
        return 0;
    }
	
    fonsSetFont(state.fons, state.font_default.fons_font);
    fonsSetSize(state.fons, xx iprof_font.character_height);
    w := fonsTextBounds(state.fons, 0.0, 0.0, text.data, text.data + text.count, null);
	return cast(float) w;
}

draw_rectangle_prof :: (x0: float, y0: float, x1: float, y1: float, color: Vector4) {
	r := GR.Rect.{x0,y0,x1-x0,y1-y0};
	draw_rectangle(r, color);
}

graph_begin :: (x: float, y: float, width: float, height: float) {
	return;
}

graph_end   :: (x: float, y: float, width: float, height: float) {
	return;
}


iprof_cycle_active_report_mode :: () {
    iprof_active_report_mode := __Iprof.displayed_quantity;
    if iprof_active_report_mode == .SELF_TIME               __Iprof.set_report_mode(.HIERARCHICAL_TIME);
    else if iprof_active_report_mode == .HIERARCHICAL_TIME  __Iprof.set_report_mode(.CALL_COUNT);
    else if iprof_active_report_mode == .CALL_COUNT         __Iprof.set_report_mode(.SELF_TIME);
    else if iprof_active_report_mode == .CALL_GRAPH         __Iprof.set_report_mode(.SELF_TIME);
    else  assert(false);
}

iprof_paused : bool = true;
 
#scope_export

init_profiler :: () {
	iprof_font = state.font_default;
	iprof_font.character_height = 20;
    ui_init_font_fields(*iprof_font);
	iprof_conf.font_character_height = xx (iprof_font.character_height + 2);
	iprof_conf.line_spacing = 23;
	iprof_conf.draw_text = draw_text;
	iprof_conf.text_width = text_width;
	iprof_conf.draw_rectangle = draw_rectangle_prof;
	iprof_conf.draw_line = draw_line;
	iprof_conf.graph_begin = graph_begin;
	iprof_conf.graph_end = graph_end;
}

draw_profiler :: () {
	if profiler_mode == .CLOSED then return;
    w,h :=  get_window_size();
	draw_rectangle(.{xx(w-700), 0, 700, xx(h) }, .{0,0,0,1});
    __Iprof.draw(xx (w - 700), 20,699,xx h, *iprof_conf);
    if profiler_mode == .FULL {
		__Iprof.draw_graph(0,xx h,xx(w-700),200, *iprof_conf);
	}
}

profiler_update :: () {
	if profiler_mode == .CLOSED then return;
	__Iprof.update(iprof_paused);
}

tick_profiler :: () {
	if input_button_states[Key_Code.F2] & .START {
		if profiler_mode == .CLOSED    then profiler_mode = .TEXT_ONLY;
		else if profiler_mode == .TEXT_ONLY then profiler_mode = .FULL;
		else if profiler_mode == .FULL      then profiler_mode = .CLOSED;
	}
	if profiler_mode == .CLOSED then return;
	if input_button_states[Key_Code.ARROW_UP] & .START {
		__Iprof.move_cursor(-1);
	}
	if input_button_states[Key_Code.ARROW_DOWN] & .START {
		__Iprof.move_cursor(1);
	}
	if input_button_states[Key_Code.ARROW_LEFT] & .START {
		__Iprof.select_parent();
	}
	if input_button_states[Key_Code.ARROW_RIGHT] & .START {
		__Iprof.select();
	}
	if input_button_states[Key_Code.SPACEBAR] & .START {
		iprof_cycle_active_report_mode();
	}
	if input_button_states[Key_Code.ENTER] & .START {
		iprof_paused = !iprof_paused;
	}
	if input_button_states[Key_Code.MOUSE_BUTTON_RIGHT] & .START {
		__Iprof.graph_select_sample();
	}

    __Iprof.set_cursor_screen_coordinates(xx input_mouse_x, xx input_mouse_y);
}
}
