#scope_export

#load "backend.jai";

// Core rendering function, runs several passes.
render :: () {
    tasks_to_commands();
    process_command_buckets();
    // // @ToDo: Consider a depth pre-pass here? Research required.
    // shadow_pass();   
    // reflection_pass();
    // forward_pass();
    // // @ToDo: Post-processing.
}

#scope_file

