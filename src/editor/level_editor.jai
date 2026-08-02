#scope_file

// @ToDo do a config tweak file thing like jblow has and add this there.
CAMERA_INACTIVE_TIME_TO_ORBIT :: 200000000.0;
MAX_CAMERA_DIST               :: 25.0;
MIN_CAMERA_DIST               :: 2.0;
DIST_SCROLL_SPEED             :: 0.8;

mouse1Active             : bool;
mouse1ActivationPosition : Vector2;
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
    INSPECTOR;
    VIEWER;
    ENTITY;
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

inspector_selected      : bool;
inspector_x             : s32;
inspector_y             : s32;
inspector_z             : s32;
inspector_emitter_def   : s32 = -1;
inspector_rdm_roughness : int = 0;
inspector_note_deactivate    : bool;
inspector_note_activate_next : bool;

// Entity tool: click to select, drag the gizmo to move or turn, right-click to
// place. The selection is held by id rather than index so removing an entity
// can't silently reselect another.
Entity_Gizmo_Mode :: enum {
    MOVE;
    ROTATE;
}

entity_gizmo        : Gizmo_State;
entity_gizmo_mode   : Entity_Gizmo_Mode;
entity_selected_id  : s64 = -1;
entity_add_type     : s32 = -1;
entity_snap_enabled : bool  = true;
entity_snap_step    : float = 1.0;

