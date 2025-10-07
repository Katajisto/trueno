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

world : World;

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

	world.ground[500][500] = .GRASS;

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
	
	if input_button_states[Key_Code.ARROW_UP] & .START {
		lastInputTime = get_time();
		editY = min(editY + 1, 100);
	}

	if input_button_states[Key_Code.ARROW_DOWN] & .START {
		lastInputTime = get_time();
		editY = max(editY - 1, 0);
	}
	
	if get_mouse_state(Key_Code.MOUSE_BUTTON_RIGHT) & .DOWN {
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


	if get_mouse_state(Key_Code.MOUSE_BUTTON_MIDDLE) & .DOWN {
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
	r := total_r;
	r.h = ui_h(3,0);
	#if HAS_TACOMA {
		if GR.button(r, "Render with Tacoma", *theme.button_theme) {
			cam := get_level_editor_camera();
			gen_reference(tacomaResolution, tacomaResolution, .{tacomaExposure, tacomaContrast, tacomaSaturation}, .{cam.target, cam.position, tacomaSamples, true}, world);
		}
		r.y += r.h;
		if current_screenshot.valid {
			aspect := cast(float)current_screenshot.width / cast(float)current_screenshot.height;
			
			r.h = r.w / aspect;
			uiTex := New(Ui_Texture,, temp);
			uiTex.tex = *current_screenshot.image;
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
	GROUND;
}

groundType : Ground_Tile;
editMode : Edit_Mode;

#scope_export

draw_tools_tab :: (theme: *GR.Overall_Theme, total_r: GR.Rect) {
	r := total_r;
	r.h = ui_h(3,0);
	r.w = r.w/2.0;
    if GR.button(r, "Edit triles", *t_button_selectable(theme, editMode == .TRILES)) {
        editMode = .TRILES;
    }
	r.x += r.w;
    if GR.button(r, "Edit ground", *t_button_selectable(theme, editMode == .GROUND)) {
        editMode = .GROUND;
    }
	r.x -= r.w;
	r.w *= 2.0;
	r.y += r.h * 1.5;
	if editMode == .GROUND {
	    if GR.button(r, "Grass", *t_button_selectable(theme, groundType == .GRASS)) {
	        groundType = .GRASS;
	    }
		r.y += r.h;
	    if GR.button(r, "Water", *t_button_selectable(theme, groundType == .WATER)) {
	        groundType = .WATER;
	    }
		r.y += r.h;
	    if GR.button(r, "Sand", *t_button_selectable(theme, groundType == .SAND)) {
	        groundType = .SAND;
	    }
	}
}

handle_tool_click :: (x: int, y: int, z: int) {
	if editMode == {
		case .TRILES;
			if editor_current_trile != null then add_trile(editor_current_trile.name, cast(float)x, cast(float)y, cast(float)z);
		case .GROUND;
			ray := get_mouse_ray(*get_level_editor_camera());
			hit, point := ray_plane_collision_point(ray, 0, 100);
		if hit {
				world.ground[floor(point.y).(int) + 500][floor(point.x).(int) + 500] = groundType;
			}
	}

} 

add_trile :: (name: string, x: float, y: float, z: float) {

	loose_float_comp :: (a: float, b: float) -> bool {
		return abs(a-b) < 0.001;
	}

	// Check if the position is already occupied. @ToDo: we would probably like to
	// have some acceleration structure like a hashmap to speed up this check when
	// we are checking for collisions.
	for world.positions {
		for v, idx: it.positions {
			if loose_float_comp(v.x, x)
			&& loose_float_comp(v.y, y)
			&& loose_float_comp(v.z, z) {
				array_unordered_remove_by_index(*it.positions, idx);
				break;
			}
		}
	}
	
	for world.positions {
		if it.trileName == name {
			array_add(*it.positions, Vector4.{x,y,z,1});
			return;
		}
	}
	poses := TrilePositions.{
		trileName = sprint("%", name),
	};
	
	array_add(*poses.positions, Vector4.{x,y,z,1});
	array_add(*world.positions, poses);
} @Command



tick_level_editor :: () {
	tick_level_editor_camera();
	ray := get_mouse_ray(*get_level_editor_camera());
	hit, point := ray_plane_collision_point(ray, xx editY, 20);
	
	show_trile_preview = false;
	if hit {
		show_trile_preview = true;
		trile_preview_x = xx floor(point.x);
		trile_preview_y = editY;
		trile_preview_z = xx floor(point.y);

		if get_mouse_state(Key_Code.MOUSE_BUTTON_LEFT) & .START {
			handle_tool_click(xx floor(point.x), xx editY, xx floor(point.y));
		}
	}
}

draw_level_editor :: () {
	create_set_cam_rendering_task(get_level_editor_camera());
	create_world_rendering_tasks(*world);
}

draw_level_editor_ui :: (theme: *GR.Overall_Theme) {
    r := GR.get_rect(0, ui_h(5,0), ui_w(20, 20), ui_h(95, 0));
	ui_add_mouse_occluder(r);
    draw_bg_rectangle(r, theme);
    tab_r := r;
    tab_r.h = ui_h(3,0);
    tab_r.w = ui_w(20, 20) / 3;

    if GR.button(tab_r, "Tools", *t_button_tab(theme, current_tab == .TOOLS)) {
		current_tab = .TOOLS;
    }
    tab_r.x += tab_r.w;
    if GR.button(tab_r, "Info", *t_button_tab(theme, current_tab == .INFO)) {
		current_tab = .INFO;
    }
    tab_r.x += tab_r.w;
    if GR.button(tab_r, "Tacoma", *t_button_tab(theme, current_tab == .TACOMA)) {
        current_tab = .TACOMA;
    }
    r.y += tab_r.h;

    if current_tab == {
		case .TOOLS;
			draw_tools_tab(theme, r);
        case .TACOMA;
			draw_tacoma_tab(theme, r);
		case .INFO;
			autoedit(r, *world.conf, theme);
    }
	draw_trile_picker(theme);
}
