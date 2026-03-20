#scope_file

// @ToDo do a config tweak file thing like jblow has and add this there.
CAMERA_INACTIVE_TIME_TO_ORBIT :: 200000000.0;
MAX_CAMERA_DIST               :: 25.0;
MIN_CAMERA_DIST               :: 2.0;
DIST_SCROLL_SPEED             :: 0.8;

mouse2Active             : bool;
mouse2ActivationPosition : Vector2;
mouse3Active             : bool;
mouse3ActivationPosition : Vector2;

cameraTilt        : float = 0.2;
cameraDist        : float = 10.0;
cameraRotation    : float;
oldCameraRotation : float;
oldCameraTilt     : float;
cameraCenter      : Vector2;

trile_preview_disabled : bool = false;

Level_Editor_Tool_Mode :: enum {
    POINT;
    BRUSH;
    AREA;
    LINE;
}

current_tool_mode : Level_Editor_Tool_Mode = .POINT;
brush_radius      : int = 2;
brush_height      : int = 0;

area_active  : bool;
area_delete  : bool;
area_start_x : int;
area_start_y : int;
area_start_z : int;

line_active  : bool;
line_delete  : bool;
line_start_x : int;
line_start_y : int;
line_start_z : int;

current_orientation_face  : u8 = 0;
current_orientation_twist : u8 = 0;

get_current_orientation :: () -> u8 {
    return current_orientation_face * 4 + current_orientation_twist;
}

#scope_export

toggle_preview :: () {
	trile_preview_disabled = !trile_preview_disabled;
} @Command

set_dist :: (dist: float) {
	cameraDist = dist;
} @Command

#scope_file

tacomaSamples    : s32   = 100;
tacomaResolution : s32   = 500;
tacomaExposure   : float = 1.0;
tacomaContrast   : float = 1.0;
tacomaSaturation : float = 1.0;

lastInputTime : float64;

editY : s32;

pointerHit : bool;
pointerX   : s32;
pointerY   : s32;

show_trile_preview : bool = true;
trile_preview_x    : int  = 0;
trile_preview_y    : int  = 0;
trile_preview_z    : int  = 0;

Level_Editor_Tab :: enum {
    TACOMA;
    TOOLS;
    INFO;  
};

current_tab : Level_Editor_Tab = .TOOLS;
get_level_editor_camera :: () -> Camera {
    camera: Camera;
    camera.near = 0.1;
    camera.far  = 5000;
	camera.target = .{cameraCenter.x, xx editY, cameraCenter.y};
	cameraDir : Vector3    = .{1, 0, 0};
    qrotation : Quaternion = .{cos(-cameraRotation/2.0),0,sin(-cameraRotation/2.0),0};
    qtilt     : Quaternion = .{cos(-cameraTilt/2.0),sin(-cameraTilt/2.0), 0, 0};

	rotate(*cameraDir, qrotation * qtilt);

	camera.position  = camera.target;
	camera.position += cameraDir * cameraDist;

	if is_in_reflection_pass {
		camera.position.y *= -1;
		camera.target.y *= -1;
	}
	
    return camera;
}


