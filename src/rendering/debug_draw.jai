DEBUG_LINE_MAX         :: 65536;
DEBUG_OVERLAY_LINE_MAX :: 8192;

// One record per line, uploaded as instance data: the line pipeline expands each
// into a screen-space quad so lines can have a real pixel width.
Debug_Line :: struct {
    a     : Vector3;
    b     : Vector3;
    color : Vector4;
    width : float;   // in pixels
}

DEBUG_LINE_DEFAULT_WIDTH :: 1.0;

g_debug_lines      : [DEBUG_LINE_MAX]Debug_Line;
g_debug_line_count : int;

// Overlay lines ignore the depth buffer, so editor gizmos stay visible through
// terrain. They are UI rather than debug visualization, so they are not gated
// on debug_draw_enabled.
g_overlay_lines      : [DEBUG_OVERLAY_LINE_MAX]Debug_Line;
g_overlay_line_count : int;

debug_draw_enabled   : bool = !FLAG_RELEASE_BUILD;
debug_draw_grid      : bool = true;
debug_draw_vectors   : bool = true;
debug_draw_colliders : bool = true;

toggle_debug_draw :: () {
    debug_draw_enabled = !debug_draw_enabled;
} @Command

toggle_debug_grid :: () {
    debug_draw_grid = !debug_draw_grid;
} @Command

toggle_debug_vectors :: () {
    debug_draw_vectors = !debug_draw_vectors;
} @Command

toggle_debug_colliders :: () {
    debug_draw_colliders = !debug_draw_colliders;
} @Command

debug_line :: (a: Vector3, b: Vector3, col: Vector4, width: float = DEBUG_LINE_DEFAULT_WIDTH) {
    if !debug_draw_enabled                   then return;
    if g_debug_line_count >= DEBUG_LINE_MAX  then return;
    g_debug_lines[g_debug_line_count] = .{a, b, col, width};
    g_debug_line_count += 1;
}

debug_line_overlay :: (a: Vector3, b: Vector3, col: Vector4, width: float = DEBUG_LINE_DEFAULT_WIDTH) {
    if g_overlay_line_count >= DEBUG_OVERLAY_LINE_MAX  then return;
    g_overlay_lines[g_overlay_line_count] = .{a, b, col, width};
    g_overlay_line_count += 1;
}

debug_aabb_3d_overlay :: (mn: Vector3, mx: Vector3, col: Vector4, width: float = DEBUG_LINE_DEFAULT_WIDTH) {
    corner :: (mn: Vector3, mx: Vector3, i: int) -> Vector3 {
        return .{ ifx i & 1 then mx.x else mn.x,
                  ifx i & 2 then mx.y else mn.y,
                  ifx i & 4 then mx.z else mn.z };
    }
    // Every pair of corners differing in exactly one bit is an edge of the box.
    for i: 0..7 {
        for bit: int.[1, 2, 4] {
            j := i | bit;
            if j == i then continue;
            debug_line_overlay(corner(mn, mx, i), corner(mn, mx, j), col, width);
        }
    }
}

debug_vector :: (origin: Vector3, vec: Vector3, col: Vector4) {
    if !debug_draw_enabled || !debug_draw_vectors then return;
    tip   := origin + vec;
    shaft := normalize(vec);
    debug_line(origin, tip, col);
    arrowhead_len  : float : 0.15;
    arrowhead_back := tip - shaft * arrowhead_len;
    perp : Vector3;
    if abs(shaft.x) < 0.9 {
        perp = normalize(cross(shaft, .{1, 0, 0}));
    } else {
        perp = normalize(cross(shaft, .{0, 1, 0}));
    }
    wing  := perp * (arrowhead_len * 0.5);
    perp2 := cross(shaft, perp);
    wing2 := perp2 * (arrowhead_len * 0.5);
    debug_line(arrowhead_back + wing,  tip, col);
    debug_line(arrowhead_back - wing,  tip, col);
    debug_line(arrowhead_back + wing2, tip, col);
    debug_line(arrowhead_back - wing2, tip, col);
}

debug_grid :: (cx: float, y: float, cz: float, half_extent: int, col: Vector4) {
    if !debug_draw_enabled || !debug_draw_grid then return;
    for i: -half_extent..half_extent {
        fi := cast(float)i;
        fe := cast(float)half_extent;
        debug_line(.{cx + fi, y, cz - fe}, .{cx + fi, y, cz + fe}, col);
        debug_line(.{cx - fe, y, cz + fi}, .{cx + fe, y, cz + fi}, col);
    }
}

