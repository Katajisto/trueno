AT_COMPILE_TIME :: true;

PS5_SUPPORT      :: false;
NINTENDO_SUPPORT :: #run to_string(getenv("NINTENDO_SDK_ROOT")) != "";

SOURCE_PATH :: "source";
LIB_BASE_NAME :: "stb_vorbis";
LIB_DECLARATION_NAME :: "lib_stb_vorbis";


DECLARATIONS_TO_OMIT :: string.[
    "STB_VORBIS_HEADER_ONLY", // No reason to export this.
];


#if AT_COMPILE_TIME {
    #run,stallable {
        set_build_options_dc(.{do_output=false});
        options := get_build_options();
        args := options.compile_time_command_line;
        if !generate_bindings(args, options.minimum_os_version) {
            compiler_set_workspace_status(.FAILED);
        }
    }
} else {
    #import "System";

    main :: () {
        set_working_directory(path_strip_filename(get_path_of_running_executable()));
        if !generate_bindings(get_command_line_arguments(), #run get_build_options().minimum_os_version) {
            exit(1);
        }
    }
}

generate_bindings :: (args: [] string, minimum_os_version: type_of(Build_Options.minimum_os_version)) -> bool {
    using BG;
    target_android := array_find(args, "-android");
    target_switch2   := array_find(args, "-switch2");
    target_ps5     := array_find(args, "-ps5");
    target_x64     := array_find(args, "-x64");
    target_arm     := array_find(args, "-arm64");
    compile        := array_find(args, "-compile");
    compile_debug  := array_find(args, "-debug");

    os_target  := OS;
    cpu_target := CPU;
    if target_android os_target  = .ANDROID;
    if target_switch2   os_target  = .NN_SWITCH2;
    if target_ps5     os_target  = .PS5;

    if target_x64     cpu_target = .X64;
    if target_arm     cpu_target = .ARM64;

    build_dynamic_lib := true;
    lib_directory: string;
    if os_target == {
        case .WINDOWS;
            lib_directory = "windows";
        case .LINUX;
            lib_directory = "linux";
        case .MACOS;
            lib_directory = "macos";
        case .ANDROID;
            lib_directory = ifx cpu_target == .X64 then "android/x64" else "android/arm64";
        case .PS5;
            build_dynamic_lib = false;
            lib_directory = "ps5";
        case .NN_SWITCH2;
            build_dynamic_lib = false;
            lib_directory = "switch2";
        case;
            assert(false);
    }

    if compile {
        source_file := tprint("%/stb_vorbis_custom.c", SOURCE_PATH);

        make_directory_if_it_does_not_exist(lib_directory, recursive = true);
        lib_path := tprint("%/%", lib_directory, LIB_BASE_NAME);
        success := true;
        if os_target == .MACOS {
            success &&= Build_Cpp.build_universal_macos_binary(lib_path, source_file, type = .DYNAMIC_LIBRARY, debug = compile_debug);
            success &&= Build_Cpp.build_universal_macos_binary(lib_path, source_file, type = .STATIC_LIBRARY,  debug = compile_debug);
        } else {
            extra: [..] string;
            if os_target == .ANDROID {
                _, target_triple_with_sdk := get_android_target_triple(cpu_target);
                array_add(*extra, "-target", target_triple_with_sdk);
            }
            if os_target != .WINDOWS {
                array_add(*extra, "-fPIC");
            }

            if build_dynamic_lib {
                success &&= Build_Cpp.build_cpp_dynamic_lib(lib_path, source_file, target = os_target, debug = compile_debug, extra = extra);
            }
            success &&= Build_Cpp.build_cpp_static_lib(lib_path, source_file, target = os_target, debug = compile_debug, extra = extra);
        }

        if !success     return false;
    }

    options: Generate_Bindings_Options;
    options.os = os_target;
    options.cpu = cpu_target;
    {
        using options;

        array_add(*extra_clang_arguments, "-DSTB_VORBIS_HEADER_ONLY");

        array_add(*library_search_paths, lib_directory);
        array_add(*libraries, .{filename=LIB_BASE_NAME, identifier=LIB_DECLARATION_NAME});
        array_add(*source_files, tprint("%/stb_vorbis.c", SOURCE_PATH));

        generate_library_declarations = false;
        footer = tprint(FOOTER_TEMPLATE, LIB_BASE_NAME, LIB_DECLARATION_NAME);

        auto_detect_enum_prefixes = true;
        log_stripped_declarations = false;
        generate_compile_time_struct_checks = false;

        visitor = stb_visitor;
    }

    output_filename := "bindings.jai";
    return generate_bindings(options, output_filename);
}

FOOTER_TEMPLATE :: #string END

#if OS == .WINDOWS {
    %2 :: #library "windows/%1";
} else #if OS == .LINUX {
    %2 :: #library "linux/%1";
} else #if OS == .MACOS {
    %2 :: #library "macos/%1";
} else #if OS == .ANDROID {
    #if CPU == .X64 {
        %2 :: #library "android/x64/%1";
    } else #if CPU == .ARM64 {
        %2 :: #library "android/arm64/%1";
    }
} else #if OS == .PS5 {
    %2 :: #library "ps5/%1";
} else #if OS == .NN_SWITCH2 {
    #if CPU == .X64 {
        %2 :: #library "windows/%1";
    } else #if CPU == .ARM64 {
        %2 :: #library "switch2/%1";
    }
} else #if OS == .WASM {
    %2 :: #library,no_dll "wasm/%1";
} else {
    #assert false;
}

END

stb_visitor :: (decl: *BG.Declaration, parent_decl: *BG.Declaration) -> BG.Declaration_Visit_Result {
    if !parent_decl {
        if array_find(DECLARATIONS_TO_OMIT, decl.name) {
            decl.decl_flags |= .OMIT_FROM_OUTPUT;
            return .STOP;
        }
    }

    return .RECURSE;
}

#import "Basic";
BG :: #import "Bindings_Generator"(NINTENDO_SUPPORT = NINTENDO_SUPPORT);
Build_Cpp :: #import "BuildCpp"()(PS5_SUPPORT = PS5_SUPPORT, NINTENDO_SUPPORT = NINTENDO_SUPPORT);
#import "Compiler";
#import "File";
#import "Android/Toolchain";
#if OS == .WINDOWS {
    #import "Windows";
} else {
    #import "POSIX";
}

