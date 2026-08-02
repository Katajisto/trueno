// Blender-style gizmos: a translate gizmo with three RGB axis arrows plus three
// plane handles for two-axis drags, and a rotate gizmo with three RGB rings.
// Drawn with depth-ignoring overlay lines so they stay visible through terrain,
// and picked in world space so the pick thresholds scale with the gizmo itself.

Gizmo_Handle :: enum {
    NONE;
    AXIS_X;
    AXIS_Y;
    AXIS_Z;
    PLANE_YZ;  // normal +X
    PLANE_XZ;  // normal +Y
    PLANE_XY;  // normal +Z
    RING_X;    // turns about +X
    RING_Y;
    RING_Z;
}

Gizmo_State :: struct {
    hover  : Gizmo_Handle;
    active : Gizmo_Handle;

    start_position : Vector3;  // object position when the drag began
    start_t        : float;    // axis drags: parameter along the axis at grab time
    start_hit      : Vector3;  // plane drags: world point grabbed
    start_angle    : float;    // ring drags: angle around the ring at grab time
    applied_steps  : int;      // ring drags: quarter turns already handed to the caller
}

// Gizmo length as a fraction of the camera distance, so it keeps a constant
// on-screen size. Everything else is expressed in units of that length.
GIZMO_SCALE       :: 0.14;
GIZMO_PLANE_INNER :: 0.22;
GIZMO_PLANE_OUTER :: 0.52;
GIZMO_PICK_RADIUS :: 0.08;
// Below this |dot(plane normal, view dir)| the plane handle is edge-on: too thin
// to aim at, so it is neither drawn nor picked.
GIZMO_PLANE_MIN_FACING :: 0.15;
// Ring radius, and how far off it a click can land, both in units of gizmo length.
GIZMO_RING_RADIUS :: 1.0;
GIZMO_RING_PICK   :: 0.14;
GIZMO_RING_SEGMENTS :: 48;
// Line widths, in pixels.
GIZMO_LINE_WIDTH :: 3.0;
GIZMO_FILL_WIDTH :: 2.0;

// Runs one frame of the gizmo: hover, click-to-grab, drag, release, and drawing.
// Returns the dragged-to position; the caller owns snapping and writing it back.
gizmo_translate :: (using state: *Gizmo_State, position: Vector3, cam: Camera, ray: Ray) -> (position: Vector3, changed: bool) {
    len := max(length(cam.position - position) * GIZMO_SCALE, 0.001);
    pos := position;
    changed := false;

    mouse   := get_mouse_state(Key_Code.MOUSE_BUTTON_LEFT);
    pressed := (mouse & .START) != .NONE;
    held    := (mouse & .DOWN)  != .NONE;

    if active == .NONE {
        hover = gizmo_pick(position, len, cam, ray);
        if hover != .NONE && pressed {
            start_position = position;
            if gizmo_is_plane(hover) {
                ok, point := gizmo_plane_hit(position, hover, ray);
                if ok {
                    start_hit = point;
                    active    = hover;
                }
            } else {
                t, _, _ := gizmo_closest_axis_t(ray, position, gizmo_axis(hover));
                start_t  = t;
                active   = hover;
            }
        }
    } else if !held {
        active = .NONE;
    } else {
        if gizmo_is_plane(active) {
            ok, point := gizmo_plane_hit(start_position, active, ray);
            if ok {
                pos     = start_position + (point - start_hit);
                changed = true;
            }
        } else {
            axis := gizmo_axis(active);
            t, _, _ := gizmo_closest_axis_t(ray, start_position, axis);
            pos     = start_position + axis * (t - start_t);
            changed = true;
        }
    }

    // Drawn at the object's own position rather than the dragged-to one: the
    // caller may snap what we hand back, and the gizmo has to sit on the object.
    gizmo_draw(position, len, cam, ifx active != .NONE then active else hover);
    return pos, changed;
}

