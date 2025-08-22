#scope_file

#load "./roule/roule.jai";

bg_tex    : Ui_Texture;


#scope_export
game_init :: () {
    print("Game init...\n");
    print("Loading bg...\n");
    img := create_texture_from_pack("./game/resources/bg.png");
    bg_tex.tex = img;
    table_init();
}

game_tick :: () {
	if input_button_states[#char "W"] & .START {
        table_roll();
    }
}


game_draw :: () {
    w,h := get_window_size();

    
    set_shader_for_images(*bg_tex);
    immediate_rect(0,0,xx w,xx h);
    immediate_flush();

    draw_table();
}
