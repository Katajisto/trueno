#scope_file
rotation : float = 0.0;
tilt     : float = 0.0;
zoom     : float = 3.0;

roughness : int = 0;
metallic  : int = 0;
emittance : int = 0;


TRILE_ROTATION_SPEED :: 2.0;

Trile_Editor_Tab :: enum {
    TOOLSET;
    METADATA;
    MATERIAL;  
};

current_tab : Trile_Editor_Tab = .TOOLSET;

current_trile : Trile;

#scope_export

current_color : Vector3 = .{1.0, 0.0, 0.0};

tick_trile_editor :: () {
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

draw_trile :: () {
    cam := get_trile_editor_camera();
    
    mvp := create_viewproj(*cam);
    vs_params : Vs_Params;
    vs_params.mvp = mvp.floats;

    trixels : [4096]Position_Color;

    hovered_trixel_x : int = -1;
    hovered_trixel_y : int = -1;
    hovered_trixel_z : int = -1;
    min_distance     : float = 999.0;

    ray := get_mouse_ray(*cam);

    for x: 0..15 {
        for y: 0..15 {
            for z: 0..15 {
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

    trixel_count : s32 = 0;

    for x: 0..15 {
        for y: 0..15 {
            for z: 0..15 {
                if current_trile.trixels[x][y][z].empty then continue;
                hit := does_ray_hit_cube(ray, .{ .{x * TRIXEL_SIZE, y * TRIXEL_SIZE, z * TRIXEL_SIZE}, .{TRIXEL_SIZE, TRIXEL_SIZE, TRIXEL_SIZE}});


                trixels[x * 16 * 16 + y * 16 + z].pos.x = x * (1.0 / 16.0) + TRIXEL_SIZE_HALF;
                trixels[x * 16 * 16 + y * 16 + z].pos.y = y * (1.0 / 16.0) + TRIXEL_SIZE_HALF;
                trixels[x * 16 * 16 + y * 16 + z].pos.z = z * (1.0 / 16.0) + TRIXEL_SIZE_HALF;
                trixels[x * 16 * 16 + y * 16 + z].pos.w = 1.0;
                trixel_color := current_trile.trixels[x][y][z].material.color;

                if  hovered_trixel_x == x &&
                    hovered_trixel_y == y &&
                    hovered_trixel_z == z {
                    trixel_color = .{1.0, 0.0, 0.0};        
                }
                
                trixels[x * 16 * 16 + y * 16 + z].col   = .{trixel_color.x, trixel_color.y, trixel_color.z, 1.0};
                trixel_count += 1;
            }
        }
    }

    sg_update_buffer(gPipelines.trixel.bind.vertex_buffers[1], *(sg_range.{
        ptr = trixels.data,
        size = size_of(type_of(trixels)),
    }));

    sg_begin_pass(*(sg_pass.{ action = state.pass_action_clear, swapchain = cast,force(sg_swapchain) sglue_swapchain() }));
    sg_apply_pipeline(gPipelines.trixel.pipeline);
    sg_apply_bindings(*gPipelines.trixel.bind);
    sg_apply_uniforms(UB_vs_params, *(sg_range.{ ptr = *vs_params, size = size_of(type_of(vs_params)) }));
    sg_draw(0, 36, trixel_count);
    sg_end_pass();
}

draw_trile_editor_ui :: (theme: *GR.Overall_Theme) {
    r := GR.get_rect(0, ui_h(5,0), ui_w(20, 20), ui_h(95, 0));
    draw_bg_rectangle(r, theme);
    tab_r := r;
    tab_r.h = ui_h(3,0);
    tab_r.w = ui_w(20, 20) / 3;

    if GR.button(tab_r, "Tool", *t_button_tab(theme, current_tab == .TOOLSET)) {
        current_tab = .TOOLSET;
    }
    tab_r.x += tab_r.w;
    if GR.button(tab_r, "Material", *t_button_tab(theme, current_tab == .MATERIAL)) {
        current_tab = .MATERIAL;
    }
    tab_r.x += tab_r.w;
    if GR.button(tab_r, "Meta", *t_button_tab(theme, current_tab == .METADATA)) {
        current_tab = .METADATA;
    }

    r.y += tab_r.h;

    if current_tab == {
        case .MATERIAL;
            draw_material_tab(theme, r);
    }
}
