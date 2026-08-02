#import "String";
    
should_ignore_file :: (name: string) -> bool {
    if name.count > 0 && name[0] == #char "." return true;

    // Aseprite sources are inputs (see resource_mirror.jai), not shippable
    // assets; only the .sheet.png/.sheet.json they export go into the pack.
    if is_aseprite_source(name) return true;

    return false;
}

should_ignore_path :: (full_name: string) -> bool {
    if contains(full_name, "/worlds/") return true;
    return false;
}

    
util :: #import "File_Utilities";
#import "Hash_Table";
    
packs : Table(string, Create_Package);
    
file_visit_handler :: (info: *util.File_Visit_Info, user_data: bool) {
    if should_ignore_file(info.short_name) then return;
    if should_ignore_path(info.full_name) then return;

    _, _, packPath := split_from_left(info.full_name, "/resources/");
    _, packName, fileName := split_from_left(packPath, "/");

    if !table_contains(*packs, packName) {
        package : Create_Package;
        init(*package);
        table_set(*packs, packName, package);
    }

    packPtr := table_find_pointer(*packs, packName);
        
    file, ok := read_entire_file(info.full_name);
    if !ok {
        print("Failed in loading file to pack: %\n", fileName);
        return;
    }
    filedata : []u8;
    filedata.count = file.count;
    filedata.data = file.data;
    add(packPtr, fileName, filedata);   
}

create_pack :: (include_test_resources: bool = false, pack_dir: string = "./packs") {
    #import "Simple_Package";
    #import "File";

    // Packs come from the processed copy of the resource trees, never the trees
    // themselves. See resource_mirror.jai.
    for prepare_resource_mirror(include_test_resources) {
        util.visit_files(it, true, true, file_visit_handler);
    }

    make_directory_if_it_does_not_exist(pack_dir);
    for pack, key : packs {
        write(*pack, tprint("%/%.pack", pack_dir, key));
    }
}
