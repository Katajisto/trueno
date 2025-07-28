#scope_file

get_shader_paths :: () -> []string {
    util :: #import "File_Utilities";
    return util.file_list("./src/shaders/jai");
}

#scope_export

add_shaders_to_workspace :: (w: Workspace) {
    file :: #import "File";
    paths := get_shader_paths();
    for paths {
        add_build_file(file.get_absolute_path(it), w);
    }
}