// One frame of the rotate gizmo. Entities only hold the 24 axis-aligned cube
// rotations, so a drag reports whole quarter turns: the returned basis is the
// (u, v, n) of the ring being dragged and 'steps' is how many turns of u toward
// v to apply since the last frame, which is usually zero.
gizmo_rotate :: (using state: *Gizmo_State, position: Vector3, cam: Camera, ray: Ray) -> (u: Vector3, v: Vector3, n: Vector3, steps: int) {
    len := max(length(cam.position - position) * GIZMO_SCALE, 0.001);

    mouse   := get_mouse_state(Key_Code.MOUSE_BUTTON_LEFT);
    pressed := (mouse & .START) != .NONE;
    held    := (mouse & .DOWN)  != .NONE;

    steps := 0;

    if active == .NONE {
        hover = gizmo_pick_ring(position, len, cam, ray);
        if hover != .NONE && pressed {
            ok, angle := gizmo_ring_angle(position, hover, ray);
            if ok {
                start_position = position;
                start_angle    = angle;
                applied_steps  = 0;
                active         = hover;
            }
        }
    } else if !held {
        active = .NONE;
    } else {
        ok, angle := gizmo_ring_angle(start_position, active, ray);
        if ok {
            // Wrap into (-180, 180] so passing the seam doesn't spin the object.
            delta := angle - start_angle;
            while delta >  PI  delta -= 2 * PI;
            while delta < -PI  delta += 2 * PI;
            total := cast(int) floor(delta / (PI * 0.5) + 0.5);
            steps = total - applied_steps;
            applied_steps = total;
        }
    }

    gizmo_draw_rings(position, len, cam, ifx active != .NONE then active else hover);

    handle := ifx active != .NONE then active else Gizmo_Handle.RING_Y;
    u, v := gizmo_plane_axes(handle);
    return u, v, gizmo_axis(handle), steps;
}

gizmo_axis :: (h: Gizmo_Handle) -> Vector3 {
    if h == {
        case .AXIS_X;   #through;
        case .PLANE_YZ; #through;
        case .RING_X;   return .{1, 0, 0};
        case .AXIS_Y;   #through;
        case .PLANE_XZ; #through;
        case .RING_Y;   return .{0, 1, 0};
        case; return .{0, 0, 1};
    }
}

gizmo_is_plane :: (h: Gizmo_Handle) -> bool {
    return h == .PLANE_YZ || h == .PLANE_XZ || h == .PLANE_XY;
}

gizmo_is_ring :: (h: Gizmo_Handle) -> bool {
    return h == .RING_X || h == .RING_Y || h == .RING_Z;
}

// The two in-plane axes of a plane or ring handle; gizmo_axis gives the third
// (the plane normal, or the axis the ring turns about).
gizmo_plane_axes :: (h: Gizmo_Handle) -> (u: Vector3, v: Vector3) {
    if h == {
        case .PLANE_YZ; #through;
        case .RING_X;   return .{0, 1, 0}, .{0, 0, 1};
        case .PLANE_XZ; #through;
        case .RING_Y;   return .{1, 0, 0}, .{0, 0, 1};
        case; return .{1, 0, 0}, .{0, 1, 0};
    }
}

// Handles are colored by their axis; plane handles by the axis they are
// perpendicular to, which is what gizmo_axis returns for them.
gizmo_color :: (h: Gizmo_Handle, highlighted: bool) -> Vector4 {
    if highlighted then return .{1.0, 0.85, 0.2, 1.0};
    axis := gizmo_axis(h);
    if axis.x != 0 then return .{0.95, 0.28, 0.30, 1.0};
    if axis.y != 0 then return .{0.40, 0.90, 0.32, 1.0};
    return .{0.30, 0.50, 0.98, 1.0};
}

#scope_file

// Parameter along the line (origin + axis*t) of the point closest to the ray,
// plus that point and the distance between the two lines at closest approach.
gizmo_closest_axis_t :: (ray: Ray, origin: Vector3, axis: Vector3) -> (t: float, point: Vector3, dist: float) {
    r := origin - ray.origin;
    a := dot(axis, axis);
    b := dot(axis, ray.direction);
    e := dot(ray.direction, ray.direction);
    c := dot(axis, r);
    f := dot(ray.direction, r);

    denom := a*e - b*b;
    if abs(denom) < 0.00001 then return 0, origin, 99999;  // ray parallel to the axis

    t := (b*f - c*e) / denom;
    s := (a*f - c*b) / denom;
    pa := origin + axis * t;
    pb := ray.origin + ray.direction * s;
    return t, pa, length(pa - pb);
}

gizmo_plane_hit :: (origin: Vector3, h: Gizmo_Handle, ray: Ray) -> (bool, Vector3) {
    n := gizmo_axis(h);
    denom := dot(n, ray.direction);
    if abs(denom) < 0.0001 then return false, .{};
    t := dot(n, origin - ray.origin) / denom;
    if t < 0 then return false, .{};  // plane is behind the camera
    return true, ray.origin + ray.direction * t;
}

