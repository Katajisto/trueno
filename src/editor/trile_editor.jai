#scope_file
rotation : float = 0.0;
tilt     : float = 0.0;
zoom     : float = 3.0;

brush_radius   : int = 5;

hovered_trixel_x : int = -1;
hovered_trixel_y : int = -1;
hovered_trixel_z : int = -1;
hovered_trixel_normal : Vector3;


TRILE_ROTATION_SPEED :: 2.0;

Trile_Editor_Tab :: enum {
    TOOLSET;
    METADATA;
    MATERIAL;  
};

Trile_Editor_Tool :: enum {
    PAINT;
    ADD;
    REMOVE;
}

Trile_Editor_Tool_Mode :: enum {
    POINT;
    BRUSH;
    AREA;
}

current_tab  : Trile_Editor_Tab       = .TOOLSET;
current_tool : Trile_Editor_Tool      = .PAINT;
current_mode : Trile_Editor_Tool_Mode = .AREA;

tiling_preview_active        : bool;
tiling_axis                  : s32 = 0;  // 0=+X, 1=+Z, 2=-X, 3=-Z
tiling_orientation           : s32 = 0;  // 0-23 = face(0..5)*4 + twist(0..3)
tiling_neighbor_trile_name   : string;
tiling_neighbor_trile_input  : string;

UNDO_MAX :: 32;
undo_trixels : [UNDO_MAX][16][16][16]u8;
undo_count   : int = 0;
undo_head    : int = 0;
redo_trixels : [UNDO_MAX][16][16][16]u8;
redo_count   : int = 0;
redo_head    : int = 0;

meta_name_input : string;

#scope_export

ntrile :: (name: string) {
    trile_changed(editor_current_trile);
    newt : Trile;
    newt.name = sprint("%", name);
    set_trile(newt.name, newt);
    editor_current_trile = get_trile(newt.name);
    trile_gen_heightmap(editor_current_trile);
} @Command

cpytrile :: (trile: string, destination: string) {
    trile_changed(editor_current_trile);
    newt : Trile;
    newt.name = sprint("%", destination);
    newt.trixels = get_trile(trile).trixels;
    set_trile(newt.name, newt);
    editor_current_trile = get_trile(newt.name);
    trile_gen_heightmap(editor_current_trile);
} @Command

ltrile :: (name: string) {
    trile_changed(editor_current_trile);
    nt := get_trile(name);
    if !nt {
        console_add_output_line("Failed to load a trile with that name...");
        return;    
    }
    editor_current_trile = nt;
    trile_gen_heightmap(editor_current_trile);
} @Command

#scope_file

push_undo :: () {
    if !editor_current_trile return;
    undo_trixels[undo_head] = editor_current_trile.trixels;
    undo_head  = (undo_head + 1) % UNDO_MAX;
    undo_count = min(undo_count + 1, UNDO_MAX);
    redo_count = 0;
    redo_head  = 0;
}

do_undo :: () {
    if undo_count == 0 || !editor_current_trile return;
    redo_trixels[redo_head] = editor_current_trile.trixels;
    redo_head  = (redo_head + 1) % UNDO_MAX;
    redo_count = min(redo_count + 1, UNDO_MAX);
    undo_head  = (undo_head - 1 + UNDO_MAX) % UNDO_MAX;
    undo_count -= 1;
    editor_current_trile.trixels = undo_trixels[undo_head];
    trile_gen_heightmap(editor_current_trile);
    trile_changed(editor_current_trile);
}

do_redo :: () {
    if redo_count == 0 || !editor_current_trile return;
    undo_trixels[undo_head] = editor_current_trile.trixels;
    undo_head  = (undo_head + 1) % UNDO_MAX;
    undo_count = min(undo_count + 1, UNDO_MAX);
    redo_head  = (redo_head - 1 + UNDO_MAX) % UNDO_MAX;
    redo_count -= 1;
    editor_current_trile.trixels = redo_trixels[redo_head];
    trile_gen_heightmap(editor_current_trile);
    trile_changed(editor_current_trile);
}

apply_tool_to_trixel :: (x: s64, y: s64, z: s64) {
    trixel := *editor_current_trile.trixels[x][y][z];
    if current_tool == {
        case .PAINT;  if trixel.* != 0  trixel.* = current_swatch;
        case .ADD;    if trixel.* == 0  trixel.* = current_swatch;
        case .REMOVE; trixel.* = 0;
    }
}

area_start_x : int;
area_start_y : int;
area_start_z : int;
area_active  : bool;

