#scope_file

MAX_FILE_SIZE :: 200_000;
buf : [MAX_FILE_SIZE]u8;

g_asset_pack : Load_Package;

mandatory_loads_left      : s32  = 0;

packcb :: (res: *sfetch_response_t) #c_call {
    push_context,defer_pop default_context;
    mem : []u8;
    mem.count = res.data.size.(s64);
    mem.data = res.data.ptr;

    success := init_from_memory(*g_asset_pack, mem, "main_asset_pack");
    print("Succesfully loaded main asset pack!\n");
    mandatory_loads_left -= 1;
}

#scope_export

init_after_mandatory_done : bool = false;

mandatory_loads_done :: () -> bool {
    return mandatory_loads_left <= 0;
}

init_asset_pack_load :: () {
    mandatory_loads_left += 1;
    sfetch_send(*(sfetch_request_t.{
        path = "./packs/assets.pack".data,
        callback = packcb,
        buffer = .{
            ptr = buf.data,
            size = buf.count
        }
    }));
}

add_font_from_pack :: (path: string) {
    ok, entry := table_find_new(*g_asset_pack.lookup, path);
    if !ok {
        print("Failed to find font % from pack...\n", path);
        return;
    }
    state.font_default.fons_font = fonsAddFontMem(state.fons, "sans", entry.data.data, xx entry.data.count, 0);
}

create_texture_from_pack :: (path: string) -> sg_image {
    ok, entry := table_find_new(*g_asset_pack.lookup, path);
    if !ok {
        print("Failed to find texture % from pack...\n", path);
        img : sg_image;
        return img;
    }
    
    x : s32;
    y : s32;
    channels : s32;
    data := stbi.stbi_load_from_memory(entry.data.data, xx entry.data.count, *x, *y, *channels, 4);
    img := sg_alloc_image();

    subimg : [6][16]sg_range;
    subimg[0][0] = .{
        ptr = data,
        size = xx (x * y * 4)
    };

    sg_init_image(*img, *(sg_image_desc.{
        width = x,
        height = y,
        pixel_format = sg_pixel_format.RGBA8,
        data = .{
            subimage = subimg
        }
    }));

    stbi.stbi_image_free(data);

    return img;
}

asset_list :: () -> string #expand {
    count := 0;
    for v : g_asset_pack.lookup {
        console_add_output_line(sprint("% (%)", v.name, format_size(v.size_of_entry)));
        count += 1;
    }
    return tprint("> A total of % assets.", count);
} @Command

// Returns tprinted pointer, please copy it somewhere.
format_size :: (bytes: int) -> string {
    bytes_counter := bytes;
    bytes_float := cast(float) bytes;
    names : []string = .["b", "kb", "mb", "gb", "tb"];
    name_index := 0;
    while bytes_counter / 1000 > 0 {
        name_index += 1;
        bytes_counter /= 1000;
        bytes_float /= 1000.0;
        if name_index > 4 then break;
    }
    return tprint("% %", bytes_float, names[name_index]);
    
}
