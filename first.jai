#load "./src/meta/meta.jai";

Iprof :: #import "Iprof"(IMPORT_MODE = .METAPROGRAM);
#import "File_Utilities";

Trueno_Build_Options :: struct {
    wasm_build     : bool;
    release_build  : bool;
    tacoma_enabled : bool;   
    iprof_enabled  : bool;    
}

build_options_from_args :: (args: []string) -> Trueno_Build_Options {
    opts : Trueno_Build_Options;

    for arg : args {
        if arg == {
            case "wasm";
                opts.wasm_build = true;
            case "tacoma";
                opts.tacoma_enabled = true;
            case "release";
                opts.release_build = true;
            case "iprof";
                opts.iprof_enabled = true;
        }
    }

    return opts;
}

add_trueno_opts_to_compiler_strings :: (trueno_opts : Trueno_Build_Options, w: Workspace) {
    #import "String";
    bool_to_string :: (b: bool) -> string {
        if b then return tprint("true"); else return tprint("false");
    }

    trueno_opts_info := type_info(Trueno_Build_Options);
    for trueno_opts_info.members {
        optPtr := (cast(*bool)(*trueno_opts)) + it.offset_in_bytes;
        name := tprint("%", it.name);
        to_upper_in_place(name);
        add_build_string(tprint("FLAG_% :: %;\n", name, bool_to_string(optPtr.*)), w);
    }
}