handle_tool_click :: () {
    if hovered_trixel_x < 0 && hovered_trixel_y < 0 && hovered_trixel_z < 0 then return;
    if current_mode == .POINT {
        push_undo();
        if current_tool == .ADD {
            nx := hovered_trixel_x + cast(int) hovered_trixel_normal.x;
            ny := hovered_trixel_y + cast(int) hovered_trixel_normal.y;
            nz := hovered_trixel_z + cast(int) hovered_trixel_normal.z;
            if nx >= 0 && nx < 16 && ny >= 0 && ny < 16 && nz >= 0 && nz < 16 {
                apply_tool_to_trixel(nx, ny, nz);
            }
        } else {
            apply_tool_to_trixel(hovered_trixel_x, hovered_trixel_y, hovered_trixel_z);
        }
    }
    if current_mode == .BRUSH {
        push_undo();
        is_in_radius :: (point : Vector3, radius: float) -> bool {
            center : Vector3 = .{xx hovered_trixel_x, xx hovered_trixel_y, xx hovered_trixel_z};
            return length(point - center) <= radius;
        }

        for x: 0..15 {
            for y: 0..15 {
                for z: 0..15 {
                    if is_in_radius(.{xx x, xx y, xx z}, xx brush_radius) {
                        apply_tool_to_trixel(x,y,z);
                    }
                }
            }
        }
    }
    if current_mode == .AREA {
        if area_active {
            push_undo();
            // Apply tool to all trixels in the area.
            for x: min(area_start_x, hovered_trixel_x)..max(hovered_trixel_x, area_start_x) {
                for y: min(area_start_y, hovered_trixel_y)..max(hovered_trixel_y, area_start_y) {
                    for z: min(area_start_z, hovered_trixel_z)..max(hovered_trixel_z, area_start_z) {
                        apply_tool_to_trixel(x,y,z);
                    }
                }
            }
            area_active = false;
        } else {
            area_active = true;
            area_start_x = hovered_trixel_x;
            area_start_y = hovered_trixel_y;
            area_start_z = hovered_trixel_z;
        }
    }
    trile_gen_heightmap(editor_current_trile);
}

#scope_export

current_swatch : u8 = 1;

reset_trile :: () {
    for x: 0..15 {
        for y: 0..15 {
            for z: 0..15 {
                editor_current_trile.trixels[x][y][z] = current_swatch;
            }
        }
    }
    trile_gen_heightmap(editor_current_trile);
} @Command

trile_copy :: (from: string) {
    src := get_trile(from);
    for x: 0..15 {
        for y: 0..15 {
            for z: 0..15 {
                editor_current_trile.trixels[x][y][z] = src.trixels[x][y][z];
            }
        }
    }
    trile_gen_heightmap(editor_current_trile);
} @Command

tick_trile_editor :: () {
    if console_open_ignore_input then return;

    if !editor_current_trile then editor_current_trile = get_any_trile();

    if input_button_states[Key_Code.MOUSE_BUTTON_LEFT] & .START {
        handle_tool_click();
        trile_changed(editor_current_trile);
    }

    mindist : float = 999999;
    hovered_trixel_x = -1;
    hovered_trixel_y = -1;
    hovered_trixel_z = -1;

    for x: 0..15 {
        for y: 0..15 {
            for z: 0..15 {
                if editor_current_trile.trixels[x][y][z] == 0 then continue;

                cube : Collision_Cube;
                cube.position = Vector3.{cast(float) x, cast(float) y, cast(float) z} * TRIXEL_SIZE;
                cube.size     = Vector3.{1,1,1} * TRIXEL_SIZE;

                ray := get_mouse_ray(*get_trile_editor_camera());
                collision := does_ray_hit_cube(ray, cube);
                if collision.hit && collision.distance < mindist {
                    mindist = collision.distance;
                    hovered_trixel_x = x;
                    hovered_trixel_y = y;
                    hovered_trixel_z = z;
                    hovered_trixel_normal = collision.normal;
                }
            }
        }
    }

    if hovered_trixel_x >= 0 {
        lo := Vector3.{xx hovered_trixel_x, xx hovered_trixel_y, xx hovered_trixel_z};
        hi := lo;
        if current_mode == .BRUSH {
            lo -= Vector3.{1, 1, 1} * cast(float) brush_radius;
            hi += Vector3.{1, 1, 1} * cast(float) brush_radius;
        } else if current_mode == .AREA && area_active {
            corner := Vector3.{xx area_start_x, xx area_start_y, xx area_start_z};
            lo = min(lo, corner);
            hi = max(hi, corner);
        }
        debug_aabb_3d_overlay(lo * TRIXEL_SIZE, (hi + Vector3.{1, 1, 1}) * TRIXEL_SIZE, .{0.9, 0.1, 0.1, 1});
    }

    if !input_button_states[Key_Code.CTRL] & .DOWN {
        if input_button_states[#char "D"] & .DOWN {
            rotation += TRILE_ROTATION_SPEED * cast(float) delta_time;
        }
        if input_button_states[#char "A"] & .DOWN {
            rotation -= TRILE_ROTATION_SPEED * cast(float) delta_time;
        }
        if input_button_states[#char "W"] & .DOWN {
            tilt += TRILE_ROTATION_SPEED * cast(float) delta_time;
        }
        if input_button_states[#char "S"] & .DOWN {
            tilt -= TRILE_ROTATION_SPEED * cast(float) delta_time;
        }
    }

    trile_editor_shortcuts();
    
    tilt = clamp(tilt, -(PI/2.0) + 0.01, PI/2.0 - 0.01);
    max_zoom := ifx tiling_preview_active then 5.0 else 3.0;
    zoom = clamp(zoom + mouse_delta_z * -0.2, 1.0, max_zoom);

    cam := get_trile_editor_camera();
    ray := get_mouse_ray(*cam);
}