editor_billboards_visible : bool = true;

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
tacoma_tab_scroll : float = 0;

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
	
	if current_tool_mode == .VIEWER && get_mouse_state(Key_Code.MOUSE_BUTTON_LEFT) & .DOWN {
		if mouse1Active {
			lastInputTime = get_time();
			diff := mouse1ActivationPosition - Vector2.{input_mouse_x, input_mouse_y};
			diff *= 0.5;
			cameraRotation = oldCameraRotation + diff.x / 100;
			cameraTilt = oldCameraTilt - diff.y / 100;
			cameraTilt = max(0.1, cameraTilt);
			cameraTilt = min(PI/2.2, cameraTilt);
		} else {
			mouse1Active = true;
			mouse1ActivationPosition = Vector2.{input_mouse_x, input_mouse_y};
			oldCameraRotation = cameraRotation;
			oldCameraTilt = cameraTilt;
		}
	} else {
		mouse1Active = false;
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
	#if FLAG_TACOMA_ENABLED {
		region, inside := GR.begin_scrollable_region(total_r, *theme.scrollable_region_theme);
		r := inside;
		r.y -= tacoma_tab_scroll;
		r.h = ui_h(3,0);
		if GR.button(r, "Render with Tacoma", *theme.button_theme) {
			cam := get_level_editor_camera();
			gen_reference(tacomaResolution, tacomaResolution, cam.position, cam.target, tacomaSamples, true, curworld.world);
		}
		r.y += r.h;
		if GR.button(r, "Bake all chunk RDMs", *theme.button_theme) {
			if curworld.valid then rdm_bake_all_chunks(curworld.world, tacomaSamples, true);
		}
		r.y += r.h;
		if GR.button(r, "Bake all chunk SH grids", *t_button_selectable(theme, !sh_bake.active)) {
			if curworld.valid && !sh_bake.active  sh_bake_start(tacomaSamples);
		}
		r.y += r.h;
		if rdm_bake.active {
			total := cast(s32) rdm_bake.jobs.count;
			done  := rdm_bake.current_job;
			pct   := ifx total > 0 then done * 100 / total else 0;
			GR.label(r, tprint("Baking RDMs: %/% (\%%)", done, total, pct), *t_label_left(theme));
			r.y += r.h;
		}
		if sh_bake.active {
			total := cast(s32) sh_bake.chunk_keys.count;
			done  := sh_bake.current_chunk;
			pct   := ifx total > 0 then done * 100 / total else 0;
			GR.label(r, tprint("Baking SH grids: %/% (\%%)", done, total, pct), *t_label_left(theme));
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
		GR.label(r, tprint("Sky Scale (bake): %", formatFloat(bake_sky_scale, trailing_width=2)), *t_label_left(theme));
		r.y += r.h;
		GR.slider(r, *bake_sky_scale, 0.0, 5.0, 0.05, *theme.slider_theme);
		r.y += r.h;
		GR.label(r, tprint("Sky Desaturation (bake): %", formatFloat(bake_sky_desaturation, trailing_width=2)), *t_label_left(theme));
		r.y += r.h;
		GR.slider(r, *bake_sky_desaturation, 0.0, 1.0, 0.05, *theme.slider_theme);
		r.y += r.h;

		GR.end_scrollable_region(region, r.x + r.w, r.y, *tacoma_tab_scroll);
	} else {
		r := total_r;
		r.h = ui_h(3,0);
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
	if keybind_button(r, "Inspector", .LEVEL_TOOL_INSPECTOR, *t_button_selectable(theme, current_tool_mode == .INSPECTOR)) then current_tool_mode = .INSPECTOR;
	r.y += r.h;
	if keybind_button(r, "Entity", .LEVEL_TOOL_ENTITY, *t_button_selectable(theme, current_tool_mode == .ENTITY)) then current_tool_mode = .ENTITY;
	r.y += r.h;
	if keybind_button(r, "Viewer", .LEVEL_TOOL_VIEWER, *t_button_selectable(theme, current_tool_mode == .VIEWER)) then current_tool_mode = .VIEWER;
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
	} else if current_tool_mode == .INSPECTOR || current_tool_mode == .ENTITY {
		r.h = ui_h(3, 2);
		if GR.button(r, ifx editor_billboards_visible then "Hide Markers" else "Show Markers", *theme.button_theme, 199) {
			editor_billboards_visible = !editor_billboards_visible;
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
	added := false;
	for *group: chunk.groups {
		if group.trile_name == name {
			array_add(*group.instances, inst);
			added = true;
			break;
		}
	}
	if !added {
		group: Chunk_Trile_Group;
		group.trile_name = sprint("%", name);
		array_add(*group.instances, inst);
		array_add(*chunk.groups, group);
	}
	invalidate_buried_around(*curworld.world, x, y, z);
} @Command

remove_trile :: (x: s32, y: s32, z: s32) {
	curworld := get_current_world();

	key := world_to_chunk_coord(x, y, z);
	chunk := table_find_pointer(*curworld.world.chunks, key);
	if !chunk then return;

	lx, ly, lz := world_to_local(x, y, z);

	removed := false;
	for *group: chunk.groups {
		for inst, idx: group.instances {
			if inst.x == lx && inst.y == ly && inst.z == lz {
				array_unordered_remove_by_index(*group.instances, idx);
				if group.is_buried.count > idx {
					array_unordered_remove_by_index(*group.is_buried, idx);
				}
				removed = true;
				break;
			}
		}
		if removed  break;
	}
	if removed  invalidate_buried_around(*curworld.world, x, y, z);
} @Command



level_editor_clear_entity_selection :: () {
	entity_selected_id  = -1;
	entity_gizmo.hover  = .NONE;
	entity_gizmo.active = .NONE;
}

get_selected_entity :: (world: *World) -> *Entity {
	if entity_selected_id < 0 then return null;
	for e: world.entities  if cast(s64)e.id == entity_selected_id  return e;
	return null;
}

// World-space box covering an entity's cell plus every part it draws, used for
// click-picking and for the selection outline.
entity_bounds :: (e: *Entity) -> (mn: Vector3, mx: Vector3) {
	mn := e.position;
	mx := e.position + Vector3.{1, 1, 1};
	for part: get_entity_parts(e.type) {
		p, q : Vector3 = ---;
		if part.kind == .TRILE {
			p = entity_trile_point(e, part.offset);
			q = p + Vector3.{1, 1, 1};
		} else {
			// Billboards and emitters are points; give them enough of a box to click.
			c := entity_point(e, part.offset);
			p = c - Vector3.{0.25, 0.25, 0.25};
			q = c + Vector3.{0.25, 0.25, 0.25};
		}
		mn.x = min(mn.x, p.x); mn.y = min(mn.y, p.y); mn.z = min(mn.z, p.z);
		mx.x = max(mx.x, q.x); mx.y = max(mx.y, q.y); mx.z = max(mx.z, q.z);
	}
	return mn, mx;
}

// The billboard that stands in for an entity in the editor: the type's declared
// EDITOR_MARKER, or a default one when the entity draws nothing you could aim
// at. Null for entities that are already visible on their own.
entity_marker_animation :: (e: *Entity) -> *Animation {
	marker := get_entity_editor_marker(e.type);
	if marker.count > 0  return get_animation_from_string(marker);
	for part: get_entity_parts(e.type) {
		if part.kind == .TRILE || part.kind == .BILLBOARD  return null;
	}
	return get_animation_from_string("game_core.ball");
}

pick_entity :: (world: *World, ray: Ray) -> *Entity {
	best      : *Entity = null;
	best_dist : float   = FLOAT32_MAX;
	for e: world.entities {
		mn, mx := entity_bounds(e);
		col := does_ray_hit_cube(ray, .{position = mn, size = mx - mn});
		if !col.hit then continue;
		d := abs(col.distance);
		if d < best_dist {
			best_dist = d;
			best      = e;
		}
	}
	return best;
}

snap_to_step :: (v: float, step: float) -> float {
	if step <= 0 then return v;
	return floor(v / step + 0.5) * step;
}

tick_entity_tool :: (ray: Ray) {
	curworld := get_current_world();
	if !curworld.valid then return;
	world := *curworld.world;

	e := get_selected_entity(world);
	if e == null {
		entity_gizmo.hover  = .NONE;
		entity_gizmo.active = .NONE;
	} else {
		mn, mx := entity_bounds(e);
		debug_aabb_3d_overlay(mn, mx, .{1.0, 0.75, 0.1, 0.8}, 2.0);

		// The gizmo sits at the middle of the entity's cell, which is both what
		// the entity's marker draws on and what it rotates about.
		cam := get_level_editor_camera();
		origin := e.position + ENTITY_PIVOT;
		if entity_gizmo_mode == .MOVE {
			moved, changed := gizmo_translate(*entity_gizmo, origin, cam, ray);
			if changed {
				p := moved - ENTITY_PIVOT;
				if entity_snap_enabled {
					p.x = snap_to_step(p.x, entity_snap_step);
					p.y = snap_to_step(p.y, entity_snap_step);
					p.z = snap_to_step(p.z, entity_snap_step);
				}
				e.position = p;
			}
		} else {
			u, v, n, steps := gizmo_rotate(*entity_gizmo, origin, cam, ray);
			if steps != 0 {
				// A negative drag is the same turn taken the other way round.
				turn := ifx steps > 0 then orientation_quarter_turn(u, v, n) else orientation_quarter_turn(v, u, n);
				for 1..abs(steps)  e.orientation = compose_orientations(turn, e.orientation);
			}
		}
		for *inst: e.emitters  inst.position = entity_point(e, inst.offset);
	}

	// A click that didn't land on the gizmo selects (or clears) the selection.
	if entity_gizmo.active == .NONE && entity_gizmo.hover == .NONE {
		if get_mouse_state(Key_Code.MOUSE_BUTTON_LEFT) & .START {
			picked := pick_entity(world, ray);
			entity_selected_id = ifx picked then cast(s64)picked.id else cast(s64)-1;
		}
	}
}

editor_edit_y :: () -> float {
    y := cast(float)editY;
    curworld := get_current_world();
    if curworld.valid {
        ph := effective_plane_height(*curworld.world.conf);
        if ph > y && ph < y + 1.0 then y = ph + 0.01;
    }
    return y;
}

tick_level_editor :: () {
	#if FLAG_TACOMA_ENABLED { rdm_bake_tick(); sh_bake_tick(); }
	tick_level_editor_camera();
	tick_particles(cast(float)delta_time);

	curworld := get_current_world();
	if curworld.valid then tick_entity_emitters(*curworld.world, cast(float)delta_time);

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

	cam := get_level_editor_camera();
	ray := get_mouse_ray(*cam);
	hit, point := ray_plane_collision_point(ray, editor_edit_y(), 20);

	// The entity tool works off the entities themselves, not the edit plane, so
	// it runs whether or not the cursor is over the plane.
	if current_tool_mode == .ENTITY then tick_entity_tool(ray);

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
		} else if current_tool_mode == .INSPECTOR {
			if get_mouse_state(Key_Code.MOUSE_BUTTON_LEFT) & .START {
				inspector_selected = true;
				inspector_x = cast(s32)px;
				inspector_y = cast(s32)py;
				inspector_z = cast(s32)pz;
				inspector_note_deactivate = true;
			}
		} else if current_tool_mode == .ENTITY {
			// Right-click places the type picked in the panel, so the cursor never
			// has to leave the spot you're aiming at.
			if get_mouse_state(Key_Code.MOUSE_BUTTON_RIGHT) & .START {
				add_entity_at(cast(s32)px, cast(s32)py, cast(s32)pz);
			}
		}
	}
}

