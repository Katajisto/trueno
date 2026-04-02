#scope_file
rotation : float = 0.0;
tilt     : float = 0.0;
zoom     : float = 3.0;

brush_radius   : int = 5;

roughness : u8 = 0;
metallic  : u8 = 0;
emittance : u8 = 0;

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

colorMuls : [16][16][16]Vector3;
tiling_preview_active        : bool;
tiling_axis                  : s32 = 0;  // 0=+X, 1=+Z, 2=-X, 3=-Z
tiling_orientation           : s32 = 0;  // 0-23 = face(0..5)*4 + twist(0..3)
tiling_neighbor_trile_name   : string;
tiling_neighbor_trile_input  : string;

UNDO_MAX :: 32;
undo_trixels : [UNDO_MAX][16][16][16] Trixel;
undo_count   : int = 0;
undo_head    : int = 0;
redo_trixels : [UNDO_MAX][16][16][16] Trixel;
redo_count   : int = 0;
redo_head    : int = 0;

meta_name_input : string;

#scope_export

ntrile :: (name: string) {
    set_trile_gfx(editor_current_trile.name, generate_trile_gfx_matias(editor_current_trile));
    newt : Trile;
    newt.name = sprint("%", name);
    set_trile(newt.name, newt);
    editor_current_trile = get_trile(newt.name);
} @Command

cpytrile :: (trile: string, destination: string) {
    set_trile_gfx(editor_current_trile.name, generate_trile_gfx_matias(editor_current_trile));
    newt : Trile;
    newt.name = sprint("%", destination);
    newt.trixels = get_trile(trile).trixels;
    set_trile(newt.name, newt);
    editor_current_trile = get_trile(newt.name);
} @Command

ltrile :: (name: string) {
    set_trile_gfx(editor_current_trile.name, generate_trile_gfx_matias(editor_current_trile));
    nt := get_trile(name);
    if !nt {
        console_add_output_line("Failed to load a trile with that name...");
        return;    
    }
    editor_current_trile = nt;
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
}

do_redo :: () {
    if redo_count == 0 || !editor_current_trile return;
    undo_trixels[undo_head] = editor_current_trile.trixels;
    undo_head  = (undo_head + 1) % UNDO_MAX;
    undo_count = min(undo_count + 1, UNDO_MAX);
    redo_head  = (redo_head - 1 + UNDO_MAX) % UNDO_MAX;
    redo_count -= 1;
    editor_current_trile.trixels = redo_trixels[redo_head];
}

