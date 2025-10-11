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

post_process_pipeline :: (color: Vector3, post_process: Post_Process) -> Vector3 {
    vec3 :: (f: float) -> Vector3 {
        return .{f,f,f};
    }

    v := color;
    v *= pow(2.0, post_process.exposure);
    v *= 0.6;
    a : float = 2.51;
    b : float = 0.03;
    c : float = 2.43;
    d : float = 0.59;
    e : float = 0.14;
    pre_clamp := (v*(a*v+vec3(b)))/(v*(c*v+vec3(d))+vec3(e));
    sdr : Vector3;
    sdr.x = clamp(pre_clamp.x, 0.0, 1.0);
    sdr.y = clamp(pre_clamp.y, 0.0, 1.0);
    sdr.z = clamp(pre_clamp.z, 0.0, 1.0);
    
    sdr =  vec3(0.5) + post_process.contrast * (sdr - vec3(0.5));
    LUMINANCE := Vector3.{0.2126, 0.7152, 0.0722};
    grayscale := dot(sdr, LUMINANCE);
    return lerp(vec3(grayscale), sdr, post_process.saturation);
}

gen_reference :: (w: s32, h: s32, postprocess: Post_Process, conf: Tacoma.Gen_Config, world: World) {
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

        color = post_process_pipeline(color, postprocess);

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
