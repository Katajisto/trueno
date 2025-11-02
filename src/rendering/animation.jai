g_animations: Table(string, Animation);

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
    if player.current_animation == null then print("Trying to draw a null animation!!\n");
    create_billboard_rendering_task(position, player.current_animation, player.current_frame, flipX, flipY);
}

animation_set :: (player: *Animation_Player, animation: string) {
    player.current_frame = 0;
    player.current_animation = table_find_pointer(*g_animations, animation);

}
animation_set_if_not :: (player: *Animation_Player, animation: string) {
    if !animation_is(player, animation) {
        animation_set(player, animation);
    }
}

animation_is :: (player: *Animation_Player, animation: string) -> bool {
    return player.current_animation.name == animation;
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

init_spritesheets :: () {
    add_new_spritesheets_from_pack();
}

add_new_spritesheets_from_pack :: () {
    String :: #import "String";

    for v : g_asset_pack.lookup {
        isSpritesheet, remainder := String.contains(v.name, "/sprites/");
        isData := String.contains(remainder, ".json");
        if isSpritesheet && isData {
            print("Adding sheet: %\n", remainder);
            is_ok, name_without_fileformat := split_from_right(v.name, #char ".");
            sheet_image_name := sprint("%.png", name_without_fileformat);
            sheet_image, sheet_w, sheet_h := create_texture_from_pack(sheet_image_name);
            
            
            s := load_string_from_pack(v.name);
            success, sheet := Jaison.json_parse_string(s, Aseprite_Sheet,, temp);

            for sheet.meta.frameTags {
                anim : Animation;
                anim.name = sprint("%", it.name);
                anim.sheet = sheet_image;
                anim.sheet_w = sheet_w;
                anim.sheet_h = sheet_h;
                for idx : it.from..it.to {
                    frameData := sheet.frames[idx];
                    array_add(*anim.frames, Frame.{
                        frameData.frame.x,
                        frameData.frame.y,
                        frameData.frame.w,
                        frameData.frame.h,
                        frameData.duration
                    });
                }
                table_add(*g_animations, anim.name, anim);
            }
        }
    }
}
