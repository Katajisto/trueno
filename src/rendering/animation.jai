g_spritesheets : Table(string, Spritesheet);
g_animations: Table(string, Animation);

String :: #import "String";

Spritesheet :: struct {
    name   : string;
    step_x : u32 = 32;
    step_y : u32 = 32;
    w      : s32 = 0;
    h      : s32 = 0;
    sheet  : sg_image; 
}

Animation :: struct {
    name        : string;
    spritesheet : string;
    ids         : [..]u32;   
    fps         : float;
}

load_spritesheets :: () {
    Jaison :: #import "Jaison";
    s := load_string_from_pack("./game/resources/spritesheets.json");
    success, sheets := Jaison.json_parse_string(s, [..]Spritesheet,, temp);
    if !success then return;
    for sheets {
        print("Loaded %\n", it.name);
        img, w, h := create_texture_from_pack(tprint("./game/resources/sprites/%", it.name));
        name_cpy := sprint("%", it.name);
        newSheet := Spritesheet.{
            name   = name_cpy,
            step_x = it.step_x,
            step_y = it.step_y,
            sheet  = img,
            w      = w,
            h      = h,
        };
        table_add(*g_spritesheets, name_cpy, newSheet);
    }
}

init_spritesheets :: () {
    load_spritesheets();
    add_new_spritesheets_from_pack();
}

add_new_spritesheets_from_pack :: () {
    for v : g_asset_pack.lookup {
        isSpritesheet, remainder := String.contains(v.name, "/sprites/");
        if isSpritesheet {
            ok, sheet := table_find_new(*g_spritesheets, remainder);
            if !ok {
                print("Adding sheet: %\n", remainder);
                img, w, h := create_texture_from_pack(v.name);
                newSheet := Spritesheet.{
                    name  = remainder,
                    sheet = img,
                    w     = w,
                    h     = h,
                };
                table_add(*g_spritesheets, remainder, newSheet);
            }
        }
    }
}