// Which way each plane handle is offset from the origin: toward the camera, so
// the handles always sit in the octant facing the viewer.
gizmo_plane_signs :: (origin: Vector3, h: Gizmo_Handle, cam: Camera) -> (su: float, sv: float) {
    u, v := gizmo_plane_axes(h);
    to_cam := cam.position - origin;
    su := ifx dot(u, to_cam) >= 0 then cast(float)1 else cast(float)-1;
    sv := ifx dot(v, to_cam) >= 0 then cast(float)1 else cast(float)-1;
    return su, sv;
}

gizmo_pick :: (origin: Vector3, len: float, cam: Camera, ray: Ray) -> Gizmo_Handle {
    // Planes first: they sit closer to the origin and never overlap the arrows,
    // but grabbing a plane is the more common intent when they are near.
    for h: Gizmo_Handle.[.PLANE_YZ, .PLANE_XZ, .PLANE_XY] {
        n := gizmo_axis(h);
        if abs(dot(n, normalize(cam.position - origin))) < GIZMO_PLANE_MIN_FACING then continue;
        ok, point := gizmo_plane_hit(origin, h, ray);
        if !ok then continue;
        u, v := gizmo_plane_axes(h);
        su, sv := gizmo_plane_signs(origin, h, cam);
        d  := point - origin;
        cu := dot(d, u) * su;
        cv := dot(d, v) * sv;
        if cu >= GIZMO_PLANE_INNER * len && cu <= GIZMO_PLANE_OUTER * len
        && cv >= GIZMO_PLANE_INNER * len && cv <= GIZMO_PLANE_OUTER * len {
            return h;
        }
    }

    best      := Gizmo_Handle.NONE;
    best_dist := GIZMO_PICK_RADIUS * len;
    for h: Gizmo_Handle.[.AXIS_X, .AXIS_Y, .AXIS_Z] {
        t, _, dist := gizmo_closest_axis_t(ray, origin, gizmo_axis(h));
        if t < 0 || t > len then continue;
        if dist < best_dist {
            best_dist = dist;
            best      = h;
        }
    }
    return best;
}

gizmo_draw :: (origin: Vector3, len: float, cam: Camera, highlighted: Gizmo_Handle) {
    for h: Gizmo_Handle.[.PLANE_YZ, .PLANE_XZ, .PLANE_XY] {
        n := gizmo_axis(h);
        if abs(dot(n, normalize(cam.position - origin))) < GIZMO_PLANE_MIN_FACING then continue;
        u, v := gizmo_plane_axes(h);
        su, sv := gizmo_plane_signs(origin, h, cam);
        col := gizmo_color(h, h == highlighted);
        gizmo_draw_plane(origin, u * su, v * sv, GIZMO_PLANE_INNER * len, GIZMO_PLANE_OUTER * len, col, h == highlighted);
    }

    for h: Gizmo_Handle.[.AXIS_X, .AXIS_Y, .AXIS_Z] {
        gizmo_draw_arrow(origin, gizmo_axis(h) * len, gizmo_color(h, h == highlighted));
    }
}

gizmo_draw_arrow :: (origin: Vector3, vec: Vector3, col: Vector4) {
    tip   := origin + vec;
    shaft := normalize(vec);
    debug_line_overlay(origin, tip, col, GIZMO_LINE_WIDTH);

    head := length(vec) * 0.18;
    back := tip - shaft * head;
    perp : Vector3;
    if abs(shaft.x) < 0.9 {
        perp = normalize(cross(shaft, .{1, 0, 0}));
    } else {
        perp = normalize(cross(shaft, .{0, 1, 0}));
    }
    perp2 := cross(shaft, perp);
    w1 := perp  * (head * 0.4);
    w2 := perp2 * (head * 0.4);
    // Four fins plus a ring, so the head reads as a cone from any angle.
    debug_line_overlay(back + w1, tip, col, GIZMO_LINE_WIDTH);
    debug_line_overlay(back - w1, tip, col, GIZMO_LINE_WIDTH);
    debug_line_overlay(back + w2, tip, col, GIZMO_LINE_WIDTH);
    debug_line_overlay(back - w2, tip, col, GIZMO_LINE_WIDTH);
    debug_line_overlay(back + w1, back + w2, col, GIZMO_LINE_WIDTH);
    debug_line_overlay(back + w2, back - w1, col, GIZMO_LINE_WIDTH);
    debug_line_overlay(back - w1, back - w2, col, GIZMO_LINE_WIDTH);
    debug_line_overlay(back - w2, back + w1, col, GIZMO_LINE_WIDTH);
}

