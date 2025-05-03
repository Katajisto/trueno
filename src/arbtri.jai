Arb_Tri :: struct {
    pos : [3]Vector3;
    col : [3]Vector4;
    uv  : [3]Vector2;
}

Arb_Draw_Command_Type :: enum {
    INVALID;
    DRAW_TEXT;
    FLUSH_TRI;
    SET_TEXTURE;
    PREPARE_TEXT;
    FONT_BOUNDARY;
    QUAD_OCCLUDER;
    REMOVE_TEXTURE;
}

Arb_Draw_Command :: struct {
    type       : Arb_Draw_Command_Type = .INVALID;

    // for triangles
    tri_offset : int = 0;
    tri_count  : int = 0;
    texture    : *Ui_Texture;
    
    // for text
    layer: s32  = 0;

}

Arb_Tri_State :: struct {
    active       : bool = false;
    trilist      : [..]Arb_Tri;
    command_list : [..]Arb_Draw_Command;
    latest_flush : int = 0;
}

arbTriState : Arb_Tri_State;

init_arb_state :: () {
    gPipelines.arbtri.bind.images[0] = default_texture.tex;
    array_reset_keeping_memory(*arbTriState.trilist);
    array_reset_keeping_memory(*arbTriState.command_list);
    arbTriState.active = true;
    arbTriState.latest_flush = 0;
} 

arb_tri_command_add :: (command: Arb_Draw_Command) {
    if !arbTriState.active {
        init_arb_state();
    }

    array_add(*arbTriState.command_list, command);
}

arb_tri_add :: (tri: Arb_Tri) {
    if !arbTriState.active {
        init_arb_state();
    }

    array_add(*arbTriState.trilist, tri);
}

arb_tri_flush :: () {
    if !arbTriState.active {
        return;
    }


    transform_to_screen_x :: (coord: float) -> float {
        w, h := get_window_size();
        return (coord / cast(float) w) * 2.0 - 1.0;
    }

    transform_to_screen_y :: (coord: float) -> float {
        w, h := get_window_size();
        return (coord / cast(float) h) * 2.0 - 1.0;
    }

    arbTriState.active = false;    

    for tri, i : arbTriState.trilist {
        bgn := i * 3 * 9;
        for 0..2 {
            gArbtriMem[bgn + it * 9 + 0] = transform_to_screen_x(tri.pos[it].x);  
            gArbtriMem[bgn + it * 9 + 1] = transform_to_screen_y(tri.pos[it].y) * -1.0;  
            gArbtriMem[bgn + it * 9 + 2] = 0;  
            gArbtriMem[bgn + it * 9 + 3] = tri.col[it].x;  
            gArbtriMem[bgn + it * 9 + 4] = tri.col[it].y;  
            gArbtriMem[bgn + it * 9 + 5] = tri.col[it].z;  
            gArbtriMem[bgn + it * 9 + 6] = tri.col[it].w;  
            gArbtriMem[bgn + it * 9 + 7] = tri.uv[it].x;  
            gArbtriMem[bgn + it * 9 + 8] = tri.uv[it].y;  
        }
    }

    sg_update_buffer(gPipelines.arbtri.bind.vertex_buffers[0], *(sg_range.{ ptr = gArbtriMem.data, size = size_of(type_of(gArbtriMem)) }));

    flush_arb_commands();
}

debug_arb_flush : bool : false;

layer : s32  = 0;

flush_arb_commands :: () {
    layer = 0;
    if debug_arb_flush then print(" --- !BEGIN FLUSH! ---- \n");
    for arbTriState.command_list {
        if debug_arb_flush then print("[command] %\n", it.type);
        if it.type == {
            case .SET_TEXTURE;
                gPipelines.arbtri.bind.images[0] = it.texture.tex;
                gCurrentTexture = it.texture;
            case .REMOVE_TEXTURE;
                gCurrentTexture = null;
            case .FLUSH_TRI;
                sg_apply_pipeline(gPipelines.arbtri.pipeline);
                sg_apply_bindings(*gPipelines.arbtri.bind);
                sg_draw(xx (it.tri_offset * 3), xx (it.tri_count * 3), 1);
            case .PREPARE_TEXT;
            case .DRAW_TEXT;
                sgl_draw_layer(it.layer);
        }
    }
}