create_level_editor_preview_tasks :: () {
	curworld := get_current_world();
	if !curworld.valid then return;

	px := trile_preview_x; py := trile_preview_y; pz := trile_preview_z;

	// The entity tool never paints triles, so it shows no brush preview.
	if current_tool_mode == .ENTITY then return;

	if current_tool_mode == .INSPECTOR {
		name, orientation, found := get_trile_at(*curworld.world, xx px, xx py, xx pz);
		cursor_trile := ifx found then name else (ifx editor_current_trile then editor_current_trile.name else "");
		if cursor_trile != "" {
			ck := world_to_chunk_coord(xx px, xx py, xx pz);
			lx, ly, lz := world_to_local(xx px, xx py, xx pz);
			positions: [..]Trile_Instance;
			positions.allocator = temp;
			array_add(*positions, Trile_Instance.{lx, ly, lz, xx orientation});
			task: Rendering_Task_Trile;
			task.trile        = cursor_trile;
			task.positions    = positions;
			task.worldConf    = *curworld.world.conf;
			task.preview_mode = 1;
			task.chunk_key    = ck;
			add_rendering_task(task);
		}
		return;
	}

	if !editor_current_trile then return;

	positions: [..]Vector4;
	positions.allocator = temp;
	ori_u8 := get_current_orientation();
	ori := cast(float) ori_u8;

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
			// array_add(*positions, .{cast(float)px, cast(float)py, cast(float)pz, ori});
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
			// array_add(*positions, .{cast(float)px, cast(float)py, cast(float)pz, ori});
		}
	}

	if positions.count == 0 then return;

	is_delete := (current_tool_mode == .AREA && area_active && area_delete)
	          || (current_tool_mode == .LINE && line_active && line_delete);

	chunk_groups: [..] struct { key: Chunk_Key; instances: [..]Trile_Instance; };
	chunk_groups.allocator = temp;
	for pos : positions {
		wx := cast(s32) pos.x; wy := cast(s32) pos.y; wz := cast(s32) pos.z;
		ck := world_to_chunk_coord(wx, wy, wz);
		lx, ly, lz := world_to_local(wx, wy, wz);
		found := false;
		for *grp : chunk_groups {
			if grp.key == ck {
				array_add(*grp.instances, Trile_Instance.{lx, ly, lz, ori_u8});
				found = true;
				break;
			}
		}
		if !found {
			instances: [..]Trile_Instance;
			instances.allocator = temp;
			array_add(*instances, Trile_Instance.{lx, ly, lz, ori_u8});
			array_add(*chunk_groups, .{ck, instances});
		}
	}

	for grp : chunk_groups {
		task: Rendering_Task_Trile;
		task.trile        = editor_current_trile.name;
		task.positions    = grp.instances;
		task.worldConf    = *curworld.world.conf;
		task.chunk_key    = grp.key;
		task.preview_mode = ifx is_delete then cast(s32)2 else cast(s32)1;
		add_rendering_task(task);
	}
}

