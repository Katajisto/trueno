Loading_Screen_Config :: struct {
    background_color : Vector4 = .{ 0.05, 0.05, 0.05, 1.0 };
    bar_bg_color     : Vector4 = .{ 0.15, 0.15, 0.15, 1.0 };
    bar_fill_color   : Vector4 = .{ 0.3,  0.7,  1.0,  1.0 };
}

loading_screen_config : Loading_Screen_Config;

set_loading_screen_config :: (config: Loading_Screen_Config) {
    loading_screen_config = config;
}

draw_loading_screen :: () {
}
