g_animations: Table(string, Animation);

String :: #import "String";

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
