#import "Simple_Package";
#import "Basic";
#import "File";
#import "Hash_Table";

write_package :: (filename: string) {
    item1 := "Hello, Sailor!";

    item2: [100] u8;
    for 0..item2.count-1  item2[it] = xx it;
    
    item3: [10] float;
    for 0..item3.count-1  item3[it] = cast(float)(it*it);


    package: Create_Package;
    defer deinit(*package);

    init(*package);

    add(*package, "run_tree/data/item1", xx item1);

    add(*package, "this is item2", xx item2);

    item3_data: [] u8;
    item3_data.data  = xx item3.data;
    item3_data.count = item3.count * size_of(type_of(item3[0]));
    add(*package, "item3, unimaginatively", item3_data);

    write(*package, filename);
}

read_package :: (filename: string) -> (success: bool, package: Load_Package) {
    package: Load_Package;

    success := init_from_file(*package, filename);
    if !success return false, package;

    print("package has % entries:\n", package.entries.count);

    for package.entries {
        print("[%] %\n", it_index, it);
    }

    return true, package;
}

main :: () {
    filename :: "test.package";

    write_package(filename);
    success, package := read_package(filename);

    print("\n");
    print("read_package returned success == %.\n", success);
    print("\n");
    
    if success {
        found, entry := table_find(*package.lookup, "this is item2");

        if found {
            print("Found the entry!: %\n", entry.*);
        } else {
            print("Did not find the entry! Oops!\n");
            assert(false);
        }
    } else {
        assert(false);
    }

    print("\n");
}

