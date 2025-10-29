should_ignore_file :: (name: string) -> bool {
    #import "String";
    
    
    ok, left, right :=  split_from_right(name, #char ".");
    if right == "aseprite" {
        print("Ignoring % as aseprite file...\n", name);
        return true;
    }
    
    return false;
}

create_pack :: () {
    #import "Simple_Package";
    #import "File";
    util :: #import "File_Utilities";

    files_to_pack := util.file_list("./resources", true);
    
    files_to_pack_game := util.file_list("./game/resources", true);

    package: Create_Package;
    defer deinit(*package);
    init(*package);
    

    for files_to_pack {
        if should_ignore_file(it) then continue;
        file, ok := read_entire_file(it);
        if !ok {
            print("Failed in loading file to pack: %\n", it);
            continue;
        }
        filedata : []u8;
        filedata.count = file.count;
        filedata.data = file.data;
        add(*package, it, filedata);   
    }
    
    for files_to_pack_game {
        if should_ignore_file(it) then continue;
        file, ok := read_entire_file(it);
        if !ok {
            print("Failed in loading file to pack: %\n", it);
            continue;
        }
        filedata : []u8;
        filedata.count = file.count;
        filedata.data = file.data;
        add(*package, it, filedata);   
    }

    print("Packing % engine files -> ./packs/assets.pack\n", files_to_pack.count);
    print("Packing % game files -> ./packs/assets.pack\n", files_to_pack_game.count);
    
    write(*package, "./packs/assets.pack");
}
