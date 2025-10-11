Post_Process :: struct {
    exposure   : float = 0.0; @Slider,-1,1,0.1;
    contrast   : float = 1.0; @Slider,0.1,4.0,0.1;
    saturation : float;
    gamma      : float = 1.0; @Slider,0.3,3.0,0.1;
    tonemap    : float = 1.0; @Slider,0,1,1;
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
