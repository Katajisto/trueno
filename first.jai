#load "./src/meta/meta.jai";
Iprof :: #import "Iprof"(IMPORT_MODE = .METAPROGRAM);

#run {
    print("%\n", ascii_car);
    // @ToDo: Fix this so that we are using the freshly compiled Jai files instead of the old ones.
    // {
    //     process_result, output, error := run_command("bash", "./compile_shaders.sh", working_directory=tprint("%/src/shaders", #filepath));
    //     if process_result.exit_code != 0 {
    //         log_error("Shader compilation failed.");
    //         if output {
    //             log_error(output,, logger = runtime_support_default_logger);
    //         }
    //         exit(1);
    //     }
    // }
    opt := get_build_options();
    args := opt.compile_time_command_line;
    doWasmBuild := false;
    hasTacoma := false;
    for arg : args {
        if arg == "wasm" then doWasmBuild = true;
        if arg == "tacoma" then hasTacoma = true;
    }

    if doWasmBuild {
    set_build_options_dc(.{do_output = false});

    make_directory_if_it_does_not_exist("dist", recursive = true);


    {

        process_result, output, error := run_command("cp", "-r", "./resources", "./dist/", working_directory=tprint("%", #filepath));
        
    
        w := compiler_create_workspace("Wasm");

        options := get_build_options(w);
        copy_commonly_propagated_fields(get_build_options(), *options);

        options.output_type                         = .OBJECT_FILE;
        options.backend                             = .LLVM; // WASM only works with the LLVM backend, obviously.
        options.os_target                           = .WASM;
        options.cpu_target                          = .CUSTOM;
        options.emit_debug_info                     = .DWARF;
        options.backtrace_on_crash                  = .OFF; // Runtime_Support_Crash_Handler doesn’t support WASM (yet?)
        options.output_path                         = "dist/";
        options.output_executable_name              = "main";
        options.llvm_options.target_system_features = "+bulk-memory"; // "This options is needed so that "memcpy" and "memset" are mapped to "memory.copy" and "memory.fill" instructions in WASM.
        options.llvm_options.enable_split_modules   = false;
        options.llvm_options.function_sections      = true; // To get around "LLVM ERROR: section already has a defining function: .text"

        import_paths: [..]string;
        // Add our own modules folder first so that we can override modules with our own version, if necessary.
        for options.import_path array_add(*import_paths, it);
        options.import_path = import_paths;

        // This was compiled from https://github.com/wingo/walloc via "clang -Oz --target=wasm64 -nostdlib -c -o walloc.o walloc.c".
        // We should probably port this allocator to Jai instead…
        //  -rluba, 2023-11-15
        walloc_object_file_path := "walloc.o";

        STACK_SIZE :: 1024 * 1024 * 1024;
        options.additional_linker_arguments = .["--stack-first", "-z", tprint("stack-size=%", STACK_SIZE), walloc_object_file_path];

        set_build_options(options, w);

        // Replace the default allocator with Walloc (https://github.com/wingo/walloc).
        remap_import(w, "*", "Default_Allocator", "Walloc");

        compiler_begin_intercept(w);

        add_build_file("src/platform_specific/main_web.jai", w);
        add_build_string("HAS_TACOMA :: false;", w);
        add_build_string("HAS_IPROF :: false;", w);

        while true {
            message := compiler_wait_for_message();
            if message.kind == {
                case .TYPECHECKED;
                    typechecked := cast(*Message_Typechecked) message;
                    for body: typechecked.procedure_bodies {
                        header := body.expression.header;
                        // You could replace individual procedure bodies here, if you needed to.
                    }

                case .COMPLETE;
                    break;
            }
        }

        compiler_end_intercept(w);
    }

    {
        args := string.[
            "emcc",
            "src/platform_specific/main.c", "dist/main.o", "modules/sokol-jai/sokol/gfx/sokol_gfx_wasm_gl_debug.a", "modules/sokol-jai/sokol/log/sokol_log_wasm_gl_debug.a", "modules/sokol-jai/sokol/time/sokol_time_wasm_gl_debug.a", "modules/sokol-jai/sokol/app/sokol_app_wasm_gl_debug.a", "modules/sokol-jai/sokol/glue/sokol_glue_wasm_gl_debug.a", "modules/sokol-jai/sokol/fetch/sokol_fetch_wasm_gl_debug.a", "modules/sokol-jai/sokol/gl/sokol_gl_wasm_gl_debug.a", "modules/sokol-jai/sokol/fontstash/sokol_fontstash_wasm_gl_debug.a",
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
    } else {
        set_build_options_dc(.{do_output=false});

        current_w := get_current_workspace();
        root_opts := get_build_options();
        w := compiler_create_workspace("Target");
        opts := get_build_options(w);
        copy_commonly_propagated_fields(*opts, *root_opts);
        opts.cpu_target = root_opts.cpu_target;
        opts.os_target  = root_opts.os_target;
        opts.output_executable_name = root_opts.output_executable_name;
        set_build_options(opts, w);
        iprof_plugin: *Iprof.My_Plugin;

        profile :: true;

        if profile {
            iprof_plugin = cast(*Iprof.My_Plugin) Iprof.get_plugin();
            iprof_plugin.workspace = w;
    
            // Set options        
            iprof_plugin.instrument_modules = true;

            iprof_plugin.before_intercept(iprof_plugin, null);
        }

        compiler_begin_intercept(w);
        if hasTacoma {
            add_build_string("HAS_TACOMA :: true;", w);
        } else {
            add_build_string("HAS_TACOMA :: false;", w);
        }
        iprof_plugin.add_source(iprof_plugin);
        add_build_file("src/platform_specific/main_native.jai", w);

       lint_ok := true;
       while true {
            message := compiler_wait_for_message();
            iprof_plugin.message(iprof_plugin, message);
            if !lint_checks(message) then lint_ok = false;
            
            if message.kind == .COMPLETE then break;
        }
        compiler_end_intercept(w);
        iprof_plugin.finish(iprof_plugin);
        iprof_plugin.shutdown(iprof_plugin);
        
    }
}

#import "Basic";
#import "Compiler";
#import "Process";
#import "File";