get_trile_at :: (world: *World, wx: s32, wy: s32, wz: s32) -> (name: string, orientation: u8, found: bool) {
	key := world_to_chunk_coord(wx, wy, wz);
	chunk := table_find_pointer(*world.chunks, key);
	if !chunk then return "", 0, false;
	lx, ly, lz := world_to_local(wx, wy, wz);
	for group: chunk.groups {
		for inst: group.instances {
			if inst.x == lx && inst.y == ly && inst.z == lz {
				return group.trile_name, inst.orientation, true;
			}
		}
	}
	return "", 0, false;
}

find_emitter_at :: (world: *World, x: s32, y: s32, z: s32) -> (idx: s32, found: bool) {
	for inst, i: world.emitter_instances {
		ix := cast(s32)floor(inst.position.x);
		iy := cast(s32)floor(inst.position.y);
		iz := cast(s32)floor(inst.position.z);
		if ix == x && iy == y && iz == z then return cast(s32)i, true;
	}
	return -1, false;
}

find_note_at :: (world: *World, x: s32, y: s32, z: s32) -> (idx: s32, found: bool) {
	for note, i: world.notes {
		if note.position.x == x && note.position.y == y && note.position.z == z then return cast(s32)i, true;
	}
	return -1, false;
}

draw_inspector_panel :: (r: *GR.Rect, theme: *GR.Overall_Theme) {
	curworld := get_current_world();
	if !curworld.valid then return;
	world := *curworld.world;

	r.h = ui_h(3, 2);
	GR.label(r.*, tprint("Slot: (%, %, %)", inspector_x, inspector_y, inspector_z), *t_label_left(theme));
	r.y += r.h;

	trile_name, orientation, has_trile := get_trile_at(world, inspector_x, inspector_y, inspector_z);
	if has_trile {
		GR.label(r.*, tprint("Trile: %  orient: %", trile_name, orientation), *t_label_left(theme));
		r.y += r.h;
		r.h = ui_h(3, 2);
		GR.label(r.*, "-- RDM --", *t_label_left(theme));
		r.y += r.h;
		r.h = ui_h(4, 0);
		rdm_on := is_rdm_instance_enabled(world, inspector_x, inspector_y, inspector_z);
		label := ifx rdm_on then "RDM: ON  (sharp specular)" else "RDM: OFF (sky reflection)";
		if GR.button(r.*, label, *theme.button_theme, 300) {
			set_rdm_instance_enabled(world, inspector_x, inspector_y, inspector_z, !rdm_on);
		}
		r.y += r.h;

		if rdm_on {
			cur_size := get_rdm_instance_size(world, inspector_x, inspector_y, inspector_z);
			tile_w := 2 * cur_size;
			tile_h := 3 * cur_size;
			size_label := tprint("Size: % (% x % px)", cur_size, tile_w, tile_h);
			GR.label(r.*, size_label, *t_label_left(theme));
			r.y += r.h;

			r2 := r.*;
			r2.w = r.w / 2;
			if GR.button(r2, "- size", *theme.button_theme, 304) {
				set_rdm_instance_size(world, inspector_x, inspector_y, inspector_z, rdm_cycle_size(cur_size, -1));
			}
			r2.x += r2.w;
			if GR.button(r2, "+ size", *theme.button_theme, 305) {
				set_rdm_instance_size(world, inspector_x, inspector_y, inspector_z, rdm_cycle_size(cur_size, +1));
			}
			r.y += r.h;
		}
	} else {
		GR.label(r.*, "Trile: (empty)", *t_label_left(theme));
		r.y += r.h;
	}

	r.y += r.h * 0.5;
	GR.label(r.*, "-- Emitter --", *t_label_left(theme));
	r.y += r.h;

	emitter_idx, has_emitter := find_emitter_at(world, inspector_x, inspector_y, inspector_z);
	if has_emitter {
		inst := *world.emitter_instances[emitter_idx];
		GR.label(r.*, tprint("Def: %", inst.definition_name), *t_label_left(theme));
		r.y += r.h;
		r.h = ui_h(4, 0);
		GR.label(r.*, tprint("Offset X: %", formatFloat(inst.offset.x, trailing_width=2)), *t_label_left(theme));
		r.y += r.h;
		GR.slider(r.*, *inst.offset.x, -0.5, 0.5, 0.05, *theme.slider_theme);
		r.y += r.h;
		GR.label(r.*, tprint("Offset Y: %", formatFloat(inst.offset.y, trailing_width=2)), *t_label_left(theme));
		r.y += r.h;
		GR.slider(r.*, *inst.offset.y, -0.5, 0.5, 0.05, *theme.slider_theme);
		r.y += r.h;
		GR.label(r.*, tprint("Offset Z: %", formatFloat(inst.offset.z, trailing_width=2)), *t_label_left(theme));
		r.y += r.h;
		GR.slider(r.*, *inst.offset.z, -0.5, 0.5, 0.05, *theme.slider_theme);
		r.y += r.h;
		if GR.button(r.*, "Remove Emitter", *theme.button_theme, 300) {
			array_ordered_remove_by_index(*world.emitter_instances, emitter_idx);
		}
		r.y += r.h;
	} else {
		r.h = ui_h(4, 0);
		GR.label(r.*, "Select emitter def:", *t_label_left(theme));
		r.y += r.h;
		for def, idx: g_emitter_defs {
			selected := (cast(s32)idx == inspector_emitter_def);
			if GR.button(r.*, def.name, *t_button_selectable(theme, selected), cast(s32)(200 + idx)) {
				inspector_emitter_def = cast(s32)idx;
			}
			r.y += r.h;
		}
		if inspector_emitter_def >= 0 && inspector_emitter_def < cast(s32)g_emitter_defs.count {
			if GR.button(r.*, "Add Emitter", *theme.button_theme, 301) {
				def := *g_emitter_defs[inspector_emitter_def];
				inst : Particle_Emitter_Instance;
				inst.definition = def;
				inst.definition_name = def.name;
				inst.position = .{cast(float)inspector_x + 0.5, cast(float)inspector_y, cast(float)inspector_z + 0.5};
				inst.active = true;
				array_add(*world.emitter_instances, inst);
			}
			r.y += r.h;
		}
	}

	r.h = ui_h(3, 2);
	r.y += r.h * 0.5;
	GR.label(r.*, "-- Note --", *t_label_left(theme));
	r.y += r.h;

	note_idx, has_note := find_note_at(world, inspector_x, inspector_y, inspector_z);
	note_input_action : GR.Text_Input_Action;
	if inspector_note_activate_next {
		note_input_action = .ACTIVATE;
		inspector_note_activate_next = false;
	} else if inspector_note_deactivate {
		note_input_action = .DEACTIVATE;
		inspector_note_deactivate = false;
	}
	if has_note {
		note := *world.notes[note_idx];
		r.h = ui_h(4, 0);
		note_id := cast(s64)inspector_x * 1000003 + cast(s64)inspector_y * 1009 + cast(s64)inspector_z;
		a, _, note_state := GR.text_input(r.*, note.text, *theme.text_input_theme, note_id, input_action = note_input_action);
		if (a & .TEXT_MODIFIED) || (a & .ENTERED)  note.text = copy_string(note_state.text);
		r.y += r.h;
		if GR.button(r.*, "Remove Note", *theme.button_theme, 302) {
			array_ordered_remove_by_index(*world.notes, note_idx);
		}
		r.y += r.h;
	} else {
		r.h = ui_h(4, 0);
		if GR.button(r.*, "Add Note", *theme.button_theme, 303) {
			note : Editor_Note;
			note.position = .{inspector_x, inspector_y, inspector_z};
			note.text = "";
			array_add(*world.notes, note);
			inspector_note_activate_next = true;
		}
		r.y += r.h;
	}

	r.h = ui_h(3, 2);
	r.y += r.h * 0.5;
	GR.label(r.*, "-- RDM --", *t_label_left(theme));
	r.y += r.h;

	rdm_flagged := is_rdm_instance_enabled(world, inspector_x, inspector_y, inspector_z);
	if rdm_flagged {
		GR.label(r.*, "RDM: flagged", *t_label_left(theme));
		r.y += r.h;

		rect, has_rect := rdm_get_atlas_rect(world, inspector_x, inspector_y, inspector_z);
		if has_rect {
			GR.label(r.*, tprint("Rect: %.2,%.2  %.2x%.2", rect.x, rect.y, rect.z, rect.w), *t_label_left(theme));
			r.y += r.h;

			r.y += r.h * 0.5;
			tex_size := r.w * 0.9;
			tex_r : GR.Rect;
			tex_r.x = r.x + (r.w - tex_size) * 0.5;
			tex_r.y = r.y;
			tex_r.w = tex_size;
			tex_r.h = tex_size * 1.5;

			fy0 := 1.0 - rect.y;
			fy1 := 1.0 - (rect.y + rect.w);
			uv0 := Vector2.{rect.x, fy0};
			uv1 := Vector2.{rect.x + rect.z, fy0};
			uv2 := Vector2.{rect.x + rect.z, fy1};
			uv3 := Vector2.{rect.x, fy1};

			uiTex := New(Ui_Texture,, temp);
			uiTex.tex = g_rdm_atlas;
			if uiTex.tex.id != INVALID_ID {
				set_shader_for_images(uiTex);
				immediate_quad(
					.{tex_r.x, tex_r.y},
					.{tex_r.x + tex_r.w, tex_r.y},
					.{tex_r.x + tex_r.w, tex_r.y + tex_r.h},
					.{tex_r.x, tex_r.y + tex_r.h},
					.{1,1,1,1},
					uv0, uv1, uv2, uv3
				);
				set_shader_for_color();
				immediate_flush();
			}
			r.y += tex_r.h + r.h * 0.5;
		} else {
			GR.label(r.*, "RDM: not yet baked", *t_label_left(theme));
			r.y += r.h;
		}
	} else {
		GR.label(r.*, "RDM: not flagged", *t_label_left(theme));
		r.y += r.h;
	}
}