// A square in the (u, v) plane between inner and outer, outlined at full alpha
// and hatched at low alpha so it reads as a translucent pane.
gizmo_draw_plane :: (origin: Vector3, u: Vector3, v: Vector3, inner: float, outer: float, col: Vector4, filled: bool) {
    p00 := origin + u * inner + v * inner;
    p10 := origin + u * outer + v * inner;
    p11 := origin + u * outer + v * outer;
    p01 := origin + u * inner + v * outer;
    debug_line_overlay(p00, p10, col, GIZMO_LINE_WIDTH);
    debug_line_overlay(p10, p11, col, GIZMO_LINE_WIDTH);
    debug_line_overlay(p11, p01, col, GIZMO_LINE_WIDTH);
    debug_line_overlay(p01, p00, col, GIZMO_LINE_WIDTH);

    fill := col;
    fill.w = ifx filled then 0.55 else 0.18;
    // Enough hatch lines that the pane reads as filled rather than striped.
    HATCH :: 14;
    for i: 1..HATCH {
        f := cast(float)i / cast(float)(HATCH + 1);
        c := inner + (outer - inner) * f;
        debug_line_overlay(origin + u * c + v * inner, origin + u * c + v * outer, fill, GIZMO_FILL_WIDTH);
    }
}

// Angle of the mouse ray's hit on the ring's plane, measured from u toward v.
gizmo_ring_angle :: (origin: Vector3, h: Gizmo_Handle, ray: Ray) -> (ok: bool, angle: float) {
    ok, point := gizmo_plane_hit(origin, h, ray);
    if !ok then return false, 0;
    u, v := gizmo_plane_axes(h);
    d := point - origin;
    return true, atan2(dot(d, v), dot(d, u));
}

gizmo_pick_ring :: (origin: Vector3, len: float, cam: Camera, ray: Ray) -> Gizmo_Handle {
    best      := Gizmo_Handle.NONE;
    best_dist := GIZMO_RING_PICK * len;
    for h: Gizmo_Handle.[.RING_X, .RING_Y, .RING_Z] {
        if !gizmo_ring_faces_camera(origin, h, cam) then continue;
        ok, point := gizmo_plane_hit(origin, h, ray);
        if !ok then continue;
        // Distance from the ring itself, not from its centre.
        off := abs(length(point - origin) - GIZMO_RING_RADIUS * len);
        if off < best_dist {
            best_dist = off;
            best      = h;
        }
    }
    return best;
}

// An edge-on ring is a line on screen: impossible to aim at, and its plane
// intersection shoots off to infinity, so skip it.
gizmo_ring_faces_camera :: (origin: Vector3, h: Gizmo_Handle, cam: Camera) -> bool {
    return abs(dot(gizmo_axis(h), normalize(cam.position - origin))) >= GIZMO_PLANE_MIN_FACING;
}

gizmo_draw_rings :: (origin: Vector3, len: float, cam: Camera, highlighted: Gizmo_Handle) {
    for h: Gizmo_Handle.[.RING_X, .RING_Y, .RING_Z] {
        is_hot := h == highlighted;
        if !gizmo_ring_faces_camera(origin, h, cam) && !is_hot then continue;
        u, v := gizmo_plane_axes(h);
        col  := gizmo_color(h, is_hot);
        r    := GIZMO_RING_RADIUS * len;
        prev := origin + u * r;
        for i: 1..GIZMO_RING_SEGMENTS {
            a    := (cast(float)i / cast(float)GIZMO_RING_SEGMENTS) * 2 * PI;
            next := origin + u * (cos(a) * r) + v * (sin(a) * r);
            debug_line_overlay(prev, next, col, GIZMO_LINE_WIDTH);
            prev = next;
        }
    }
}

