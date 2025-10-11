Post_Process :: struct {
    exposure   : float;
    contrast   : float;
    saturation : float;
    gamma      : float = 1.0; @Slider,0.3,3.0,0.1;
    tonemap    : float = 1.0; @Slider,0,1,1;

}

current_post_process : Post_Process;
