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

Post_Process :: struct {
    exposure   : float;
    contrast   : float;
    saturation : float;
}

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

test_gen :: (w: s32, h: s32, postprocess: Post_Process, conf: Tacoma.Gen_Config, worldConf: World_Config) {
    trile := get_trile("test");

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

    gfx := get_trile_gfx("test");
    ttrile.vertices = gfx.vertices.data;
    ttrile.vertexCount = cast(s32) (gfx.vertices.count / 3);

    trile_list : [1]Tacoma.Trile_Data;
    trile_list[0] = ttrile;

    sky : Tacoma.Sky_Config;

    sky.skyBase = worldConf.skyBase;
    sky.skyTop = worldConf.skyTop;
    sky.sunDisk = worldConf.sunDisk;
    sky.horizonHalo = worldConf.horizonHalo;
    sky.sunHalo = worldConf.sunHalo;
    sky.sunLightColor = worldConf.sunLightColor;
    sky.sunPosition = worldConf.sunPosition;
    sky.sunIntensity = worldConf.sunIntensity;
    sky.skyIntensity = worldConf.skyIntensity;

    ts : Tacoma.Trile_Set = .{trile_list.data, trile_list.count};

    wTrile : Tacoma.World_Trile = .{
        0,
        .{1.0, 0.0, 0.0}
    };
    
    wTrile2 : Tacoma.World_Trile = .{
        0,
        .{0.0, 1.0, 1.0}
    };

    triles : [2]Tacoma.World_Trile = .[wTrile, wTrile2];

    world : Tacoma.World = .{triles.data, 2};

    ptr := Tacoma.do_gen("./modules/Tacoma/", w, h, sky, ts, world, conf);
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
