g_animations: Table(string, Animation);

#scope_file
get_animation_from_string :: (animation: string) -> *Animation {
    ok, pack, anim := split_from_left(animation, ".");
    if !ok {
        log_warn("Malformed animation query: %", animation);
        return null;
    }
    return get_animation_from_pack(pack, anim);
}
#scope_export

Animation_Player :: struct {
    current_animation      : *Animation;
    queued_animation       : *Animation = null;
    current_frame          : s32 = 0;
    frame_start            : float64 = 0;
}

animation_player_tick :: (player: *Animation_Player) {
    if player.current_animation == null then return;
    frame := player.current_animation.frames[player.current_frame];
    current_time := get_time();
    if cast(s32)((current_time - player.frame_start) * 1000) > frame.duration_ms {
        player.current_frame += 1;
        player.frame_start = current_time;
        if player.current_frame >= player.current_animation.frames.count {
            player.current_frame = 0;
            if player.queued_animation != null {
                player.current_animation = player.queued_animation;
                player.queued_animation = null;
            }
        }
    }
}

animation_draw :: (player: *Animation_Player, position: Vector3, flipX: bool = false, flipY: bool = false) {
    animation_player_tick(player);
    if player.current_animation == null then log_warn("Trying to draw a null animation!!");
    create_billboard_rendering_task(position, player.current_animation, player.current_frame, flipX, flipY);
}

animation_set :: (player: *Animation_Player, animation: string) {
    player.current_frame = 0;
    player.current_animation = get_animation_from_string(animation);
}

animation_set_queued :: (player: *Animation_Player, animation: string) {
    player.queued_animation = get_animation_from_string(animation);

}
animation_set_if_not :: (player: *Animation_Player, animation: string) {
    if !animation_is(player, animation) {
        animation_set(player, animation);
    }
}

animation_is :: (player: *Animation_Player, animation: string) -> bool {
    _, pack, anim := split_from_left(animation, ".");
    return player.current_animation.name == anim;
}

Frame :: struct {
    x: s32;
    y: s32;
    w: s32;
    h: s32;
    duration_ms : s32;
}

Animation :: struct {
    name    : string;
    sheet   : sg_image;
    sheet_w : s32;
    sheet_h : s32;
    frames  : [..]Frame;   
}

Aseprite_Frame_Data :: struct {
    x: s32;
    y: s32;
    w: s32;
    h: s32;
}

Aseprite_Frame :: struct {
    duration : s32;
    frame    : Aseprite_Frame_Data;
}

Aseprite_Frame_Tag :: struct {
    name : string;
    from : s32;
    to   : s32;
}

Aseprite_Sheet_Info :: struct {
    frameTags : [..]Aseprite_Frame_Tag;
}

Aseprite_Sheet :: struct {
    frames : [..]Aseprite_Frame;
    meta   : Aseprite_Sheet_Info;
}
