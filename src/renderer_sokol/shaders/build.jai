compile_sokol_shaders :: () -> bool {
    dir :: "src/renderer_sokol/shaders";
    shdc :: #ifx OS == .MACOS then "sokol-shdc-mac" else "sokol-shdc";

    for file_list(dir) {
        if !ends_with(it, ".glsl")  continue;
        name := path_strip_extension(path_filename(it));
        out  := tprint("%/jai/%.jai", dir, name);

        src_time := file_modtime_and_size(it);
        out_time, _, out_exists := file_modtime_and_size(out);
        if out_exists && compare_apollo_times(out_time, src_time) >= 0  continue;

        result, output, error := run_command(tprint("%/%", dir, shdc), "-i", it, "-o", out,
            "-l", "glsl430:glsl300es:metal_macos", "-f", "sokol_jai", capture_and_return_output = true);
        if result.exit_code != 0 {
            log_error("sokol-shdc failed on %:\n%%", it, output, error);
            return false;
        }
    }
    return true;
}
