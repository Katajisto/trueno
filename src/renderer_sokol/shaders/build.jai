compile_sokol_shaders :: () -> bool {
    dir    :: "src/renderer_sokol/shaders";
    input  :: "src/renderer_sokol/shaders/shaders.glsl";
    output :: "src/renderer_sokol/shaders/jai/shaders.jai";
    shdc   :: #ifx OS == .MACOS then "src/renderer_sokol/shaders/sokol-shdc-mac" else "src/renderer_sokol/shaders/sokol-shdc";

    out_time, _, out_exists := file_modtime_and_size(output);
    stale := !out_exists;
    for file_list(dir) {
        if !ends_with(it, ".glsl")  continue;
        src_time := file_modtime_and_size(it);
        if compare_apollo_times(src_time, out_time) > 0  stale = true;
    }
    if !stale  return true;

    result, out, error := run_command(shdc, "-i", input, "-o", output,
        "-l", "glsl430:glsl300es:metal_macos", "-f", "sokol_jai", capture_and_return_output = true);
    if result.exit_code != 0 {
        log_error("sokol-shdc failed:\n%%", out, error);
        return false;
    }
    return true;
}