draw_entity_tool_panel :: (r: *GR.Rect, theme: *GR.Overall_Theme) {
	curworld := get_current_world();
	if !curworld.valid then return;
	world := *curworld.world;

	r.h = ui_h(3, 2);
	GR.label(r.*, "-- Entity Tool --", *t_label_left(theme));
	r.y += r.h;

	e := get_selected_entity(world);
	if e != null {
		GR.label(r.*, tprint("Type: %", entity_type_name(e.type)), *t_label_left(theme));
		r.y += r.h;
		GR.label(r.*, tprint("Pos: %, %, %",
			formatFloat(e.position.x, trailing_width=2),
			formatFloat(e.position.y, trailing_width=2),
			formatFloat(e.position.z, trailing_width=2)), *t_label_left(theme));
		r.y += r.h;

		GR.label(r.*, tprint("Orientation: %", e.orientation), *t_label_left(theme));
		r.y += r.h;

		r.h = ui_h(4, 0);
		mode_r := r.*;
		mode_r.w = r.w / 2;
		if GR.button(mode_r, "Move", *t_button_selectable(theme, entity_gizmo_mode == .MOVE), 524) {
			entity_gizmo_mode = .MOVE;
			entity_gizmo.active = .NONE;
		}
		mode_r.x += mode_r.w;
		if GR.button(mode_r, "Rotate", *t_button_selectable(theme, entity_gizmo_mode == .ROTATE), 525) {
			entity_gizmo_mode = .ROTATE;
			entity_gizmo.active = .NONE;
		}
		r.y += r.h;

		// Rotation is always in quarter turns, so snapping is a move-only setting.
		if entity_gizmo_mode == .MOVE {
			snap_label := ifx entity_snap_enabled then tprint("Snap: %", formatFloat(entity_snap_step, trailing_width=2)) else "Snap: off";
			if GR.button(r.*, snap_label, *t_button_selectable(theme, entity_snap_enabled), 520) {
				entity_snap_enabled = !entity_snap_enabled;
			}
			r.y += r.h;
			if entity_snap_enabled {
				GR.slider(r.*, *entity_snap_step, 0.125, 1.0, 0.125, *theme.slider_theme);
				r.y += r.h;
			}
		}

		fields_r := r.*;
		fields_r.h = ui_h(30, 0);
		entity_autoedit(fields_r, e, theme);
		r.y += fields_r.h;

		if GR.button(r.*, "Remove Entity", *theme.button_theme, 521) {
			remove_entity(world, e);
			level_editor_clear_entity_selection();
		}
		r.y += r.h;
		if GR.button(r.*, "Deselect", *theme.button_theme, 522) {
			level_editor_clear_entity_selection();
		}
		r.y += r.h;
	} else {
		GR.label(r.*, "Click an entity to select it.", *t_label_left(theme));
		r.y += r.h;
		GR.label(r.*, "Drag the gizmo to move or turn.", *t_label_left(theme));
		r.y += r.h;
	}

	r.h = ui_h(3, 2);
	r.y += r.h * 0.5;
	GR.label(r.*, "-- Spawn --", *t_label_left(theme));
	r.y += r.h;

	r.h = ui_h(4, 0);
	for info, idx: ENTITY_TYPE_TABLE {
		selected := cast(s32)idx == entity_add_type;
		if GR.button(r.*, info.name, *t_button_selectable(theme, selected), cast(s32)(500 + idx)) {
			entity_add_type = cast(s32)idx;
		}
		r.y += r.h;
	}
	r.h = ui_h(3, 2);
	if entity_add_type >= 0 && entity_add_type < cast(s32)ENTITY_TYPE_TABLE.count {
		GR.label(r.*, "Right-click in the world to place.", *t_label_left(theme));
	} else {
		GR.label(r.*, "Pick a type to place.", *t_label_left(theme));
	}
	r.y += r.h;
}

