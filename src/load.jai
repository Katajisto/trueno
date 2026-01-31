g_asset_pack : Load_Package;

#scope_export

init_after_mandatory_done : bool = false;

add_font_from_pack :: (path: string) {
    ok, entry := table_find(*g_asset_pack.lookup, path);
    if !ok {
        print("Failed to find font % from pack...\n", path);
        return;
    }
    state.font_default.fons_font = fonsAddFontMem(state.fons, "sans", entry.data.data, xx entry.data.count, 0);
}

create_texture_from_pack :: (path: string) -> (sg_image, s32, s32) {
    ok, entry := table_find(*g_asset_pack.lookup, path);
    if !ok {
        print("Failed to find texture % from pack...\n", path);
        img : sg_image;
        return img, 0, 0;
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

    sg_init_image(img, *(sg_image_desc.{
        width = x,
        height = y,
        pixel_format = sg_pixel_format.RGBA8,
        data = .{
            subimage = subimg
        }
    }));

    stbi.stbi_image_free(data);

    return img, x, y;
}

load_string_from_pack :: (path: string) -> string {
    ok, entry := table_find(*g_asset_pack.lookup, path);
    if !ok {
        print("Failed to load string from pack: %\n", path);
        return "";
    }

    s: string;
    s.data = entry.data.data;
    s.count = entry.data.count;
    return s;
}

asset_list :: () -> string #expand {
    count := 0;
    for v : g_asset_pack.lookup {
        console_add_output_line(sprint("% (%)", v.name, format_size(v.size_of_entry)));
        count += 1;
    }
    return tprint("> A total of % assets.", count);
} @Command

// Returns tprinted string, please copy it somewhere.
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