compile_shaders :: () {
    process_result, output, error := run_command("bash", ifx OS == .MACOS then "./compile_shaders_mac.sh" else "./compile_shaders.sh", working_directory=tprint("%/src/shaders", #filepath));
    if process_result.exit_code != 0 {
        log_error("Shader compilation failed.");
        if output {
            log_error(output,, logger = runtime_support_default_logger);
        }
        exit(1);
    }
}

wasm_copy_assets :: () {
    if is_directory("./packs") {
        run_command("cp", "-r", "./packs", "./dist/", working_directory=tprint("%", #filepath));
    }

    worlds_src := "./game/resources/worlds";
    if is_directory(worlds_src) {
        make_directory_if_it_does_not_exist("./dist/game/resources", recursive = true);
        run_command("cp", "-r", worlds_src, "./dist/game/resources/", working_directory=tprint("%", #filepath));
    }
}

metaprogramming_loop :: (trueno_opts: Trueno_Build_Options, w: *Workspace) {
   while true {
        message := compiler_wait_for_message();
        // @ToDo: add iprof to this refactored metaprogram
        // if trueno_opts.iprof_enabled then iprof_plugin.message(iprof_plugin, message)
        custom_message_handler(message, w);
        if message.kind == .COMPLETE then break;
    }
    compiler_end_intercept(w.*);
}

native_build :: (opts: Build_Options, trueno_opts: Trueno_Build_Options) {
    set_build_options_dc(.{do_output=false});

    current_w := get_current_workspace();
    root_opts := get_build_options();
    w := compiler_create_workspace("Target");
    opts := get_build_options(w);
    copy_commonly_propagated_fields(opts, *root_opts);
        
    opts.cpu_target = root_opts.cpu_target;
    opts.os_target  = root_opts.os_target;
    opts.backend    = ifx (trueno_opts.release_build || OS == .MACOS) then .LLVM else .X64;
    opts.output_executable_name = root_opts.output_executable_name;

    set_build_options(opts, w);
    iprof_plugin: *Iprof.My_Plugin;

    // profile := iprof;

    // if profile {
    //     iprof_plugin = cast(*Iprof.My_Plugin) Iprof.get_plugin();
    //     iprof_plugin.workspace = w;

    //     // Set options        
    //     iprof_plugin.instrument_modules = true;

    //     iprof_plugin.before_intercept(iprof_plugin, null);
    // }

    compiler_begin_intercept(w);

    add_build_file("src/platform_specific/main_native.jai", w);
    add_shaders_to_workspace(w);

    metaprogramming_loop(trueno_opts, *w);

    if trueno_opts.iprof_enabled {
        iprof_plugin.finish(iprof_plugin);
        iprof_plugin.shutdown(iprof_plugin);
    }
}

wasm_build :: (opts: Build_Options, trueno_opts: Trueno_Build_Options) {
    set_build_options_dc(.{do_output = false});
    make_directory_if_it_does_not_exist("dist", recursive = true);
    
    wasm_copy_assets();
    w := compiler_create_workspace("Wasm");

    options := get_build_options(w);
    copy_commonly_propagated_fields(get_build_options(), *options);

    options.output_type                         = .OBJECT_FILE;
    options.backend                             = .LLVM;
    options.os_target                           = .WASM;
    options.cpu_target                          = .CUSTOM;
    options.emit_debug_info                     = .DWARF;
    options.backtrace_on_crash                  = .OFF;
    options.output_path                         = "dist/";
    options.output_executable_name              = "main";
    options.llvm_options.target_system_features = "+bulk-memory";
    options.llvm_options.enable_split_modules   = false;
    options.llvm_options.function_sections      = true;

    import_paths: [..]string;

    for options.import_path array_add(*import_paths, it);
    options.import_path = import_paths;

    // This was compiled from https://github.com/wingo/walloc via "clang -Oz --target=wasm64 -nostdlib -c -o walloc.o walloc.c".
    // We should probably port this allocator to Jai instead…
    //  -rluba, 2023-11-15
    walloc_object_file_path := "walloc.o";
    STACK_SIZE :: 1024 * 1024 * 1024;
    options.additional_linker_arguments = .["--stack-first", "-z", tprint("stack-size=%", STACK_SIZE), walloc_object_file_path];

    set_build_options(options, w);
    remap_import(w, "*", "Default_Allocator", "Walloc");

    compiler_begin_intercept(w);

    add_trueno_opts_to_compiler_strings(trueno_opts, w);
    add_build_file("src/platform_specific/main_web.jai", w);      
    add_shaders_to_workspace(w);

    metaprogramming_loop(trueno_opts, *w);

    args := string.[
        "emcc",
        "src/platform_specific/main.c", "dist/main.o", "modules/sokol-jai/sokol/gfx/sokol_gfx_wasm_gl_release.a", "modules/sokol-jai/sokol/log/sokol_log_wasm_gl_release.a", "modules/sokol-jai/sokol/audio/sokol_audio_wasm_gl_release.a", "modules/sokol-jai/sokol/time/sokol_time_wasm_gl_release.a", "modules/sokol-jai/sokol/app/sokol_app_wasm_gl_release.a", "modules/sokol-jai/sokol/glue/sokol_glue_wasm_gl_release.a", "modules/sokol-jai/sokol/fetch/sokol_fetch_wasm_gl_release.a", "modules/sokol-jai/sokol/gl/sokol_gl_wasm_gl_release.a", "modules/sokol-jai/sokol/fontstash/sokol_fontstash_wasm_gl_release.a",
        "modules/sokol-jai/sokol/stbi/stb_image.a",
        "-o", "dist/index.html",
        "-sSTACK_SIZE=10MB",
        "-sALLOW_MEMORY_GROWTH",
        "-sERROR_ON_UNDEFINED_SYMBOLS=1", "-sMEMORY64", "-sMAX_WEBGL_VERSION=2",
        "--js-library=src/platform_specific/runtime.js",
        "--shell-file=src/platform_specific/shell.html",
    ];
        
    process_result, output, error := run_command(..args, capture_and_return_output = true);
    if process_result.exit_code != 0 {
        log_error("EMCC compilation failed.");
        if error {
            log_error(error,, logger = runtime_support_default_logger);
        }
        exit(1);
    }
}

#run {
    opt := get_build_options();
    trueno_opts := build_options_from_args(opt.compile_time_command_line);  
    compile_shaders();
    create_pack();

    if trueno_opts.wasm_build {
        wasm_build(opt, trueno_opts);
    } else {
        native_build(opt, trueno_opts);
    }
}

#import "Basic";
#import "Compiler";
#import "Process";
#import "File";

