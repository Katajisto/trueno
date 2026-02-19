#import "String";
    
should_ignore_file :: (name: string) -> bool {

    ok, left, right :=  split_from_right(name, #char ".");
    if right == "aseprite" {
        print("Ignoring % as aseprite file...\n", name);
        return true;
    }

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

create_pack :: () {
    #import "Simple_Package";
    #import "File";

    util.visit_files("./resources", true, true, file_visit_handler);
    util.visit_files("./game/resources", true, true, file_visit_handler);

    for pack, key : packs {
        write(*pack, tprint("./packs/%.pack", key));
    }
}
