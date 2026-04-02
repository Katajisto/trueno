DEBUG_LINE_MAX :: 65536;

g_debug_line_verts : [DEBUG_LINE_MAX * 2 * 7]float;
g_debug_line_count : int;

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

debug_line :: (a: Vector3, b: Vector3, col: Vector4) {
    if !debug_draw_enabled                   then return;
    if g_debug_line_count >= DEBUG_LINE_MAX  then return;
    base := g_debug_line_count * 14;
    g_debug_line_verts[base + 0]  = a.x;
    g_debug_line_verts[base + 1]  = a.y;
    g_debug_line_verts[base + 2]  = a.z;
    g_debug_line_verts[base + 3]  = col.x;
    g_debug_line_verts[base + 4]  = col.y;
    g_debug_line_verts[base + 5]  = col.z;
    g_debug_line_verts[base + 6]  = col.w;
    g_debug_line_verts[base + 7]  = b.x;
    g_debug_line_verts[base + 8]  = b.y;
    g_debug_line_verts[base + 9]  = b.z;
    g_debug_line_verts[base + 10] = col.x;
    g_debug_line_verts[base + 11] = col.y;
    g_debug_line_verts[base + 12] = col.z;
    g_debug_line_verts[base + 13] = col.w;
    g_debug_line_count += 1;
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

debug_box_2d :: (rect: Collision_Rect, y: float, col: Vector4) {
    if !debug_draw_enabled || !debug_draw_colliders then return;
    hw := rect.width  * 0.5;
    hh := rect.height * 0.5;
    cx := rect.position.x;
    cz := rect.position.y;
    p0 := Vector3.{cx - hw, y, cz - hh};
    p1 := Vector3.{cx + hw, y, cz - hh};
    p2 := Vector3.{cx + hw, y, cz + hh};
    p3 := Vector3.{cx - hw, y, cz + hh};
    debug_line(p0, p1, col);
    debug_line(p1, p2, col);
    debug_line(p2, p3, col);
    debug_line(p3, p0, col);
}

debug_circle_2d :: (circle: Collision_Circle, y: float, col: Vector4, segments: int = 16) {
    if !debug_draw_enabled || !debug_draw_colliders then return;
    TAU :: cast(float)(2.0 * 3.14159265358979);
    cx := circle.position.x;
    cz := circle.position.y;
    r  := circle.radius;
    for i: 0..segments-1 {
        t0 := (cast(float)i       / cast(float)segments) * TAU;
        t1 := (cast(float)(i + 1) / cast(float)segments) * TAU;
        a  := Vector3.{cx + cos(t0) * r, y, cz + sin(t0) * r};
        b  := Vector3.{cx + cos(t1) * r, y, cz + sin(t1) * r};
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

debug_draw_flush_gpu :: () {
    if g_debug_line_count == 0 then return;
    sg_update_buffer(
        gPipelines.debugline.bind.vertex_buffers[0],
        *(sg_range.{
            ptr  = g_debug_line_verts.data,
            size = cast(u64)(g_debug_line_count * 14 * size_of(float)),
        })
    );
    mvp    := create_viewproj(*camera);
    params : Debugline_Vs_Params;
    params.mvp = mvp.floats;
    sg_apply_pipeline(gPipelines.debugline.pipeline);
    sg_apply_bindings(*gPipelines.debugline.bind);
    sg_apply_uniforms(UB_debugline_vs_params, *(sg_range.{ ptr = *params, size = size_of(Debugline_Vs_Params) }));
    sg_draw(0, xx (g_debug_line_count * 2), 1);
    g_debug_line_count = 0;
}