// Todo: This should probably allow for any axis to be the constant one.
// Currently this is this way to support the game being currently made.
debug_box_2d :: (rect: Collision_Rect, x: float, col: Vector4) {
    if !debug_draw_enabled || !debug_draw_colliders then return;
    hw := rect.width  * 0.5;
    hh := rect.height * 0.5;
    cx := rect.position.x;
    cz := rect.position.y;
    p0 := Vector3.{ x, cz - hh, cx - hw };
    p1 := Vector3.{ x, cz - hh, cx + hw };
    p2 := Vector3.{ x, cz + hh, cx + hw };
    p3 := Vector3.{ x, cz + hh, cx - hw };
    debug_line(p0, p1, col);
    debug_line(p1, p2, col);
    debug_line(p2, p3, col);
    debug_line(p3, p0, col);
}

debug_circle_2d :: (circle: Collision_Circle, x: float, col: Vector4, segments: int = 16) {
    if !debug_draw_enabled || !debug_draw_colliders then return;
    TAU :: cast(float)(2.0 * 3.14159265358979);
    cx := circle.position.x;
    cz := circle.position.y;
    r  := circle.radius;
    for i: 0..segments-1 {
        t0 := (cast(float)i       / cast(float)segments) * TAU;
        t1 := (cast(float)(i + 1) / cast(float)segments) * TAU;
        a  := Vector3.{x, cz + sin(t0) * r, cx + cos(t0) * r};
        b  := Vector3.{x, cz + sin(t1) * r, cx + cos(t1) * r};
        debug_line(a, b, col);
    }
}

debug_aabb_3d :: (mn: Vector3, mx: Vector3, col: Vector4) {
    if !debug_draw_enabled || !debug_draw_colliders then return;
    debug_line(.{mn.x, mn.y, mn.z}, .{mx.x, mn.y, mn.z}, col);
    debug_line(.{mn.x, mn.y, mn.z}, .{mn.x, mn.y, mx.z}, col);
    debug_line(.{mx.x, mn.y, mn.z}, .{mx.x, mn.y, mx.z}, col);
    debug_line(.{mn.x, mn.y, mx.z}, .{mx.x, mn.y, mx.z}, col);
    debug_line(.{mn.x, mx.y, mn.z}, .{mx.x, mx.y, mn.z}, col);
    debug_line(.{mn.x, mx.y, mn.z}, .{mn.x, mx.y, mx.z}, col);
    debug_line(.{mx.x, mx.y, mn.z}, .{mx.x, mx.y, mx.z}, col);
    debug_line(.{mn.x, mx.y, mx.z}, .{mx.x, mx.y, mx.z}, col);
    debug_line(.{mn.x, mn.y, mn.z}, .{mn.x, mx.y, mn.z}, col);
    debug_line(.{mx.x, mn.y, mn.z}, .{mx.x, mx.y, mn.z}, col);
    debug_line(.{mn.x, mn.y, mx.z}, .{mn.x, mx.y, mx.z}, col);
    debug_line(.{mx.x, mn.y, mx.z}, .{mx.x, mx.y, mx.z}, col);
}

flush_debug_lines :: (pipe: *Pipeline_Binding, lines: []Debug_Line, count: *int, params: *Debugline_Vs_Params) {
    if count.* == 0 then return;
    // Buffer 0 is the shared static quad; buffer 1 is this pipeline's instances.
    sg_update_buffer(
        pipe.bind.vertex_buffers[1],
        *(sg_range.{
            ptr  = lines.data,
            size = cast(u64)(count.* * size_of(Debug_Line)),
        })
    );
    sg_apply_pipeline(pipe.pipeline);
    sg_apply_bindings(*pipe.bind);
    sg_apply_uniforms(UB_debugline_vs_params, *(sg_range.{ ptr = params, size = size_of(Debugline_Vs_Params) }));
    sg_draw(0, 6, xx count.*);
    count.* = 0;
}

debug_draw_flush_gpu :: () {
    if g_debug_line_count == 0 && g_overlay_line_count == 0 then return;

    w, h := get_window_size();
    mvp  := create_viewproj(*camera);
    params : Debugline_Vs_Params;
    params.mvp = mvp.floats;
    params.viewport = .[cast(float)w, cast(float)h, 0, 0];

    flush_debug_lines(*gPipelines.debugline,         g_debug_lines,   *g_debug_line_count,   *params);
    flush_debug_lines(*gPipelines.debugline_overlay, g_overlay_lines, *g_overlay_line_count, *params);
}

#assert size_of(Debug_Line) == 44 "Debug_Line must stay tightly packed: the pipeline layout hardcodes its field offsets.";
