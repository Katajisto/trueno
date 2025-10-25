Post_Process :: struct {
    exposure          : float = 0.0; @Slider,-1,1,0.1;
    contrast          : float = 1.0; @Slider,0.1,4.0,0.1;
    saturation        : float = 1.0; @Slider,0.0,2.0,0.1;
    gamma             : float = 1.0; @Slider,0.3,3.0,0.1;
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
    bloom_treshold   : float = 0.4; @Slider,0,1,0.1;
    bloom_amount      : float = 1.0; @Slider,0,5,0.1;
}

current_post_process : Post_Process;

load_post_process_from_pack :: () {
    s := load_string_from_pack("./game/resources/postprocess.json");
    success, pp:= Jaison.json_parse_string(s, Post_Process,, temp);
    if success {
        current_post_process = pp;        
    }
}

reset_post_process :: () {
    load_post_process_from_pack();
} @Command
