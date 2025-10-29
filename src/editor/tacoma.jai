#run {
    #load "../meta/ascii.jai";
    print("%\n", ascii_tacoma);
}

Tacoma :: #import "Tacoma";

Tacoma_Screenshot :: struct {
    image  : sg_image;
    width  : s32;
    height : s32;
    valid  : bool = false;
}

current_screenshot : Tacoma_Screenshot;

gen_reference :: (w: s32, h: s32, conf: Tacoma.Gen_Config, world: World) {
    // Trile BLASes.
    trile_list : [..]Tacoma.Trile_Data;
    trile_list.allocator = temp;
    // BLAS instances to create TLAS.
    world_triles : [..]Tacoma.World_Trile;
    world_triles.allocator = temp;

    for world.positions {
        print("World positions for: %\n", it.trileName);
        trile := get_trile(it.trileName);
        ttrile : Tacoma.Trile_Data;
        for x: 0..15 {
            for y: 0..15 {
                for z: 0..15 {
                    ttrile.trixels[x][y][z] = .{
                        trile.trixels[x][y][z].empty,
                        trile.trixels[x][y][z].material.color,
                        material_encode_to_float(trile.trixels[x][y][z].material)
                    };
                }
            }
        }
        gfx := get_trile_gfx(it.trileName);
        ttrile.vertices = gfx.vertices.data;
        ttrile.vertexCount = cast(s32) (gfx.vertices.count / 3);
        array_add(*trile_list, ttrile);

        for pos, posi: it.positions {
            array_add(*world_triles, Tacoma.World_Trile.{cast(s32)it_index, pos.xyz});
        }
    }


    sky : Tacoma.Sky_Config;

    sky.skyBase = world.conf.skyBase;
    sky.skyTop = world.conf.skyTop;
    sky.sunDisk = world.conf.sunDisk;
    sky.horizonHalo = world.conf.horizonHalo;
    sky.sunHalo = world.conf.sunHalo;
    sky.sunLightColor = world.conf.sunLightColor;
    sky.sunPosition = world.conf.sunPosition;
    sky.sunIntensity = world.conf.sunIntensity;
    sky.skyIntensity = world.conf.skyIntensity;

    blases : Tacoma.Trile_Set = .{trile_list.data, cast(s32)trile_list.count};
    for world_triles {
        print("World trile %\n", it);
    }
    tlas : Tacoma.World = .{world_triles.data, cast(s32)world_triles.count};

    ptr := Tacoma.do_gen("./modules/Tacoma/", w, h, sky, blases, tlas, conf);
    data := cast(*float) talloc(w*h*4*size_of(float));
    memcpy(data, ptr, w*h*4*4);
    for 0..(w*h) {
        color : Vector3;
        color.x = data[it * 4 + 0]; 
        color.y = data[it * 4 + 1]; 
        color.z = data[it * 4 + 2]; 

        data[it * 4 + 0] = color.x;
        data[it * 4 + 1] = color.y;
        data[it * 4 + 2] = color.z;

    }
        
    imgdata : sg_image_data;
    imgdata.subimage[0][0] = .{data, cast(u64) (w*h*4*4)};

    texdesc : sg_image_desc = .{
        render_target = false,
        width         = w,
        height        = h,  
        pixel_format  = sg_pixel_format.RGBA32F,
        sample_count  = 1,
        data          = imgdata
    };

    current_screenshot = .{
        sg_make_image(*texdesc),
        w,
        h,
        true
    };
}
