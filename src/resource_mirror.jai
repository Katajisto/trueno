// Packs are built from a throwaway copy of the resource trees, not from the
// trees themselves:
//
//     wipe .build/generated -> copy the trees in -> process the copy -> pack it
//
// Processing (currently just the Aseprite export) writes its output into the
// copy, so the real resource trees only ever hold sources. Rebuilding the copy
// from scratch every time is what keeps this simple: there is no stale output to
// detect and nothing to prune, because a deleted source is simply not there.
//
// Used by both the build (meta/pack.jai) and the runtime hot-reloader
// (pack_hotreload.jai), so they process resources identically.

#import "Basic";
#import "String";
#import "Process";
#import "File";
#import "File_Utilities";

// Not ".build/generated/resources": pack.jai derives the pack name by splitting
// on the *first* "/resources/", so a "resources" segment here would shadow the
// real one and yield pack "game" instead of "game_core".
MIRROR_ROOT :: ".build/generated";

ASEPRITE_SOURCE_EXTENSIONS :: string.["aseprite", "ase"];

is_aseprite_source :: (short_name: string) -> bool {
    ok, base, extension := split_from_right(short_name, #char ".");
    if !ok return false;
    for ASEPRITE_SOURCE_EXTENSIONS  if extension == it  return true;
    return false;
}

// Wipes and rebuilds the mirror, runs the processing steps over it, and returns
// the mirrored resource roots to pack in place of the real ones.
prepare_resource_mirror :: (use_test_game: bool) -> [] string {
    run_command("rm", "-rf", MIRROR_ROOT);

    game_tree := ifx use_test_game then "test_game" else "game";

    roots: [..] string;
    roots.allocator = temp;
    array_add(*roots, copy_tree_into("./resources", MIRROR_ROOT));
    array_add(*roots, copy_tree_into(tprint("./%/resources", game_tree), tprint("%/%", MIRROR_ROOT, game_tree)));

    export_aseprite_sheets(roots);

    return roots;
}

// "cp -r ./game/resources .build/generated/game" -> ".build/generated/game/resources"
copy_tree_into :: (source: string, destination_parent: string) -> string {
    make_directory_if_it_does_not_exist(destination_parent, recursive = true);
    run_command("cp", "-r", source, destination_parent);

    ok, parent, name := split_from_right(source, #char "/");
    return tprint("%/%", destination_parent, name);
}

// Aseprite's CLI, reproducing byte for byte what its "Export Sprite Sheet"
// dialog was producing for the sheets that used to be checked in.
// --format json-array and --list-tags are load-bearing: asset_manager.jai parses
// `frames` as an array and drives Animation off `meta.frameTags`.
ASEPRITE_EXPORT_FLAGS :: string.[
    "--format",     "json-array",
    "--list-tags",
    "--list-layers",
    "--list-slices",
];

// "player.aseprite"     -> player.sheet.png / player.sheet.json
// "anim.sheet.aseprite" -> anim.sheet.png   / anim.sheet.json
//
// The doubled-up ".sheet" is dropped because asset_manager.jai keys sheets on
// everything before the *first* dot, so "anim.sheet.sheet.png" would load as a
// sheet named "anim" with extension "sheet.sheet.png" and be rejected.
sheet_output_paths :: (source: string) -> (png: string, json: string) {
    ok, stem := split_from_right(source, #char ".");
    if ends_with(stem, ".sheet") {
        stem.count -= ".sheet".count;
    }
    return tprint("%.sheet.png", stem), tprint("%.sheet.json", stem);
}

find_aseprite_binary :: () -> (path: string, found: bool) {
    candidates: [..] string;
    candidates.allocator = temp;

    #if OS == .LINUX || OS == .MACOS {
        POSIX :: #import "POSIX";
        read_env :: (name: string) -> string {
            value := POSIX.getenv(name.data);
            if !value return "";
            return to_string(value);
        }

        // ASEPRITE points the build at a different install without editing this.
        override := read_env("ASEPRITE");
        if override  array_add(*candidates, override);

        home := read_env("HOME");
        if home  array_add(*candidates, tprint("%/bin/aseprite", home));
    }

    #if OS == .MACOS {
        array_add(*candidates, "/Applications/Aseprite.app/Contents/MacOS/aseprite");
    }

    array_add(*candidates, "aseprite");  // whatever is on PATH

    for candidates {
        // Probing by running it also catches a path that exists but isn't executable.
        result := run_command(it, "--version", capture_and_return_output = true);
        if result.type == .EXITED && result.exit_code == 0  return it, true;
    }
    return "", false;
}

collect_aseprite_sources :: (root: string, sources: *[..] string) {
    if !is_directory(root) return;

    visit_files(root, true, sources, (info: *File_Visit_Info, sources: *[..] string) {
        if info.is_directory return;
        if !is_aseprite_source(info.short_name) return;
        array_add(sources, copy_string(info.full_name));
    });
}

// Exports every Aseprite file in the mirror to a sheet pair beside it. pack.jai
// skips the sources themselves, so only the exports end up in the pack.
export_aseprite_sheets :: (roots: [] string) {
    sources: [..] string;
    sources.allocator = temp;
    for roots  collect_aseprite_sources(it, *sources);
    if !sources return;

    aseprite, found := find_aseprite_binary();
    if !found {
        log_error("Aseprite export: % source file(s) to export but no aseprite binary was found.", sources.count);
        log_error("Looked for $ASEPRITE, $HOME/bin/aseprite, and 'aseprite' on PATH.");
        exit(1);
    }

    for source: sources {
        png, json := sheet_output_paths(source);

        args: [..] string;
        args.allocator = temp;
        array_add(*args, aseprite, "-b", source, "--sheet", png, "--data", json);
        for flag: ASEPRITE_EXPORT_FLAGS  array_add(*args, flag);

        result, output, error := run_command(..args, capture_and_return_output = true);
        if result.type != .EXITED || result.exit_code != 0 {
            log_error("Aseprite export failed for %", source);
            if output  log_error(output,, logger = runtime_support_default_logger);
            if error   log_error(error,,  logger = runtime_support_default_logger);
            exit(1);
        }
    }

    print("Aseprite: exported % sheet(s)\n", sources.count);
}