// Places the type picked in the panel. Called from the right-click handler, so
// the position is whatever cell the cursor is over on the edit plane.
add_entity_at :: (x: s32, y: s32, z: s32) {
	if entity_add_type < 0 || entity_add_type >= cast(s32)ENTITY_TYPE_TABLE.count then return;
	curworld := get_current_world();
	if !curworld.valid then return;
	spawned := spawn_entity(*curworld.world, ENTITY_TYPE_TABLE[entity_add_type].name, .{cast(float)x, cast(float)y, cast(float)z});
	if spawned then entity_selected_id = cast(s64)spawned.id;
}

// Runs autoedit on the entity's concrete type, so each type gets an editor
// generated from its own fields.
entity_autoedit :: (rect: GR.Rect, e: *Entity, theme: *GR.Overall_Theme) {
	#insert #run,stallable gen_entity_dispatch("autoedit(rect, cast(*%)e, theme, 400)");
}

add_editor_billboards :: () {
	if !editor_billboards_visible then return;
	curworld := get_current_world();
	if !curworld.valid then return;

	// Entities are marked first, before the fallback animation is required, so a
	// type with its own EDITOR_MARKER still shows up if "game_core.ball" is gone.
	for e: curworld.world.entities {
		marker := entity_marker_animation(e);
		if marker == null then continue;
		task : Rendering_Task_Billboard;
		task.position  = e.position + ENTITY_PIVOT;
		task.animation = marker;
		task.frame     = 0;
		add_rendering_task(task);
	}

	anim := get_animation_from_string("game_core.ball");
	if anim == null then return;

	for inst: curworld.world.emitter_instances {
		task : Rendering_Task_Billboard;
		task.position = inst.position;
		task.animation = anim;
		task.frame = 0;
		add_rendering_task(task);
	}

	for note: curworld.world.notes {
		task : Rendering_Task_Billboard;
		task.position = .{cast(float)note.position.x + 0.5, cast(float)note.position.y + 0.5, cast(float)note.position.z + 0.5};
		task.animation = anim;
		task.frame = 0;
		add_rendering_task(task);
	}
}

