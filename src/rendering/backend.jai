#scope_export

Render_Command_Buckets :: struct {
    setup      : [..]*Render_Command;
    shadow     : [..]*Render_Command;
    reflection : [..]*Render_Command;
    main       : [..]*Render_Command;
    gbuffer    : [..]*Render_Command;
    ui         : [..]*Render_Command;
}

render_command_buckets : Render_Command_Buckets;

Render_Command_Type :: enum {
    INVALID;
    DRAW_SKY;
    SET_CAMERA;
    DRAW_GROUND;
    ADD_TRILE_POSITIONS;
    DRAW_TRILE_POSITIONS;
    UPDATE_TRIXELS;
    DRAW_TRIXELS;
    SET_LIGHT;
    DRAW_BILLBOARD;
    DRAW_PARTICLES;
}

Render_Command :: struct {
    type: Render_Command_Type = .INVALID;
}

Render_Command_Sky :: struct {
    #as using c : Render_Command;
    c.type      = .DRAW_SKY;
    worldConfig : *World_Config;
}

Render_Command_Set_Light :: struct {
    #as using c : Render_Command;
    c.type      = .SET_LIGHT;
    worldConfig : *World_Config;
}

Render_Command_Add_Trile_Positions :: struct {
    #as using c : Render_Command;
    c.type      = .ADD_TRILE_POSITIONS;
    positions   : []Vector4;
}

Render_Command_Draw_Trile_Positions :: struct {
    #as using c  : Render_Command;
    c.type       = .DRAW_TRILE_POSITIONS;
    trile        : string;
    chunk_key    : Chunk_Key;
    amount       : s32;
    conf         : *World_Config;
    preview_mode : s32 = 0;   // 0=normal, 1=add preview (blue), 2=delete preview (red)
    offset_index : s32 = 0;  // index into trile_offsets, assigned at task-conversion time
}

Render_Command_Update_Trixels :: struct {
    #as using c    : Render_Command;
    c.type         = .UPDATE_TRIXELS;
    trile          : *Trile;
    colMultipliers : *[16][16][16]Vector3;
}

Render_Command_Draw_Billboard :: struct {
    #as using c    : Render_Command;
    c.type         = .DRAW_BILLBOARD;
    position       : Vector3;
    animation      : *Animation;
    frame          : s32;
    flipX          : bool;
    flipY          : bool;
}

Render_Command_Draw_Trixels :: struct {
    #as using c : Render_Command;
    c.type      = .DRAW_TRIXELS;
}

Render_Command_Draw_Particles :: struct {
    #as using c    : Render_Command;
    c.type         = .DRAW_PARTICLES;
    count          : s32;
    blend_mode     : Particle_Blend_Mode;
    sheet          : sg_image;
    pos_size       : [2048]Vector4;
    uv_rects       : [2048]Vector4;
    colors         : [2048]Vector4;
}

Render_Command_Draw_Ground :: struct {
    #as using c : Render_Command;
    c.type      = .DRAW_GROUND;
    worldConfig : *World_Config;
}

Render_Command_Set_Camera :: struct {
    #as using c : Render_Command;
    c.type      = .SET_CAMERA;
    camera: Camera;
}

process_command_buckets :: () {
    backend_process_command_buckets();
}

#scope_file
#load "backend_sokol.jai";

