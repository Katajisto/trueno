Camera :: struct {
	fov: float = 75.0 * 3.141 / 180.0;
	near: float = 1.0;
	far: float = 20.0;
	position: Vector3 = .{3, 3, 3};
	target: Vector3 = .{0, 0, 0};
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

// TODO: maybe later don't pass in the whole context, but only the width and height.
create_viewproj :: (camera: *Camera) -> Matrix4 {
	return create_lookat(camera) * create_perspective(camera);
}