tick_level_editor_camera :: () {
    if console_open_ignore_input then return;

	if get_time() - lastInputTime > CAMERA_INACTIVE_TIME_TO_ORBIT { // idle rotating camera
		cameraRotation += cast(float) delta_time;
	}

	cameraSpeed :: 150;

	forward   : Vector3    = .{1, 0, 0};
    qrotation : Quaternion = .{cos(-cameraRotation/2.0),0,sin(-cameraRotation/2.0),0};
	
	rotate(*forward, qrotation);
	forward2d := Vector2.{forward.x, forward.z};

	left           : Vector3    = .{0, 0, 1};
    qrotation_left : Quaternion = .{cos(-cameraRotation/2.0),0,sin(-cameraRotation/2.0),0};
	rotate(*left, qrotation_left);
	left2d := Vector2.{left.x, left.z};
	
	cameraDist = clamp(cameraDist - mouse_delta_z * DIST_SCROLL_SPEED, 0.0, MAX_CAMERA_DIST);

	distRange : float = MAX_CAMERA_DIST - MIN_CAMERA_DIST;
	zoomCameraMovementMultiplier := 0.03 + ((cameraDist - MIN_CAMERA_DIST) / distRange) * 0.15; 
	 
	if input_button_states[#char "W"] & .DOWN {
		lastInputTime = get_time();
		cameraCenter += -cameraSpeed * zoomCameraMovementMultiplier * (xx delta_time) * forward2d;
	}
	if input_button_states[#char "S"] & .DOWN {
		lastInputTime = get_time();
		cameraCenter += cameraSpeed * zoomCameraMovementMultiplier * (xx delta_time) * forward2d;
	}

	if input_button_states[#char "A"] & .DOWN {
		lastInputTime = get_time();
		cameraCenter += -cameraSpeed * zoomCameraMovementMultiplier * (xx delta_time) * left2d;
	}
	if input_button_states[#char "D"] & .DOWN {
		lastInputTime = get_time();
		cameraCenter += cameraSpeed * zoomCameraMovementMultiplier * (xx delta_time) * left2d;
	}
	
	if is_action_start(Editor_Action.LEVEL_HEIGHT_UP) {
		lastInputTime = get_time();
		editY = min(editY + 1, 100);
	}

	if is_action_start(Editor_Action.LEVEL_HEIGHT_DOWN) {
		lastInputTime = get_time();
		editY = max(editY - 1, 0);
	}
	
	if get_mouse_state(Key_Code.MOUSE_BUTTON_MIDDLE) & .DOWN {
		if mouse2Active {
			lastInputTime = get_time();
			diff := mouse2ActivationPosition - Vector2.{input_mouse_x, input_mouse_y};
			diff *= 0.5;
			cameraRotation = oldCameraRotation + diff.x / 100;
			cameraTilt = oldCameraTilt - diff.y / 100;
			cameraTilt = max(0.1, cameraTilt);
			cameraTilt = min(PI/2.2, cameraTilt);
		} else {
			mouse2Active = true;
			mouse2ActivationPosition = Vector2.{input_mouse_x, input_mouse_y};
			oldCameraRotation = cameraRotation;
			oldCameraTilt = cameraTilt;
		}
	} else {
		mouse2Active = false;
	}


	if get_mouse_state(Key_Code.MOUSE_BUTTON_RIGHT) & .DOWN {
		if mouse3Active {
			lastInputTime = get_time();
			diff := mouse3ActivationPosition - Vector2.{input_mouse_x, input_mouse_y};
			cameraCenter = cameraCenter + forward2d * -diff.y * cast(float) delta_time * zoomCameraMovementMultiplier;
			cameraCenter = cameraCenter + left2d    * -diff.x * cast(float) delta_time * zoomCameraMovementMultiplier;
		} else {
			mouse3Active = true;
			mouse3ActivationPosition = Vector2.{input_mouse_x, input_mouse_y};
		}
	} else {
		mouse3Active = false;
	}

	
}

draw_tacoma_tab :: (theme: *GR.Overall_Theme, total_r: GR.Rect) {
	curworld := get_current_world();
	r := total_r;
	r.h = ui_h(3,0);
	#if FLAG_TACOMA_ENABLED {
		if GR.button(r, "Render with Tacoma", *theme.button_theme) {
			cam := get_level_editor_camera();
			gen_reference(tacomaResolution, tacomaResolution, cam.position, cam.target, tacomaSamples, true, curworld.world);
		}
		r.y += r.h;
		if GR.button(r, "Render a RDM", *theme.button_theme) {
			gen_rdm(tacomaSamples, true, curworld.world);
		}
		r.y += r.h;
		if GR.button(r, "Bake all chunk RDMs", *theme.button_theme) {
			if curworld.valid then rdm_bake_all_chunks(curworld.world, tacomaSamples, true);
		}
		r.y += r.h;
		if rdm_bake.active {
			total := cast(s32) rdm_bake.jobs.count;
			done  := rdm_bake.current_job;
			pct   := ifx total > 0 then done * 100 / total else 0;
			GR.label(r, tprint("Baking RDMs: %/% (\%%)", done, total, pct), *t_label_left(theme));
			r.y += r.h;
		}
		if current_screenshot.valid {
			aspect := cast(float)current_screenshot.width / cast(float)current_screenshot.height;
			
			r.h = r.w / aspect;
			uiTex := New(Ui_Texture,, temp);
			uiTex.tex = current_screenshot.image;
			set_shader_for_images(uiTex);
		    immediate_quad(.{r.x, r.y}, .{r.x + r.w, r.y}, .{r.x + r.w, r.y + r.h}, .{r.x, r.y + r.h});
			set_shader_for_color();
			r.y += r.h;
		}
		r.h = ui_h(4,0);

	    GR.label(r, "Samples", *t_label_left(theme));
	    r.y += r.h;
	    GR.slider(r, *tacomaSamples, 10, 10000, 10, *theme.slider_theme);
		r.y += r.h;
	    GR.label(r, "Resolution", *t_label_left(theme));
	    r.y += r.h;
	    GR.slider(r, *tacomaResolution, 10, 5000, 10, *theme.slider_theme);
		r.y += r.h;
	    GR.label(r, "Exposure", *t_label_left(theme));
	    r.y += r.h;
	    GR.slider(r, *tacomaExposure, 0.5, 3.0, 0.1, *theme.slider_theme);
		r.y += r.h;
	    GR.label(r, "Contrast", *t_label_left(theme));
	    r.y += r.h;
	    GR.slider(r, *tacomaContrast, 0.5, 3.0, 0.1, *theme.slider_theme);
		r.y += r.h;
	    GR.label(r, "Saturation", *t_label_left(theme));
	    r.y += r.h;
	    GR.slider(r, *tacomaSaturation, 0.5, 3.0, 0.1, *theme.slider_theme);
		r.y += r.h;

		
	} else {
		GR.label(r, "Tacoma is not enabled in this build.", *theme.label_theme);
	}
}