draw_level_editor :: () {
	curworld := get_current_world();
	if !curworld.valid then return;
	cam := get_level_editor_camera();
	ph := effective_plane_height(*curworld.world.conf);
	create_set_cam_rendering_task(cam, ph);
	create_world_rendering_tasks(*curworld.world, cam, ph);
	add_entity_render_tasks(*curworld.world);
	if show_trile_preview && !trile_preview_disabled {
		create_level_editor_preview_tasks();
	}
	add_editor_billboards();
	debug_grid(floor(cameraCenter.x), editor_edit_y(), floor(cameraCenter.y), 20, .{0.3, 0.3, 0.35, 0.7});
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
	if current_tool_mode == .INSPECTOR || current_tool_mode == .ENTITY {
		rr := GR.get_rect(ui_w(85,0), ui_h(5,0), ui_w(15, 0), ui_h(95, 0));
		draw_bg_rectangle(rr, theme);
		ui_add_mouse_occluder(rr);
		rr.y += ui_h(1, 0);
		if current_tool_mode == .ENTITY {
			draw_entity_tool_panel(*rr, theme);
		} else if inspector_selected {
			draw_inspector_panel(*rr, theme);
		} else {
			rr.h = ui_h(3, 2);
			GR.label(rr, "Click a slot to inspect", *t_label_left(theme));
		}
	} else if current_tool_mode != .VIEWER {
		draw_picker(theme);
	}
}
