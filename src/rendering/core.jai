#scope_export

#load "backend.jai";

init_rendering :: () {
    init_ssao();
}

// Core rendering function, runs several passes.
render :: () {
    tasks_to_commands();
    add_frame_profiling_point("After task->command conversion");
    start_frame_profiling_group("Rendering command bucket processing");
    process_command_buckets();
    end_frame_profiling_group("Rendering command bucket processing");
}

#scope_file