#scope_file

Edit_Mode :: enum {
	TRILES;
}

editMode : Edit_Mode;

#scope_export

draw_tools_tab :: (theme: *GR.Overall_Theme, total_r: GR.Rect) {
	r := total_r;
	r.h = ui_h(4, 0);

	if keybind_button(r, "Save world", .SAVE, *theme.button_theme) then sworld();
	r.y += r.h * 2;

	// Tool mode buttons
	if keybind_button(r, "Point", .LEVEL_TOOL_POINT, *t_button_selectable(theme, current_tool_mode == .POINT)) then current_tool_mode = .POINT;
	r.y += r.h;
	if keybind_button(r, "Brush", .LEVEL_TOOL_BRUSH, *t_button_selectable(theme, current_tool_mode == .BRUSH)) then current_tool_mode = .BRUSH;
	r.y += r.h;
	if keybind_button(r, "Area",  .LEVEL_TOOL_AREA,  *t_button_selectable(theme, current_tool_mode == .AREA))  { current_tool_mode = .AREA;  area_active = false; }
	r.y += r.h;
	if keybind_button(r, "Line",  .LEVEL_TOOL_LINE,  *t_button_selectable(theme, current_tool_mode == .LINE))  { current_tool_mode = .LINE;  line_active = false; }
	r.y += r.h;

	// Brush radius/height (only for brush mode)
	if current_tool_mode == .BRUSH {
		r.h = ui_h(3, 2);
		GR.label(r, "Brush Radius", *t_label_left(theme));
		r.y += r.h;
		r.h = ui_h(4, 0);
		GR.slider(r, *brush_radius, 1, 8, 1, *theme.slider_theme);
		r.y += r.h;
		r.h = ui_h(3, 2);
		GR.label(r, "Brush Height (±Y layers)", *t_label_left(theme));
		r.y += r.h;
		r.h = ui_h(4, 0);
		GR.slider(r, *brush_height, 0, 8, 1, *theme.slider_theme);
		r.y += r.h * 2;
	} else {
		r.y += r.h;
	}

	// Status hints for multi-click tools
	r.h = ui_h(3, 2);
	if current_tool_mode == .AREA {
		if area_active {
			GR.label(r, "Click second corner to fill", *t_label_left(theme));
		} else {
			GR.label(r, "Click first corner to start", *t_label_left(theme));
		}
		r.y += r.h;
	} else if current_tool_mode == .LINE {
		if line_active {
			GR.label(r, "Click endpoint to draw line", *t_label_left(theme));
		} else {
			GR.label(r, "Click start of line", *t_label_left(theme));
		}
		r.y += r.h;
	}

	// Orientation controls
	r.y += r.h;
	r.h = ui_h(3, 2);
	GR.label(r, "-- Orientation --", *t_label_left(theme));
	r.y += r.h;
	twist_angle := current_orientation_twist * 90;
	GR.label(r, tprint("Face: %  Twist: %°", current_orientation_face, twist_angle), *t_label_left(theme));
	r.y += r.h;
	GR.label(r, tprint("%/%: twist   %: face",
		key_combo_string(get_action_combo(Editor_Action.LEVEL_TWIST_CCW)),
		key_combo_string(get_action_combo(Editor_Action.LEVEL_TWIST_CW)),
		key_combo_string(get_action_combo(Editor_Action.LEVEL_CYCLE_FACE))), *t_label_left(theme));
	r.y += r.h;
}

