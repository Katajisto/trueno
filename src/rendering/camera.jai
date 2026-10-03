Camera :: struct {
	fov      : float   = 75.0 * 3.141 / 180.0;
	near     : float   = 0.5;
	far      : float   = 2000.0;
	position : Vector3 = .{2, 2, 2};
	target   : Vector3 = .{0, 0, 0};
}

create_perspective :: (camera: *Camera) -> Matrix4 {

	w, h: s32 = get_window_size();
    

	num : float = 1.0 / tan(camera.fov * 0.5);

	aspect := w / cast(float)h;
	
	return .{
		num / aspect, 0, 0, 0,
		0, num, 0, 0,
		0, 0, camera.far / (camera.near - camera.far), -1,
		0, 0, (camera.near * camera.far) / (camera.near - camera.far), 0
	};
}

create_lookat :: (camera: *Camera) -> Matrix4 {
	up: Vector3 = .{0, 1, 0};
	targetToPos := camera.position - camera.target;
	A := normalize(targetToPos);
	B := normalize(cross(up, A));
	C := cross(A, B);

	return .{
		B.x, C.x, A.x, 0,
		B.y, C.y, A.y, 0,
		B.z, C.z, A.z, 0,
		-dot(B, camera.position), -dot(C, camera.position), -dot(A, camera.position), 1
	};
}

create_viewproj :: (camera: *Camera) -> Matrix4 {
	return create_lookat(camera) * create_perspective(camera);
}

// An orthographic box around focus, seen from the sun. Depth goes 0..1 away from
// the sun. The box moves in whole shadow texels so shadows don't shimmer.
create_sun_viewproj :: (focus: Vector3, sun_direction: Vector3, radius: float, depth: float, map_size: int) -> Matrix4 {
	A := normalize(sun_direction);
	up := ifx abs(A.y) > 0.99 then Vector3.{0, 0, 1} else Vector3.{0, 1, 0};
	B := normalize(cross(up, A));
	C := cross(A, B);

	texel := 2 * radius / map_size;
	cx := floor(dot(B, focus) / texel) * texel;
	cy := floor(dot(C, focus) / texel) * texel;
	cz := dot(A, focus);

	// Rows of the transform; stored transposed like create_lookat.
	m := Matrix4.{
		B.x / radius, B.y / radius, B.z / radius, -cx / radius,
		C.x / radius, C.y / radius, C.z / radius, -cy / radius,
		-A.x / (2 * depth), -A.y / (2 * depth), -A.z / (2 * depth), (cz + depth) / (2 * depth),
		0, 0, 0, 1,
	};
	return transpose(m);
}