get_trile_editor_camera :: () -> Camera {
    camera: Camera;
    camera.near = 0.1;
    camera.far = 5000;

    cameraDir : Vector3    = .{1, 0, 0};
    qrotation : Quaternion = .{cos(rotation/2.0),0,sin(rotation/2.0),0};
    qtilt     : Quaternion = .{cos(tilt/2.0),sin(tilt/2.0), 0, 0};

    rotate(*cameraDir, qrotation * qtilt);
    target := ifx tiling_preview_active then get_tiling_camera_target() else Vector3.{0.5, 0.5, 0.5};
    camera.position = target;

    camera.position += cameraDir * zoom;
    camera.target = target;
    
    return camera;
}

swatch_scroll : float = 0.0;

draw_tool_tab :: (theme: *GR.Overall_Theme, area: GR.Rect) {
    r := area;
    r.h = ui_h(4, 0);
    if keybind_button(r, "Paint",  .TRIXEL_TOOL_PAINT,  *t_button_selectable(theme, current_tool == .PAINT))  then current_tool = .PAINT;
    r.y += r.h;
    if keybind_button(r, "Add",    .TRIXEL_TOOL_ADD,    *t_button_selectable(theme, current_tool == .ADD))    then current_tool = .ADD;
    r.y += r.h;
    if keybind_button(r, "Remove", .TRIXEL_TOOL_REMOVE, *t_button_selectable(theme, current_tool == .REMOVE)) then current_tool = .REMOVE;
    r.y += r.h * 3;
    if keybind_button(r, "Point",  .TRIXEL_MODE_POINT,  *t_button_selectable(theme, current_mode == .POINT))  then current_mode = .POINT;
    r.y += r.h;
    if keybind_button(r, "Area",   .TRIXEL_MODE_AREA,   *t_button_selectable(theme, current_mode == .AREA))   then current_mode = .AREA;
    r.y += r.h;
    if keybind_button(r, "Brush",  .TRIXEL_MODE_BRUSH,  *t_button_selectable(theme, current_mode == .BRUSH))  then current_mode = .BRUSH;

    r.y += r.h;
    GR.slider(r, *brush_radius, 0, 12, 1, *theme.slider_theme);
    r.y += r.h * 2;
    if keybind_button(r, "Save and gen", .SAVE, *theme.button_theme) {
        trile_changed(editor_current_trile);
        striles();
        update_trile_thumbnail(editor_current_trile.name);
    };
}

draw_material_tab :: (theme: *GR.Overall_Theme, area: GR.Rect) {
    region, inside := GR.begin_scrollable_region(area, *theme.scrollable_region_theme);
    end_y := draw_swatch_grid(inside, *swatch_scroll, *current_swatch, theme);
    GR.end_scrollable_region(region, inside.x + inside.w, end_y, *swatch_scroll);
}

// Shared with the material studio. Returns the bottom of the grid.
draw_swatch_grid :: (inside: GR.Rect, scroll: *float, selected: *u8, theme: *GR.Overall_Theme) -> float {
    block := ui_h(3, 2);
    cols  := max(1, cast(int)(inside.w / block));
    n := 0;
    for g_swatches {
        if !it.used  continue;
        r := GR.Rect.{inside.x + (n % cols) * block, inside.y - scroll.* + (n / cols) * block, block, block};
        btn := t_button_selectable(theme, selected.* == it_index);
        c := swatch_color(cast(u8) it_index);
        btn.surface_color = .{c.x, c.y, c.z, 1};
        if GR.button(r, "", *btn, cast(s32) it_index)  selected.* = cast(u8) it_index;
        n += 1;
    }
    return inside.y + ((n + cols - 1) / cols) * block;
}