handle_tool_click :: (x: int, y: int, z: int, delete: bool = false) {
	curworld := get_current_world();
	if delete {
		remove_trile(cast(s32)x, cast(s32)y, cast(s32)z);
	} else {
		if editor_current_trile != null then add_trile(editor_current_trile.name, cast(s32)x, cast(s32)y, cast(s32)z, get_current_orientation());
	}
}

apply_brush :: (cx: int, cy: int, cz: int, delete: bool) {
    for dy: -brush_height..brush_height {
        for dx: -brush_radius..brush_radius {
            for dz: -brush_radius..brush_radius {
                dist := sqrt(cast(float)(dx*dx + dz*dz));
                if dist <= cast(float)brush_radius {
                    handle_tool_click(cx + dx, cy + dy, cz + dz, delete);
                }
            }
        }
    }
}

apply_area :: (x2: int, y2: int, z2: int, delete: bool) {
    for x: min(area_start_x, x2)..max(area_start_x, x2) {
        for y: min(area_start_y, y2)..max(area_start_y, y2) {
            for z: min(area_start_z, z2)..max(area_start_z, z2) {
                handle_tool_click(x, y, z, delete);
            }
        }
    }
}

apply_line :: (x2: int, y2: int, z2: int, delete: bool) {
    x1 := line_start_x; y1 := line_start_y; z1 := line_start_z;
    dx := abs(x2 - x1); dy := abs(y2 - y1); dz := abs(z2 - z1);
    sx := ifx x1 < x2 then 1 else -1;
    sy := ifx y1 < y2 then 1 else -1;
    sz := ifx z1 < z2 then 1 else -1;
    // 3D Bresenham: drive along the longest axis
    dm := max(dx, max(dy, dz));
    x := x1; y := y1; z := z1;
    ex := dm / 2; ey := dm / 2; ez := dm / 2;
    count := 0;
    while count <= dm && count < 2000 {
        handle_tool_click(x, y, z, delete);
        ex -= dx; if ex < 0 { x += sx; ex += dm; }
        ey -= dy; if ey < 0 { y += sy; ey += dm; }
        ez -= dz; if ez < 0 { z += sz; ez += dm; }
        count += 1;
    }
}

add_trile :: (name: string, x: s32, y: s32, z: s32, orientation: u8 = 0) {
	curworld := get_current_world();

	// Remove any existing trile at this position first.
	remove_trile(x, y, z);

	// Find or create the chunk.
	key := world_to_chunk_coord(x, y, z);
	chunk := table_find_pointer(*curworld.world.chunks, key);
	if !chunk {
		new_chunk: Chunk;
		new_chunk.coord = key;
		table_set(*curworld.world.chunks, key, new_chunk);
		chunk = table_find_pointer(*curworld.world.chunks, key);
	}

	lx, ly, lz := world_to_local(x, y, z);
	inst := Trile_Instance.{x = lx, y = ly, z = lz, orientation = orientation};

	// Find existing group for this trile type, or create one.
	for *group: chunk.groups {
		if group.trile_name == name {
			array_add(*group.instances, inst);
			return;
		}
	}
	group: Chunk_Trile_Group;
	group.trile_name = sprint("%", name);
	array_add(*group.instances, inst);
	array_add(*chunk.groups, group);
} @Command

remove_trile :: (x: s32, y: s32, z: s32) {
	curworld := get_current_world();

	key := world_to_chunk_coord(x, y, z);
	chunk := table_find_pointer(*curworld.world.chunks, key);
	if !chunk then return;

	lx, ly, lz := world_to_local(x, y, z);

	for *group: chunk.groups {
		for inst, idx: group.instances {
			if inst.x == lx && inst.y == ly && inst.z == lz {
				array_unordered_remove_by_index(*group.instances, idx);
				return;
			}
		}
	}
} @Command



