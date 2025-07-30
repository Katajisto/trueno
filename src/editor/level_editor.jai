#scope_file

// @ToDo do a config tweak file thing like jblow has and add this there.
CAMERA_INACTIVE_TIME_TO_ORBIT :: 20.0;
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
	
	cameraDist = clamp(cameraDist - mouse_delta_z * DIST_SCROLL_SPEED, MIN_CAMERA_DIST, MAX_CAMERA_DIST);

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
	
	if input_button_states[Key_Code.MOUSE_BUTTON_RIGHT] & .DOWN {
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


	if input_button_states[Key_Code.MOUSE_BUTTON_MIDDLE] & .DOWN {
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
			test_gen(tacomaResolution, tacomaResolution, .{tacomaExposure, tacomaContrast, tacomaSaturation}, .{cam.target, cam.position, tacomaSamples, true}, world.conf);
		}
		r.y += r.h;
		if current_screenshot.valid {
			aspect := cast(float)current_screenshot.width / cast(float)current_screenshot.height;
			
			r.h = r.w / aspect;
			uiTex := Ui_Texture.{*current_screenshot.image};
			set_shader_for_images(*uiTex);
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

#scope_export

tick_level_editor :: () {
	tick_level_editor_camera();
	
}

draw_level_editor :: () {
	positions : [4096]Vector4;
	positions[0] = .{1, 0, 0, 1};
	positions[1] = .{0, 1, 1, 1};

	draw_sky(*get_level_editor_camera(), *world.conf);
	cam := get_level_editor_camera();
	mvp := create_viewproj(*cam);

	vs_params : Trile_Vs_Params;
	vs_params.mvp = mvp.floats;
    vs_params.camera = cam.position.component;

	trilegfx := get_trile_gfx("test");

    sg_update_buffer(gPipelines.trile.bind.vertex_buffers[3], *(sg_range.{
        ptr = positions.data,
        size = size_of(type_of(positions)),
    }));

	sg_apply_pipeline(gPipelines.trile.pipeline);

    world_conf : Trile_World_Config;
    world_config_to_shader_type(*world.conf, *world_conf);


	bindings : sg_bindings;
	bindings.vertex_buffers[0] = trilegfx.vertex_buffer;
	bindings.vertex_buffers[1] = trilegfx.normal_buffer;
	bindings.vertex_buffers[2] = trilegfx.centre_buffer;
	bindings.vertex_buffers[3] = gPipelines.trile.bind.vertex_buffers[3];
    bindings.samplers[0]       = gPipelines.trile.bind.samplers[0];
	bindings.images[0]         = trilegfx.trixel_colors;
	
	sg_apply_bindings(*bindings);
	sg_apply_uniforms(UB_trile_vs_params, *(sg_range.{ ptr = *vs_params, size = size_of(type_of(vs_params))}));
    sg_apply_uniforms(UB_trile_world_config, *(sg_range.{ptr = *world_conf, size = size_of(type_of(world_conf))}));

	sg_draw(0, cast(s32) trilegfx.vertex_count, 2);

	
}

draw_level_editor_ui :: (theme: *GR.Overall_Theme) {
    r := GR.get_rect(0, ui_h(5,0), ui_w(20, 20), ui_h(95, 0));
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
        case .TACOMA;
			draw_tacoma_tab(theme, r);
		case .INFO;
			autoedit(r, *world.conf, theme);
    }
}
