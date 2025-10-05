#scope_export

Render_Command_Buckets :: struct {
    setup      : [..]*Render_Command;
    shadow     : [..]*Render_Command;
    reflection : [..]*Render_Command;
    main       : [..]*Render_Command;
    ui         : [..]*Render_Command;
}

render_command_buckets : Render_Command_Buckets;

Render_Command_Type :: enum {
    INVALID;
    DRAW_SKY;
    SET_CAMERA;
    DRAW_GROUND;
    GENERATE_GROUND;
}

Render_Command :: struct {
    type: Render_Command_Type = .INVALID;
}

Render_Command_Sky :: struct {
    #as using c : Render_Command;
    worldConfig : *World_Config;
}

Render_Command_Draw_Ground :: struct {
    #as using c : Render_Command;
    worldConfig : *World_Config;
}

Render_Command_Generate_Ground_Texture :: struct {
    #as using c : Render_Command;
    world : *World;
}

Render_Command_Set_Camera :: struct {
    #as using c : Render_Command;
    camera: Camera;
}

process_command_buckets :: () {
    backend_process_command_buckets();
}

#scope_file
#load "backend_sokol.jai";