tick_level_editor :: () {
	#if FLAG_TACOMA_ENABLED { rdm_bake_tick(); }
	tick_level_editor_camera();

	if is_action_start(Editor_Action.SAVE) then sworld();

	if is_action_start(Editor_Action.LEVEL_TOOL_POINT) then current_tool_mode = .POINT;
	if is_action_start(Editor_Action.LEVEL_TOOL_BRUSH) then current_tool_mode = .BRUSH;
	if is_action_start(Editor_Action.LEVEL_TOOL_AREA)  { current_tool_mode = .AREA;  area_active = false; }
	if is_action_start(Editor_Action.LEVEL_TOOL_LINE)  { current_tool_mode = .LINE;  line_active = false; }
	if is_action_start(Editor_Action.LEVEL_TWIST_CCW) {
		lastInputTime = get_time();
		current_orientation_twist = (current_orientation_twist + 1) % 4;
	}
	if is_action_start(Editor_Action.LEVEL_TWIST_CW) {
		lastInputTime = get_time();
		current_orientation_twist = (current_orientation_twist + 3) % 4;
	}
	if is_action_start(Editor_Action.LEVEL_CYCLE_FACE) {
		lastInputTime = get_time();
		current_orientation_face = (current_orientation_face + 1) % 6;
	}

	ray := get_mouse_ray(*get_level_editor_camera());
	hit, point := ray_plane_collision_point(ray, xx editY, 20);

	show_trile_preview = false;
	if hit {
		show_trile_preview = true;
		trile_preview_x = xx floor(point.x);
		trile_preview_y = editY;
		trile_preview_z = xx floor(point.y);

		px := trile_preview_x;
		py := trile_preview_y;
		pz := trile_preview_z;

		if current_tool_mode == .POINT {
			if get_mouse_state(Key_Code.MOUSE_BUTTON_LEFT) & .START {
				handle_tool_click(px, py, pz);
			}
			if get_mouse_state(Key_Code.MOUSE_BUTTON_RIGHT) & .START {
				handle_tool_click(px, py, pz, true);
			}
		} else if current_tool_mode == .BRUSH {
			if get_mouse_state(Key_Code.MOUSE_BUTTON_LEFT) & .DOWN {
				apply_brush(px, py, pz, false);
			}
			if get_mouse_state(Key_Code.MOUSE_BUTTON_RIGHT) & .DOWN {
				apply_brush(px, py, pz, true);
			}
		} else if current_tool_mode == .AREA {
			if get_mouse_state(Key_Code.MOUSE_BUTTON_LEFT) & .START {
				if !area_active {
					area_active  = true;
					area_delete  = false;
					area_start_x = px;
					area_start_y = py;
					area_start_z = pz;
				} else if !area_delete {
					apply_area(px, py, pz, false);
					area_active = false;
				} else {
					area_active = false;  // cancel delete selection
				}
			}
			if get_mouse_state(Key_Code.MOUSE_BUTTON_RIGHT) & .START {
				if !area_active {
					area_active  = true;
					area_delete  = true;
					area_start_x = px;
					area_start_y = py;
					area_start_z = pz;
				} else if area_delete {
					apply_area(px, py, pz, true);
					area_active = false;
				} else {
					area_active = false;  // cancel add selection
				}
			}
		} else if current_tool_mode == .LINE {
			if get_mouse_state(Key_Code.MOUSE_BUTTON_LEFT) & .START {
				if !line_active {
					line_active  = true;
					line_delete  = false;
					line_start_x = px;
					line_start_y = py;
					line_start_z = pz;
				} else if !line_delete {
					apply_line(px, py, pz, false);
					line_active = false;
				} else {
					line_active = false;  // cancel delete selection
				}
			}
			if get_mouse_state(Key_Code.MOUSE_BUTTON_RIGHT) & .START {
				if !line_active {
					line_active  = true;
					line_delete  = true;
					line_start_x = px;
					line_start_y = py;
					line_start_z = pz;
				} else if line_delete {
					apply_line(px, py, pz, true);
					line_active = false;
				} else {
					line_active = false;  // cancel add selection
				}
			}
		}
	}
}

