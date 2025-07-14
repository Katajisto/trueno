#scope_file

// @ToDo do a config tweak file thing like jblow has and add this there.
CAMERA_INACTIVE_TIME_TO_ORBIT :: 20.0;

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

lastInputTime : float64;

editY : s32;

pointerHit : bool;
pointerX   : s32;
pointerY   : s32;

get_level_editor_camera :: () -> Camera {
    camera: Camera;
    camera.near = 0.1;
    camera.far  = 1000;
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
	if get_time() - lastInputTime > CAMERA_INACTIVE_TIME_TO_ORBIT { // idle rotating camera
		cameraRotation += cast(float) delta_time;
	}

	cameraSpeed :: 5.1;

	forward   : Vector3    = .{1, 0, 0};
    qrotation : Quaternion = .{cos(-cameraRotation/2.0),0,sin(-cameraRotation/2.0),0};
	
	rotate(*forward, qrotation);
	forward2d := Vector2.{forward.x, forward.z};

	left           : Vector3    = .{0, 0, 1};
    qrotation_left : Quaternion = .{cos(-cameraRotation/2.0),0,sin(-cameraRotation/2.0),0};
	rotate(*left, qrotation_left);
	left2d := Vector2.{left.x, left.z};
	 
	if input_button_states[#char "W"] & .DOWN {
		lastInputTime = get_time();
		cameraCenter += -cameraSpeed * (xx delta_time) * forward2d;
	}
	if input_button_states[#char "S"] & .DOWN {
		lastInputTime = get_time();
		cameraCenter += cameraSpeed * (xx delta_time) * forward2d;
	}

	if input_button_states[#char "A"] & .DOWN {
		lastInputTime = get_time();
		cameraCenter += -cameraSpeed * (xx delta_time) * left2d;
	}
	if input_button_states[#char "D"] & .DOWN {
		lastInputTime = get_time();
		cameraCenter += cameraSpeed * (xx delta_time) * left2d;
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
			cameraCenter = cameraCenter + forward2d * -diff.y * cast(float) delta_time * 0.1;
			cameraCenter = cameraCenter + left2d    * -diff.x * cast(float) delta_time * 0.1;
		} else {
			mouse3Active = true;
			mouse3ActivationPosition = Vector2.{input_mouse_x, input_mouse_y};
		}
	} else {
		mouse3Active = false;
	}
	
}

#scope_export

tick_level_editor :: () {
	tick_level_editor_camera();
	
}

draw_level_editor :: () {
	draw_sky(*get_level_editor_camera());
	cam := get_level_editor_camera();
	mvp := create_viewproj(*cam);

	vs_params : Trile_Vs_Params;
	vs_params.mvp = mvp.floats;

	mesh := get_trile_gfx("test");

	sg_apply_pipeline(gPipelines.trile.pipeline);


	bindings : sg_bindings;
	bindings.vertex_buffers[0] = mesh.vertex_buffer;
	bindings.vertex_buffers[1] = mesh.normal_buffer;
	
	sg_apply_bindings(*bindings);
	sg_apply_uniforms(UB_trile_vs_params, *(sg_range.{ ptr = *vs_params, size = size_of(type_of(vs_params))}));

	sg_draw(0, cast(s32) mesh.vertex_count, 1);

	
}

draw_level_editor_ui :: (theme: *GR.Overall_Theme) {
}
