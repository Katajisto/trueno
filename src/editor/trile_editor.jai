#scope_file
rotation : float = 0.0;
tilt     : float = 0.0;
zoom     : float = 3.0;

brush_radius   : int = 5;

roughness : int = 0;
metallic  : int = 0;
emittance : int = 0;

hovered_trixel_x : int = -1;
hovered_trixel_y : int = -1;
hovered_trixel_z : int = -1;


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

current_trile : *Trile;

#scope_file

apply_tool_to_trixel :: (x: s64, y: s64, z: s64) {
    if current_tool == .PAINT {
        current_trile.trixels[x][y][z].material.color = current_color;
    }
    if current_tool == .ADD {
        current_trile.trixels[x][y][z].empty = false;
    }
    if current_tool == .REMOVE {
        current_trile.trixels[x][y][z].empty = true;
    }
}

area_start_x : int;
area_start_y : int;
area_start_z : int;
area_active  : bool;

handle_tool_click :: () {
    if hovered_trixel_x < 0 && hovered_trixel_y < 0 && hovered_trixel_z < 0 then return;
    if current_mode == .POINT {
        apply_tool_to_trixel(hovered_trixel_x, hovered_trixel_y, hovered_trixel_z);
    }
    if current_mode == .BRUSH {
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

tick_trile_editor :: () {
    if !current_trile then current_trile = get_trile("test");

    if input_button_states[Key_Code.MOUSE_BUTTON_LEFT] & .START {
        handle_tool_click();
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
    zoom = clamp(zoom + mouse_delta_z * -0.2, 1.0, 3.0);

    cam := get_trile_editor_camera();
    ray := get_mouse_ray(*cam);
}

get_trile_editor_camera :: () -> Camera {
    camera: Camera;
    camera.near = 0.1;
    camera.far = 100;

    cameraDir : Vector3    = .{1, 0, 0};
    qrotation : Quaternion = .{cos(rotation/2.0),0,sin(rotation/2.0),0};
    qtilt     : Quaternion = .{cos(tilt/2.0),sin(tilt/2.0), 0, 0};

    rotate(*cameraDir, qrotation * qtilt);
    camera.position = .{0.5, 0.5, 0.5};

    camera.position += cameraDir * zoom;
    camera.target = .{0.5, 0.5, 0.5};
    
    return camera;
}

global_palette_scroll : float = 0.0;
trile_palette_scroll  : float = 0.0;

draw_tool_tab :: (theme: *GR.Overall_Theme, area: GR.Rect) {
    r := area;
    r.h = ui_h(4, 0);
    if GR.button(r, "Paint (P)", *t_button_selectable(theme, current_tool == .PAINT)) {
        current_tool = .PAINT;
    }
    r.y += r.h;
    if GR.button(r, "Add (+)", *t_button_selectable(theme, current_tool == .ADD)) {
        current_tool = .ADD;
    }
    r.y += r.h;
    if GR.button(r, "Remove (-)", *t_button_selectable(theme, current_tool == .REMOVE)) {
        current_tool = .REMOVE;
    }
    r.y += r.h * 3;
    if GR.button(r, "Point (c-P)", *t_button_selectable(theme, current_mode == .POINT)) {
        current_mode = .POINT;
    }
    r.y += r.h;
    if GR.button(r, "Area (c-A)", *t_button_selectable(theme, current_mode == .AREA)) {
        current_mode = .AREA;
    }
    r.y += r.h;
    if GR.button(r, "Brush (c-B)", *t_button_selectable(theme, current_mode == .BRUSH)) {
        current_mode = .BRUSH;
    }

    r.y += r.h;
    GR.slider(r, *brush_radius, 0, 12, 1, *theme.slider_theme);
    r.y += r.h * 2;
    if GR.button(r, "Save and gen", *theme.button_theme) {
        set_trile_gfx("test", generate_trile_gfx_matias(current_trile));
    };
}

draw_material_tab :: (theme: *GR.Overall_Theme, area: GR.Rect) {
    r := area;
    r.h = ui_h(42, 0);
    GR.color_picker(r, *current_color, *theme.color_picker_theme);
    r.y += r.h;
    r.h = ui_h(100,0) - r.y;
    r.h -= ui_h(18,0);
    r.h /= 2;
    region, inside := GR.begin_scrollable_region(r, *theme.scrollable_region_theme);
    s := inside;
    GR.end_scrollable_region(region, s.x + s.w, s.y + s.h, *global_palette_scroll);
    r.y += r.h;
    region, inside = GR.begin_scrollable_region(r, *theme.scrollable_region_theme);
    s = inside;
    GR.end_scrollable_region(region, s.x + s.w, s.y + s.h, *trile_palette_scroll);
    r.y += r.h;
    r.h = ui_h(3,2);
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
    GR.slider(r, *emittance, 0, 2, 1, *theme.slider_theme);
    
}


draw_trile_editor :: () {
    draw_sky(*get_trile_editor_camera());
    draw_trile();
}

draw_trile :: () {
    cam := get_trile_editor_camera();
    
    mvp := create_viewproj(*cam);
    vs_params : Vs_Params;
    vs_params.mvp = mvp.floats;

    trixels : [4096]Position_Color;

    min_distance     : float = 999.0;

    ray := get_mouse_ray(*cam);

    hovered_trixel_x = -1;
    hovered_trixel_y = -1;
    hovered_trixel_z = -1;

    print("BURGER!\n");
    for x: 0..15 {
        for y: 0..15 {
            for z: 0..15 {
                if current_trile.trixels[x][y][z].empty then continue;
                hit := does_ray_hit_cube(ray, .{ .{x * TRIXEL_SIZE, y * TRIXEL_SIZE, z * TRIXEL_SIZE}, .{TRIXEL_SIZE, TRIXEL_SIZE, TRIXEL_SIZE}});
                if hit.hit && hit.distance < min_distance {
                    hovered_trixel_x = x;
                    hovered_trixel_y = y;
                    hovered_trixel_z = z;
                    min_distance = hit.distance;
                }
            }
        }
    }
    print("BURGER!\n");

    trixel_count : s32 = 0;

    for x: 0..15 {
        for y: 0..15 {
            for z: 0..15 {
                if current_trile.trixels[x][y][z].empty then continue;
                hit := does_ray_hit_cube(ray, .{ .{x * TRIXEL_SIZE, y * TRIXEL_SIZE, z * TRIXEL_SIZE}, .{TRIXEL_SIZE, TRIXEL_SIZE, TRIXEL_SIZE}});


                trixels[trixel_count].pos.x = x * (1.0 / 16.0) + TRIXEL_SIZE_HALF;
                trixels[trixel_count].pos.y = y * (1.0 / 16.0) + TRIXEL_SIZE_HALF;
                trixels[trixel_count].pos.z = z * (1.0 / 16.0) + TRIXEL_SIZE_HALF;
                trixels[trixel_count].pos.w = 1.0;
                trixel_color := current_trile.trixels[x][y][z].material.color;

                if  hovered_trixel_x == x &&
                    hovered_trixel_y == y &&
                    hovered_trixel_z == z {
                    trixel_color = .{1.0, 0.0, 0.0};        
                }
                
                trixels[trixel_count].col = .{trixel_color.x, trixel_color.y, trixel_color.z, 1.0};
                trixel_count += 1;
            }
        }
    }

    print("BURGER!\n");
    sg_update_buffer(gPipelines.trixel.bind.vertex_buffers[2], *(sg_range.{
        ptr = trixels.data,
        size = size_of(type_of(trixels)),
    }));

    sg_apply_pipeline(gPipelines.trixel.pipeline);
    sg_apply_bindings(*gPipelines.trixel.bind);
    sg_apply_uniforms(UB_vs_params, *(sg_range.{ ptr = *vs_params, size = size_of(type_of(vs_params)) }));
    sg_draw(0, 36, trixel_count);
}

trile_editor_shortcuts :: () {
    if input_button_states[Key_Code.CTRL] & .DOWN {
        if input_button_states[#char "A"] & .START {
            current_mode = .AREA;
        }
        if input_button_states[#char "P"] & .START {
            current_mode = .POINT;
        }
        if input_button_states[#char "B"] & .START {
            current_mode = .BRUSH;
        }
    } else {
        if input_button_states[#char "T"] & .START {
            current_tab = .TOOLSET;
        }
        if input_button_states[#char "M"] & .START {
            current_tab = .MATERIAL;
        }
        if input_button_states[#char "I"] & .START {
            current_tab = .METADATA;
        }
        if input_button_states[#char "P"] & .START {
            current_tool = .PAINT;
        }
        // Hack: These will only work on nordic keyboards as expected...
        if input_button_states[#char "-"] & .START {
            current_tool = .ADD;
        }
        if input_button_states[#char "/"] & .START {
            current_tool = .REMOVE;
        }
    }
}

draw_trile_editor_ui :: (theme: *GR.Overall_Theme) {
    r := GR.get_rect(0, ui_h(5,0), ui_w(20, 20), ui_h(95, 0));
    draw_bg_rectangle(r, theme);
    tab_r := r;
    tab_r.h = ui_h(3,0);
    tab_r.w = ui_w(20, 20) / 3;

    if GR.button(tab_r, "Tool (T)", *t_button_tab(theme, current_tab == .TOOLSET)) {
        current_tab = .TOOLSET;
    }
    tab_r.x += tab_r.w;
    if GR.button(tab_r, "Material (M)", *t_button_tab(theme, current_tab == .MATERIAL)) {
        current_tab = .MATERIAL;
    }
    tab_r.x += tab_r.w;
    if GR.button(tab_r, "Meta (I)", *t_button_tab(theme, current_tab == .METADATA)) {
        current_tab = .METADATA;
    }

    r.y += tab_r.h;

    if current_tab == {
        case .MATERIAL;
            draw_material_tab(theme, r);
        case .TOOLSET;
            draw_tool_tab(theme, r);
    }
}
