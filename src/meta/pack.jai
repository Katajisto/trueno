create_pack :: () {
    #import "Simple_Package";
    #import "File";
    util :: #import "File_Utilities";

    files_to_pack := util.file_list("./resources", true);

    package: Create_Package;
    defer deinit(*package);
    init(*package);
    
    print("Packing % files -> ./packs/assets.pack\n", files_to_pack.count);

    for files_to_pack {
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

    write(*package, "./packs/assets.pack");
}