create_level_editor_preview_tasks :: () {
	curworld := get_current_world();
	if !curworld.valid then return;
	if !editor_current_trile then return;

	positions: [..]Vector4;
	positions.allocator = temp;
	ori := cast(float) get_current_orientation();

	px := trile_preview_x; py := trile_preview_y; pz := trile_preview_z;

	if current_tool_mode == .POINT {
		array_add(*positions, .{cast(float)px, cast(float)py, cast(float)pz, ori});
	} else if current_tool_mode == .BRUSH {
		for dy: -brush_height..brush_height {
			for dx: -brush_radius..brush_radius {
				for dz: -brush_radius..brush_radius {
					dist := sqrt(cast(float)(dx*dx + dz*dz));
					if dist <= cast(float)brush_radius {
						array_add(*positions, .{cast(float)(px+dx), cast(float)(py+dy), cast(float)(pz+dz), ori});
					}
				}
			}
		}
	} else if current_tool_mode == .AREA {
		if area_active {
			for x: min(area_start_x, px)..max(area_start_x, px) {
				for y: min(area_start_y, py)..max(area_start_y, py) {
					for z: min(area_start_z, pz)..max(area_start_z, pz) {
						array_add(*positions, .{cast(float)x, cast(float)y, cast(float)z, ori});
					}
				}
			}
		} else {
			array_add(*positions, .{cast(float)px, cast(float)py, cast(float)pz, ori});
		}
	} else if current_tool_mode == .LINE {
		if line_active {
			x1 := line_start_x; y1 := line_start_y; z1 := line_start_z;
			x2 := px; y2 := py; z2 := pz;
			dx := abs(x2-x1); dy := abs(y2-y1); dz := abs(z2-z1);
			sx := ifx x1 < x2 then 1 else -1;
			sy := ifx y1 < y2 then 1 else -1;
			sz := ifx z1 < z2 then 1 else -1;
			dm := max(dx, max(dy, dz));
			x := x1; y := y1; z := z1;
			ex := dm/2; ey := dm/2; ez := dm/2;
			count := 0;
			while count <= dm && count < 2000 {
				array_add(*positions, .{cast(float)x, cast(float)y, cast(float)z, ori});
				ex -= dx; if ex < 0 { x += sx; ex += dm; }
				ey -= dy; if ey < 0 { y += sy; ey += dm; }
				ez -= dz; if ez < 0 { z += sz; ez += dm; }
				count += 1;
			}
		} else {
			array_add(*positions, .{cast(float)px, cast(float)py, cast(float)pz, ori});
		}
	}

	if positions.count == 0 then return;

	is_delete := (current_tool_mode == .AREA && area_active && area_delete)
	          || (current_tool_mode == .LINE && line_active && line_delete);

	task: Rendering_Task_Trile;
	task.trile        = editor_current_trile.name;
	task.positions    = positions;
	task.worldConf    = *curworld.world.conf;
	task.preview_mode = ifx is_delete then cast(s32)2 else cast(s32)1;
	add_rendering_task(task);
}

draw_level_editor :: () {
	curworld := get_current_world();
	if !curworld.valid then return;
	cam := get_level_editor_camera();
	create_set_cam_rendering_task(cam, effective_plane_height(*curworld.world.conf));
	create_world_rendering_tasks(*curworld.world, cam);
	if show_trile_preview && !trile_preview_disabled {
		create_level_editor_preview_tasks();
	}
}

draw_level_editor_ui :: (theme: *GR.Overall_Theme) {
    r := GR.get_rect(0, ui_h(5,0), ui_w(20, 20), ui_h(95, 0));
	ui_add_mouse_occluder(r);
    draw_bg_rectangle(r, theme);
    tab_r := r;
    tab_r.h = ui_h(3,0);
    tab_r.w = ui_w(20, 20) / 3;

    if keybind_button(tab_r, "Tools",  .LEVEL_TAB_TOOLS,  *t_button_tab(theme, current_tab == .TOOLS))  then current_tab = .TOOLS;
    tab_r.x += tab_r.w;
    if keybind_button(tab_r, "Info",   .LEVEL_TAB_INFO,   *t_button_tab(theme, current_tab == .INFO))   then current_tab = .INFO;
    tab_r.x += tab_r.w;
    if keybind_button(tab_r, "Tacoma", .LEVEL_TAB_TACOMA, *t_button_tab(theme, current_tab == .TACOMA)) then current_tab = .TACOMA;
    r.y += tab_r.h;

	curworld := get_current_world();
    if current_tab == {
		case .TOOLS;
			draw_tools_tab(theme, r);
        case .TACOMA;
			draw_tacoma_tab(theme, r);
		case .INFO;
			if curworld.valid then autoedit(r, *curworld.world.conf, theme);
    }
	draw_picker(theme);
}