TILING_AXIS_NAMES :: string.["+ X", "+ Z", "- X", "- Z", "+ Y", "- Y"];

get_tiling_world_offset :: () -> Vector3 {
    if tiling_axis == 0  return .{ 1,  0,  0};
    if tiling_axis == 1  return .{ 0,  0,  1};
    if tiling_axis == 2  return .{-1,  0,  0};
    if tiling_axis == 3  return .{ 0,  0, -1};
    if tiling_axis == 4  return .{ 0,  1,  0};
                         return .{ 0, -1,  0};
}

get_tiling_camera_target :: () -> Vector3 {
    off := get_tiling_world_offset();
    return Vector3.{0.5, 0.5, 0.5} + off * 0.5;
}

get_tiling_neighbor_trile :: () -> *Trile {
    if tiling_neighbor_trile_name.count > 0 {
        t := get_trile(tiling_neighbor_trile_name);
        if t  return t;
    }
    return editor_current_trile;
}

draw_trile_editor :: () {
    // A trile is drawn in the light of the world it will sit in.
    environment := New(Environment,, temp);
    curworld := get_current_world();
    if curworld.valid  environment = world_environment(*curworld.world);

    view := add_view(.{camera = get_trile_editor_camera(), environment = environment, draw_world = false});
    mesh, ok := get_trile_mesh(editor_current_trile.name);
    if ok  draw_trile(view, mesh, .{}, 0);
    if tiling_preview_active {
        neighbor, neighbor_ok := get_trile_mesh(get_tiling_neighbor_trile().name);
        if neighbor_ok  draw_trile(view, neighbor, get_tiling_world_offset(), xx tiling_orientation);
    }
}

trile_editor_shortcuts :: () {
    if is_action_start(Editor_Action.TRIXEL_UNDO) then do_undo();
    if is_action_start(Editor_Action.TRIXEL_REDO) then do_redo();
}

draw_meta_tab :: (theme: *GR.Overall_Theme, area: GR.Rect) {
    if !editor_current_trile return;
    r     := area;
    row_h := ui_h(4, 0);

    r.h = row_h;
    GR.label(r, "Name", *t_label_left(theme));
    r.y += row_h;

    r.h = row_h;
    a, new_text, text_state := GR.text_input(r, meta_name_input, *theme.text_input_theme, 128);
    if a & .ENTERED  meta_name_input = copy_string(new_text);
    current_name := ifx text_state then text_state.text else meta_name_input;
    r.y += row_h;

    r.h = row_h;
    if GR.button(r, "Rename", *theme.button_theme) && current_name.count > 0 {
        old := copy_string(editor_current_trile.name,, temp);
        rename_trile(old, current_name);
        meta_name_input = copy_string(current_name);
        if editor_current_trile  update_trile_thumbnail(editor_current_trile.name);
        striles();
    }
    r.y += row_h * 2;

    r.h = row_h;
    changed := GR.base_checkbox(r, "Opaque (occludes neighbors)", editor_current_trile.is_opaque, *theme.checkbox_theme);
    if changed  editor_current_trile.is_opaque = !editor_current_trile.is_opaque;
    r.y += row_h;
    changed = GR.base_checkbox(r, "Skip collision", editor_current_trile.skip_collision, *theme.checkbox_theme);
    if changed  editor_current_trile.skip_collision = !editor_current_trile.skip_collision;
    r.y += row_h;
    changed = GR.base_checkbox(r, "Is stairs", editor_current_trile.is_stairs, *theme.checkbox_theme);
    if changed  editor_current_trile.is_stairs = !editor_current_trile.is_stairs;
    r.y += row_h * 2;

    r.h = row_h;
    if GR.button(r, "Delete trile", *theme.button_theme) {
        name_copy := copy_string(editor_current_trile.name,, temp);
        delete_trile(name_copy);
        undo_count = 0; undo_head = 0; redo_count = 0; redo_head = 0;
        striles();
        return;
    }
    r.y += row_h * 2;

    r.h = row_h;
    half := r.w / 2.0;
    ur := r; ur.w = half;
    rr := r; rr.x = r.x + half; rr.w = r.w - half;
    if GR.button(ur, tprint("Undo (%)", undo_count), *theme.button_theme)  do_undo();
    if GR.button(rr, tprint("Redo (%)", redo_count), *theme.button_theme)  do_redo();
}

