#load "colliders.jai";
#load "worldphysics.jai";

Physics_Body :: struct {
	half_extents : Vector3;
	velocity     : Vector3;
	position     : Vector3;

	// Status, don't write to these outside of the engine physics code:
	on_ground   : bool;
	hit_x       : bool;
	hit_y       : bool;
	hit_z       : bool;

	// Config:
	prevent_falling     : bool = true;
	max_step_height     : float = 0.0;
	gravity             : float = 20;
	downward_probe_dist : float = 0.01;
}

move_body :: (body : *Physics_Body, dt: float) {
	// reset status
	body.on_ground = false;
	body.hit_x = false;
	body.hit_y = false;
	body.hit_z = false;


	// apply velocity XZ
	body.position.x += body.velocity.x * dt;
	if body_overlaps_solid(body) {
		body.hit_x = true;
		if body.velocity.x < 0 {
			hit_cell := floor(body.position.x - body.half_extents.x);
			body.position.x = hit_cell + 1.0 + body.half_extents.x;
		} else {
			hit_cell := floor(body.position.x + body.half_extents.x);
			body.position.x = hit_cell - body.half_extents.x;
		}
		body.velocity.x = 0;
	}

	body.position.z+= body.velocity.z * dt;
	if body_overlaps_solid(body) {
		body.hit_z = true;
		if body.velocity.z < 0 {
			hit_cell := floor(body.position.z - body.half_extents.z);
			body.position.z = hit_cell + 1.0 + body.half_extents.z;
		} else {
			hit_cell := floor(body.position.z + body.half_extents.z);
			body.position.z = hit_cell - body.half_extents.z;
		}
		body.velocity.z = 0;
	}
	
	// gravity
	probe_body := body.*;
	probe_body.position.y -= body.downward_probe_dist;
	if body.velocity.y <= 0 && body_overlaps_solid(*probe_body) {
		// Do this so we don't stutter on the ground
		body.hit_y = true;
		body.on_ground = true;
		body.velocity.y = 0;
		hit_cell := floor(probe_body.position.y - body.half_extents.y);
		body.position.y = hit_cell + 1.0 + body.half_extents.y;
	} else {
		body.velocity.y -= body.gravity * dt;
	}

	// apply velocity Y
	body.position.y += body.velocity.y * dt;
	if body_overlaps_solid(body) {
		body.hit_y = true;
		if body.velocity.y < 0 {
			body.on_ground = true;
			hit_cell := floor(body.position.y - body.half_extents.y);
			body.position.y = hit_cell + 1.0 + body.half_extents.y;
		} else {
			hit_cell := floor(body.position.y + body.half_extents.y);
			body.position.y = hit_cell - body.half_extents.y;
		}
		body.velocity.y = 0;
	}

}
