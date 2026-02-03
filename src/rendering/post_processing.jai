Post_Process :: struct {
    exposure          : float = 0.0; @Slider,0,3,0.1;
    contrast          : float = 1.0; @Slider,0,6,0.1;
    saturation        : float = 1.0; @Slider,0.0,2.0,0.1;
    gamma             : float = 2.2; @Slider,0.3,3.0,0.1;
    tonemap           : float = 1.0; @Slider,0,1,1;
    ssao              : float = 1.0; @Slider,0,5,0.1;
    ssao_size         : s32   = 1;   @Slider,0,5,1;
    dilate_separation : float = 1.0; @Slider,0,6,0.1;
    dilate_size       : s32   = 2;   @Slider,0,10,1;
    dilate_min        : float = 0.1; @Slider,0,1,0.1;
    dilate_max        : float = 0.3; @Slider,0,1,0.1;
    dof_blur_size     : s32   = 2;   @Slider,0,10,1;
    dof_min           : float = 1.0; @Slider,0,10,1;
    dof_max           : float = 3.0; @Slider,0,50,1;
    dof_point         : float = 5.0; @Slider,0,30,1;
    bloom_size        : s32   = 5;   @Slider,0,10,1;
    bloom_separation  : float = 3.0; @Slider,0,10,1;
    bloom_treshold    : float = 0.4; @Slider,0,1,0.1;
    bloom_amount      : float = 1.0; @Slider,0,5,0.1;
    
    vignette_intensity: float = 0.5; @Slider,0,1,0.1;
    vignette_radius: float = 0.5; @Slider,0,1,0.1;
    scanlines_intensity: float = 0.1; @Slider,0,1,0.1;
    scanlines_density: float = 1; @Slider,0,10,0.1;
    chromatic_aberration_intensity: float = 0.0; @Slider,0,0.05,0.001;
    film_grain_intensity: float = 0.0; @Slider,0,0.5,0.001;
    barrel_distortion_intensity: float = 0.0; @Slider,-2,2,0.1;
    lut_mode: s32 = 0; @Slider,0,2,1; // 0 -> no LUT, 1 -> LUT with interpolation 2 -> LUT no iterpolate
}


current_post_process : Post_Process;

load_post_process_from_pack :: () {
    s := load_string_from_pack("game_core", "postprocess.json");
    success, pp:= Jaison.json_parse_string(s, Post_Process,, temp);
    if success {
        current_post_process = pp;        
    }
}

reset_post_process :: () {
    load_post_process_from_pack();
} @Command

Color_LUT :: struct {
    name:  string;
    image: sg_image;
}

LUT_list      : [..]Color_LUT;
LUT_name_list : [..]string;
g_current_lut_texture_index : s32 = 0;


add_image_to_lut_list :: (img: sg_image, name: string) {
    for LUT_list {
        if it.name == name then return;
    }
    
    newSheet := Color_LUT.{
        name  = sprint("%", name),
        image = img,
    };
    array_add(*LUT_list, newSheet);
    array_add(*LUT_name_list, newSheet.name);
}
