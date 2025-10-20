#scope_export

#load "backend.jai";

init_rendering :: () {
    init_ssao();
}

// Core rendering function, runs several passes.
render :: () {
    tasks_to_commands();
    process_command_buckets();
}

#scope_file

