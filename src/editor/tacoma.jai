#run {
    tacomaString : string = #string DONE
▖▖▄▖▖▖  ▄▖▄▖▄▖  ▄▖▄▖▖  ▖▄▖▄▖▖ ▄▖▖ ▖▄▖  ▖  ▖▄▖▄▖▖▖
▌▌▌▌▌▌  ▌▌▙▘▙▖  ▌ ▌▌▛▖▞▌▙▌▐ ▌ ▐ ▛▖▌▌   ▌▞▖▌▐ ▐ ▙▌
▐ ▙▌▙▌  ▛▌▌▌▙▖  ▙▖▙▌▌▝ ▌▌ ▟▖▙▖▟▖▌▝▌▙▌  ▛ ▝▌▟▖▐ ▌▌
                                                 
                                     
      ___           ___           ___           ___           ___           ___     
     /\  \         /\  \         /\  \         /\  \         /\__\         /\  \    
     \:\  \       /::\  \       /::\  \       /::\  \       /::|  |       /::\  \   
      \:\  \     /:/\:\  \     /:/\:\  \     /:/\:\  \     /:|:|  |      /:/\:\  \  
      /::\  \   /::\~\:\  \   /:/  \:\  \   /:/  \:\  \   /:/|:|__|__   /::\~\:\  \ 
     /:/\:\__\ /:/\:\ \:\__\ /:/__/ \:\__\ /:/__/ \:\__\ /:/ |::::\__\ /:/\:\ \:\__\
    /:/  \/__/ \/__\:\/:/  / \:\  \  \/__/ \:\  \ /:/  / \/__/~~/:/  / \/__\:\/:/  /
   /:/  /           \::/  /   \:\  \        \:\  /:/  /        /:/  /       \::/  / 
   \/__/            /:/  /     \:\  \        \:\/:/  /        /:/  /        /:/  /  
                   /:/  /       \:\__\        \::/  /        /:/  /        /:/  /   
                   \/__/         \/__/         \/__/         \/__/         \/__/    
▄▖▖ ▖▄▖▄ ▖ ▄▖▄ 
▙▖▛▖▌▌▌▙▘▌ ▙▖▌▌
▙▖▌▝▌▛▌▙▘▙▖▙▖▙▘
 
    DONE
    print("%\n", tacomaString);
}

Tacoma :: #import "Tacoma";

Tacoma_Screenshot :: struct {
    image  : sg_image;
    width  : s32;
    height : s32;
    valid  : bool = false;
}

current_screenshot : Tacoma_Screenshot;


test_gen :: (w: s32, h: s32, conf: Tacoma.Gen_Config) {

    trile := get_trile("test");
    print("Testing gen!\n");
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

    ts : Tacoma.Trile_Set = .{trile_list.data, trile_list.count};

    wTrile : Tacoma.World_Trile = .{
        0,
        .{0.0, 0.0, 0.0}
    };

    world : Tacoma.World = .{*wTrile, 1};

    ptr := Tacoma.do_gen("./modules/Tacoma/", w, h, sky, ts, world, conf);
        
    imgdata : sg_image_data;
    imgdata.subimage[0][0] = .{ptr, cast(u64) (w*h*4*4)};
    
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