apply_tool_to_trixel :: (x: s64, y: s64, z: s64) {
    if current_tool == .PAINT {
        editor_current_trile.trixels[x][y][z].material.color = current_color;
        editor_current_trile.trixels[x][y][z].material.metallic = metallic;
        editor_current_trile.trixels[x][y][z].material.roughness = roughness;
        editor_current_trile.trixels[x][y][z].material.emittance = emittance;
    }
    if current_tool == .ADD {
        editor_current_trile.trixels[x][y][z].empty = false;
    }
    if current_tool == .REMOVE {
        editor_current_trile.trixels[x][y][z].empty = true;
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
    
}

#scope_export

current_color : Vector3 = .{1.0, 0.0, 0.0};

reset_trile :: () {
    for x: 0..15 {
        for y: 0..15 {
            for z: 0..15 {
                editor_current_trile.trixels[x][y][z].empty = false;
            }
        }
    }
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
} @Command

tick_trile_editor :: () {
    if console_open_ignore_input then return;

    if !editor_current_trile then editor_current_trile = get_trile("test");

    if input_button_states[Key_Code.MOUSE_BUTTON_LEFT] & .START {
        handle_tool_click();
    }

    mindist : float = 999999;
    hovered_trixel_x = -1;
    hovered_trixel_y = -1;
    hovered_trixel_z = -1;

    for x: 0..15 {
        for y: 0..15 {
            for z: 0..15 {
                t := editor_current_trile.trixels[x][y][z];
                if t.empty then continue;

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

    for x: 0..15 {
        for y: 0..15 {
            for z: 0..15 {
                highlighted := false;
                if hovered_trixel_x >= 0 {
                    if current_mode == .BRUSH {
                        center : Vector3 = .{xx hovered_trixel_x, xx hovered_trixel_y, xx hovered_trixel_z};
                        highlighted = length(Vector3.{xx x, xx y, xx z} - center) <= xx brush_radius;
                    } else if current_mode == .AREA && area_active {
                        highlighted = x >= min(area_start_x, hovered_trixel_x) && x <= max(area_start_x, hovered_trixel_x)
                                   && y >= min(area_start_y, hovered_trixel_y) && y <= max(area_start_y, hovered_trixel_y)
                                   && z >= min(area_start_z, hovered_trixel_z) && z <= max(area_start_z, hovered_trixel_z);
                    } else {
                        highlighted = x == hovered_trixel_x && y == hovered_trixel_y && z == hovered_trixel_z;
                    }
                }
                colorMuls[x][y][z] = ifx highlighted then Vector3.{0.6, 0.0, 0.0} else .{1.0, 1.0, 1.0};
            }
        }
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

global_palette_scroll : float = 0.0;
trile_palette_scroll  : float = 0.0;
use_color_picker      : bool  = false;
selected_palette      : s32   = 0;

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
        set_trile_gfx(editor_current_trile.name, generate_trile_gfx_matias(editor_current_trile));
        striles();
        update_trile_thumbnail(editor_current_trile.name);
    };
}

draw_swatches :: (entries: []Palette_Entry, inside: GR.Rect, block: float, scroll: *float, id_offset: s32, theme: *GR.Overall_Theme) -> (end_y: float) {
    cols := max(1, cast(int)(inside.w / block));
    for entry, idx: entries {
        er : GR.Rect;
        er.x = inside.x + (idx % cols) * block;
        er.y = inside.y - scroll.* + (idx / cols) * block;
        er.w = block; er.h = block;
        btn := theme.button_theme;
        btn.surface_color = .{entry.r, entry.g, entry.b, 1.0};
        if GR.button(er, "", *btn, id_offset + cast(s32)idx) {
            current_color = .{entry.r, entry.g, entry.b};
            roughness = xx entry.roughness;
            metallic  = xx entry.metallic;
            emittance = xx entry.emittance;
        }
    }
    rows := ifx entries.count > 0 then (entries.count + cols - 1) / cols else 0;
    return inside.y + rows * block;
}

draw_material_tab :: (theme: *GR.Overall_Theme, area: GR.Rect) {
    r       := area;
    row_h   := ui_h(4, 0);
    block   := ui_h(3, 2);
    bottom  := area.y + area.h;
    sliders_h := ui_h(18, 0);

    r.h = row_h;
    half := r.w / 2;
    r.w = half;
    if GR.button(r, "Palette",      *t_button_selectable(theme, !use_color_picker)) then use_color_picker = false;
    r.x += half;
    if GR.button(r, "Color Picker", *t_button_selectable(theme, use_color_picker))  then use_color_picker = true;
    r.x = area.x; r.w = area.w;
    r.y += row_h;

    available := bottom - r.y - sliders_h;
    top_h := ifx use_color_picker then ui_h(42, 0) else available / 2;
    bot_h := available - top_h;

    r.h = top_h;
    if use_color_picker {
        GR.color_picker(r, *current_color, *theme.color_picker_theme);
    } else {
        if g_palettes.count > 1 {
            r.h = row_h;
            pal_w := r.w / cast(float)g_palettes.count;
            for pal, idx: g_palettes {
                pr := r;
                pr.x = area.x + idx * pal_w;
                pr.w = pal_w;
                if GR.button(pr, pal.name, *t_button_selectable(theme, cast(s32)idx == selected_palette), cast(s32)idx + 20000) {
                    selected_palette = cast(s32)idx;
                    global_palette_scroll = 0;
                }
            }
            r.y += row_h;
            top_h -= row_h;
            r.h = top_h;
        }
        entries : []Palette_Entry;
        if g_palettes.count > 0 {
            selected_palette = clamp(selected_palette, 0, cast(s32)g_palettes.count - 1);
            entries = g_palettes[selected_palette].entries;
        }
        region, inside := GR.begin_scrollable_region(r, *theme.scrollable_region_theme);
        end_y := draw_swatches(entries, inside, block, *global_palette_scroll, 0, theme);
        GR.end_scrollable_region(region, inside.x + inside.w, end_y, *global_palette_scroll);
    }
    r.y += top_h;

    unique_mats : [..]Material;
    unique_mats.allocator = temp;
    for x: 0..15  for y: 0..15  for z: 0..15 {
        trix := editor_current_trile.trixels[x][y][z];
        if trix.empty then continue;
        mr, mg, mb, ma := material_to_rgba(trix.material);
        key := (cast(u32)mr << 24) | (cast(u32)mg << 16) | (cast(u32)mb << 8) | cast(u32)ma;
        already := false;
        for um: unique_mats {
            ur, ug, ub, ua := material_to_rgba(um);
            if ((cast(u32)ur << 24) | (cast(u32)ug << 16) | (cast(u32)ub << 8) | cast(u32)ua) == key { already = true; break; }
        }
        if !already  array_add(*unique_mats, trix.material);
    }
    as_entries : [..]Palette_Entry;
    as_entries.allocator = temp;
    for mat: unique_mats {
        e : Palette_Entry;
        e.r = mat.color.x; e.g = mat.color.y; e.b = mat.color.z;
        e.roughness = mat.roughness; e.metallic = mat.metallic; e.emittance = mat.emittance;
        array_add(*as_entries, e);
    }

    r.h = bot_h * 0.75; 
    region2, inside2 := GR.begin_scrollable_region(r, *theme.scrollable_region_theme);
    end_y2 := draw_swatches(as_entries, inside2, block, *trile_palette_scroll, 10000, theme);
    GR.end_scrollable_region(region2, inside2.x + inside2.w, end_y2, *trile_palette_scroll);
    r.y += bot_h * 0.75;

    r.h = ui_h(3, 2);
    GR.label(r, "Roughness", *t_label_left(theme));
    r.y += r.h;
    GR.slider(r, *roughness, 0, 7, 1, *theme.slider_theme);
    r.y += r.h;
    GR.label(r, "Metallic", *t_label_left(theme));
    r.y += r.h;
    GR.slider(r, *metallic, 0, 3, 1, *theme.slider_theme);
    r.y += r.h;
    GR.label(r, "Emittance", *t_label_left(theme));
    r.y += r.h;
    GR.slider(r, *emittance, 0, 127, 1, *theme.slider_theme);
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

// Build rotation matrices matching the same GLSL convention used in shader_trile.glsl.
// In Jai row-major passed as GLSL column-major: GLSL out[i] = sum_j M_jai[j][i]*v[j].
tiling_rot_x :: (a: float) -> Matrix4 {
    c := cos(a); s := sin(a);
    m : Matrix4;
    m._11 = 1;
    m._22 = c;  m._23 = s;
    m._32 = -s; m._33 = c;
    m._44 = 1;
    return m;
}
tiling_rot_y :: (a: float) -> Matrix4 {
    c := cos(a); s := sin(a);
    m : Matrix4;
    m._11 = c;  m._13 = s;
    m._22 = 1;
    m._31 = -s; m._33 = c;
    m._44 = 1;
    return m;
}
tiling_rot_z :: (a: float) -> Matrix4 {
    c := cos(a); s := sin(a);
    m : Matrix4;
    m._11 = c;  m._21 = s;
    m._12 = -s; m._22 = c;
    m._33 = 1;
    m._44 = 1;
    return m;
}
// Matches get_orientation_matrix(ori) from shader_trile.glsl.
// Jai A*B applies A_eff first in GLSL, so twist*base = twist applied second = same as GLSL base*rot_y(twist).
make_orientation_matrix :: (ori: s32) -> Matrix4 {
    face  := ori / 4;
    twist := ori % 4;
    twist_mat : Matrix4;
    identity(*twist_mat);
    if twist > 0  twist_mat = tiling_rot_y(cast(float)twist * PI / 2.0);
    base_mat : Matrix4;
    if      face == 0 { identity(*base_mat); }
    else if face == 1 { base_mat = tiling_rot_x(PI); }
    else if face == 2 { base_mat = tiling_rot_z(-PI * 0.5); }
    else if face == 3 { base_mat = tiling_rot_z( PI * 0.5); }
    else if face == 4 { base_mat = tiling_rot_x( PI * 0.5); }
    else              { base_mat = tiling_rot_x(-PI * 0.5); }
    return twist_mat * base_mat;
}

get_tiling_neighbor_trile :: () -> *Trile {
    if tiling_neighbor_trile_name.count > 0 {
        t := get_trile(tiling_neighbor_trile_name);
        if t  return t;
    }
    return editor_current_trile;
}

draw_trile_editor :: () {
    create_set_cam_rendering_task(get_trile_editor_camera(), 0.0);
    w :=  New(World,, temp);
    create_sky_rendering_task(*w.conf);
    create_trixel_rendering_task(editor_current_trile, *colorMuls);
    if tiling_preview_active {
        neighbor_trile := get_tiling_neighbor_trile();
        create_trixel_rendering_task(neighbor_trile, null, world_offset = get_tiling_world_offset(), brightness = 0.75, tile_rotation = make_orientation_matrix(tiling_orientation), is_secondary = true);
    }
}

trile_editor_shortcuts :: () {
    // Tool/mode buttons are only rendered in the Toolset tab — handle shortcuts here so they work from any tab.
    if is_action_start(Editor_Action.TRIXEL_TOOL_PAINT)  then current_tool = .PAINT;
    if is_action_start(Editor_Action.TRIXEL_TOOL_ADD)    then current_tool = .ADD;
    if is_action_start(Editor_Action.TRIXEL_TOOL_REMOVE) then current_tool = .REMOVE;
    if is_action_start(Editor_Action.TRIXEL_MODE_POINT)  then current_mode = .POINT;
    if is_action_start(Editor_Action.TRIXEL_MODE_AREA)   then current_mode = .AREA;
    if is_action_start(Editor_Action.TRIXEL_MODE_BRUSH)  then current_mode = .BRUSH;
    // Save is in the Toolset tab only.
    if is_action_start(Editor_Action.SAVE) {
        set_trile_gfx(editor_current_trile.name, generate_trile_gfx_matias(editor_current_trile));
        striles();
        update_trile_thumbnail(editor_current_trile.name);
    }
    if is_action_start(Editor_Action.TRIXEL_VIEW_TILE) then tiling_preview_active = !tiling_preview_active;
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
    bar_w  := btn_w * 5.0;
    bar_x  := 100.0 * vw / 2.0 - bar_w / 2.0;
    bar_y  := 100.0 * vh - btn_h - 1.5 * vh;

    bar_r : GR.Rect;
    bar_r.x = bar_x; bar_r.y = bar_y; bar_r.w = bar_w; bar_r.h = btn_h;
    ui_add_mouse_occluder(bar_r);

    r2 : GR.Rect;
    r2.x = bar_x; r2.y = bar_y; r2.w = btn_w; r2.h = btn_h;
    if keybind_button(r2, "Lit",     .TRIXEL_VIEW_LIT,     *t_button_selectable(theme, trixel_view_mode == 0)) then trixel_view_mode = 0;
    r2.x += btn_w;
    if keybind_button(r2, "Normals", .TRIXEL_VIEW_NORMALS, *t_button_selectable(theme, trixel_view_mode == 1)) then trixel_view_mode = 1;
    r2.x += btn_w;
    if keybind_button(r2, "Albedo",  .TRIXEL_VIEW_ALBEDO,  *t_button_selectable(theme, trixel_view_mode == 2)) then trixel_view_mode = 2;
    r2.x += btn_w;
    if keybind_button(r2, "Mixed",   .TRIXEL_VIEW_MIXED,   *t_button_selectable(theme, trixel_view_mode == 3)) then trixel_view_mode = 3;
    r2.x += btn_w;
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
