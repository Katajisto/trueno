Arb_Tri :: struct {
    pos: [3]Vector3;
    col: [3]Vector4;
    uv: [3]Vector2;
}

Arb_Tri_State :: struct {
    active : bool = false;
    trilist : [..]Arb_Tri;
}

arbTriState : Arb_Tri_State;

arb_tri_add :: (tri: Arb_Tri) {
    if !arbTriState.active {
        array_reset_keeping_memory(*arbTriState.trilist);
        arbTriState.active = true;
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

    sg_apply_pipeline(gPipelines.arbtri.pipeline);
    sg_apply_bindings(*gPipelines.arbtri.bind);
    sg_draw(0, xx (arbTriState.trilist.count * 3), 1);
}