draw_trile_editor_ui :: (theme: *GR.Overall_Theme) {
    r := GR.get_rect(0, ui_h(5,0), ui_w(20, 20), ui_h(95, 0));
	ui_add_mouse_occluder(r);
    draw_bg_rectangle(r, theme);
    tab_r := r;
    tab_r.h = ui_h(3,0);
    tab_r.w = ui_w(20, 20) / 3;

    if keybind_button(tab_r, "Tools",    .TRIXEL_TAB_TOOLS,    *t_button_tab(theme, current_tab == .TOOLSET))  then current_tab = .TOOLSET;
    tab_r.x += tab_r.w;
    if keybind_button(tab_r, "Material", .TRIXEL_TAB_MATERIAL, *t_button_tab(theme, current_tab == .MATERIAL)) then current_tab = .MATERIAL;
    tab_r.x += tab_r.w;
    if keybind_button(tab_r, "Meta",     .TRIXEL_TAB_INFO,     *t_button_tab(theme, current_tab == .METADATA)) {
        current_tab = .METADATA;
        if editor_current_trile  meta_name_input = copy_string(editor_current_trile.name);
    }

    r.y += tab_r.h;

    if current_tab == {
        case .MATERIAL;
            draw_material_tab(theme, r);
        case .TOOLSET;
            draw_tool_tab(theme, r);
        case .METADATA;
            draw_meta_tab(theme, r);
    }

    draw_picker(theme);

    // View mode buttons — bottom center of the 3D viewport.
    btn_w  := 11.0 * vw;
    btn_h  := cast(float) ui_h(4, 0);
    bar_w  := btn_w * 3.0;
    bar_x  := 100.0 * vw / 2.0 - bar_w / 2.0;
    bar_y  := 100.0 * vh - btn_h - 1.5 * vh;

    bar_r : GR.Rect;
    bar_r.x = bar_x; bar_r.y = bar_y; bar_r.w = bar_w; bar_r.h = btn_h;
    ui_add_mouse_occluder(bar_r);

    r2 : GR.Rect;
    r2.x = bar_x; r2.y = bar_y; r2.w = btn_w; r2.h = btn_h;
    if keybind_button(r2, "Tile", .TRIXEL_VIEW_TILE, *t_button_selectable(theme, tiling_preview_active)) {
        tiling_preview_active = !tiling_preview_active;
    }

    if tiling_preview_active {
        ctrl_w  := bar_w / 3.0;
        ctrl_y  := bar_y - btn_h - 0.5 * vh;
        ctrl_r  : GR.Rect;
        ctrl_r.y = ctrl_y; ctrl_r.h = btn_h;

        tiling_bar_r : GR.Rect;
        tiling_bar_r.x = bar_x; tiling_bar_r.y = ctrl_y; tiling_bar_r.w = bar_w; tiling_bar_r.h = btn_h;
        ui_add_mouse_occluder(tiling_bar_r);

        // Axis cycle button (Q)
        ctrl_r.x = bar_x; ctrl_r.w = ctrl_w;
        axis_label := tprint("Axis: %", TILING_AXIS_NAMES[tiling_axis]);
        if keybind_button(ctrl_r, axis_label, .TRIXEL_TILING_AXIS, *theme.button_theme) {
            tiling_axis = (tiling_axis + 1) % 6;
        }

        // Orientation cycle button (R) — cycles through all 24 face*twist orientations
        ctrl_r.x = bar_x + ctrl_w; ctrl_r.w = ctrl_w;
        ori_label := tprint("F% T%", tiling_orientation / 4, tiling_orientation % 4);
        if keybind_button(ctrl_r, ori_label, .TRIXEL_TILING_ROTATE, *theme.button_theme) {
            tiling_orientation = (tiling_orientation + 1) % 24;
        }

        // Neighbor trile text input
        ctrl_r.x = bar_x + ctrl_w * 2.0; ctrl_r.w = ctrl_w;
        a, new_text, _ := GR.text_input(ctrl_r, tiling_neighbor_trile_input, *theme.text_input_theme, 600);
        if a & .TEXT_MODIFIED  tiling_neighbor_trile_input = copy_string(new_text);
        if a & .ENTERED {
            tiling_neighbor_trile_input = copy_string(new_text);
            tiling_neighbor_trile_name  = tiling_neighbor_trile_input;
        }
    }
}
