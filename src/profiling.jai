/*
	Profiling functions for profiling the performance of a single frame.
*/

#scope_file

DO_FRAME_PROFILING :: false;

Frame_Point :: struct {
	name  : string;
	time  : Apollo_Time;
	depth : s32;
	type  : Frame_Point_Type;
}

Frame_Point_Type :: enum {
	POINT;
	GROUP_START;
	GROUP_END;
}

add_frame_profiling_point_with_type :: (pointName: string, pointType: Frame_Point_Type) {
	array_add(*current_frame_points, .{pointName, get_apollo_time(), current_depth, pointType});
}


print_point :: (name: string, us: s64, depth: s32, type: Frame_Point_Type) {
	for 0..depth print("  ");
	if type == {
		case .POINT;
			print("(%): %µs\n", name, us);
		case .GROUP_START;
			print("GROUP_START(%): %µs\n", name, us);
		case .GROUP_END;
			print("GROUP_END(%): %µs\n", name, us);
	}
}

current_frame_points : [..]Frame_Point;
current_depth : s32;
#scope_export

clear_frame_profiling :: () {
	#if DO_FRAME_PROFILING {
		array_reset_keeping_memory(*current_frame_points);
		add_frame_profiling_point("frame_start");
	}
}

add_frame_profiling_point :: (pointName: string) {
	#if DO_FRAME_PROFILING {
		add_frame_profiling_point_with_type(pointName, .POINT);
	}
}

start_frame_profiling_group :: (groupName: string) {
	#if DO_FRAME_PROFILING {
		add_frame_profiling_point_with_type(groupName, .GROUP_START);
		current_depth += 1;
	}
}

end_frame_profiling_group :: (groupName: string) {
	#if DO_FRAME_PROFILING {
		current_depth -= 1;
		add_frame_profiling_point_with_type(groupName, .GROUP_END);
	}
}

end_frame_profiling :: () {
	#if DO_FRAME_PROFILING {
		endTime := get_apollo_time();
		startPoint : Apollo_Time;
		startPointSet := false;
	
		print("\n\n-----Frame profiling report ----\n");

		add_frame_profiling_point("frame_end");
	
		for current_frame_points {
			if !startPointSet {
				startPoint = it.time;
				startPointSet = true;
				print_point(it.name, 0, it.depth, it.type);
			} else {
				startUs := to_microseconds(startPoint);
				curUs   := to_microseconds(it.time);
				print_point(it.name, curUs - startUs, it.depth, it.type);
			}
		}
	}
}