#if FLAG_TEST_ENGINE {
    gizmo_test_cam :: () -> Camera {
        // Off the +X+Y+Z octant, so every plane handle faces the viewer and its
        // signs are all positive.
        cam : Camera;
        cam.position = .{5, 5, 5};
        cam.target   = .{0, 0, 0};
        return cam;
    }

    test_gizmo_closest_axis :: () {
        s := begin_suite("gizmo closest point on axis");
        // Vertical ray dropping onto the +X axis at x = 0.5.
        ray := Ray.{ origin = .{0.5, 3, 0}, direction = .{0, -1, 0} };
        t, point, dist := gizmo_closest_axis_t(ray, .{0, 0, 0}, .{1, 0, 0});
        check(*s, "t is the distance along the axis",  abs(t - 0.5) < 0.001);
        check(*s, "closest point sits on the axis",    abs(point.x - 0.5) < 0.001 && abs(point.y) < 0.001 && abs(point.z) < 0.001);
        check(*s, "intersecting lines have 0 distance", dist < 0.001);

        // A ray offset in Z never meets the axis; the gap is that offset.
        off := Ray.{ origin = .{0.5, 3, 0.25}, direction = .{0, -1, 0} };
        _, _, off_dist := gizmo_closest_axis_t(off, .{0, 0, 0}, .{1, 0, 0});
        check(*s, "offset ray reports its offset as distance", abs(off_dist - 0.25) < 0.001);

        // Parallel lines have no unique closest point.
        par := Ray.{ origin = .{0, 3, 0}, direction = .{1, 0, 0} };
        _, _, par_dist := gizmo_closest_axis_t(par, .{0, 0, 0}, .{1, 0, 0});
        check(*s, "parallel ray is rejected", par_dist > 1000);
        end_suite(s);
    }

    test_gizmo_pick :: () {
        s   := begin_suite("gizmo handle picking");
        cam := gizmo_test_cam();
        len : float : 1.0;

        // Straight down onto the middle of the +X arrow.
        axis_ray := Ray.{ origin = .{0.5, 3, 0}, direction = .{0, -1, 0} };
        check(*s, "aiming at the X arrow picks AXIS_X", gizmo_pick(.{0,0,0}, len, cam, axis_ray) == .AXIS_X);

        // Down onto the XZ pane, which spans 0.22..0.52 on both of its axes.
        plane_ray := Ray.{ origin = .{0.35, 3, 0.35}, direction = .{0, -1, 0} };
        check(*s, "aiming at the XZ pane picks PLANE_XZ", gizmo_pick(.{0,0,0}, len, cam, plane_ray) == .PLANE_XZ);

        // Inside the pane's plane but short of its inner edge: no handle there.
        gap_ray := Ray.{ origin = .{0.1, 3, 0.1}, direction = .{0, -1, 0} };
        check(*s, "the gap inside the panes picks nothing", gizmo_pick(.{0,0,0}, len, cam, gap_ray) == .NONE);

        // Past the end of every arrow.
        miss_ray := Ray.{ origin = .{2, 3, 2}, direction = .{0, -1, 0} };
        check(*s, "aiming past the gizmo picks nothing", gizmo_pick(.{0,0,0}, len, cam, miss_ray) == .NONE);

        // Picking follows the gizmo, not the world origin.
        moved := Vector3.{10, 4, -7};
        moved_ray := Ray.{ origin = moved + Vector3.{0.5, 3, 0}, direction = .{0, -1, 0} };
        check(*s, "picking is relative to the gizmo origin", gizmo_pick(moved, len, cam, moved_ray) == .AXIS_X);
        end_suite(s);
    }

    test_gizmo_plane_hit :: () {
        s := begin_suite("gizmo plane intersection");
        // PLANE_XZ has a +Y normal, so it is the horizontal plane through the origin.
        ray := Ray.{ origin = .{1, 4, 2}, direction = .{0, -1, 0} };
        ok, point := gizmo_plane_hit(.{0, 0, 0}, .PLANE_XZ, ray);
        check(*s, "downward ray hits the XZ pane's plane", ok);
        check(*s, "hit lands at the ray's XZ",             abs(point.x - 1) < 0.001 && abs(point.z - 2) < 0.001);
        check(*s, "hit lands on the plane",                abs(point.y) < 0.001);

        // The plane passes through the gizmo origin, not the world origin.
        shifted, sp := gizmo_plane_hit(.{0, 2.5, 0}, .PLANE_XZ, ray);
        check(*s, "plane follows the gizmo origin", shifted && abs(sp.y - 2.5) < 0.001);

        away := Ray.{ origin = .{1, 4, 2}, direction = .{0, 1, 0} };
        no_hit, _ := gizmo_plane_hit(.{0, 0, 0}, .PLANE_XZ, away);
        check(*s, "ray pointing away misses", !no_hit);
        end_suite(s);
    }

    #run {
        test_gizmo_closest_axis();
        test_gizmo_pick();
        test_gizmo_plane_hit();
    }
}
