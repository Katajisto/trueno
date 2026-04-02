#scope_file

THUMB_SIZE :: 64;
ATLAS_SIZE :: 2048;
ATLAS_COLS :: ATLAS_SIZE / THUMB_SIZE;

g_thumbnail_atlas_buf  : [ATLAS_SIZE * ATLAS_SIZE * 4] u8;
g_thumbnail_slot_map   : Table(string, int);
g_thumbnail_slot_count : int;

blit_slot :: (thumb: *[THUMB_SIZE * THUMB_SIZE * 4] u8, slot: int) {
    col     := slot % ATLAS_COLS;
    row     := slot / ATLAS_COLS;
    start_x := col * THUMB_SIZE;
    start_y := row * THUMB_SIZE;
    for py : 0..THUMB_SIZE-1 {
        for px : 0..THUMB_SIZE-1 {
            ai := ((start_y + py) * ATLAS_SIZE + (start_x + px)) * 4;
            ti := (py * THUMB_SIZE + px) * 4;
            g_thumbnail_atlas_buf[ai]   = (thumb.*)[ti];
            g_thumbnail_atlas_buf[ai+1] = (thumb.*)[ti+1];
            g_thumbnail_atlas_buf[ai+2] = (thumb.*)[ti+2];
            g_thumbnail_atlas_buf[ai+3] = (thumb.*)[ti+3];
        }
    }
}

render_thumbnail :: (trile: *Trile, out: *[THUMB_SIZE * THUMB_SIZE * 4] u8) {
    ray_dir   := normalize(Vector3.{-1.0, -1.2, -1.0});
    right_vec := normalize(Vector3.{1.0, 0.0, -1.0});
    up_vec    := -normalize(cross(ray_dir, right_vec));
    center    := Vector3.{8.0, 8.0, 8.0};
    scale     : float = 10.5;
    light_dir := normalize(Vector3.{-1.0, -2.0, -1.0});

    for py : 0..THUMB_SIZE-1 {
        for px : 0..THUMB_SIZE-1 {
            u : float = (cast(float)px + 0.5) / cast(float)THUMB_SIZE * 2.0 - 1.0;
            v : float = -((cast(float)py + 0.5) / cast(float)THUMB_SIZE * 2.0 - 1.0);

            o := center + right_vec * (u * scale) + up_vec * (v * scale) - ray_dir * 30.0;

            ix := cast(int) floor(o.x);
            iy := cast(int) floor(o.y);
            iz := cast(int) floor(o.z);

            sx := ifx ray_dir.x >= 0.0 then 1 else -1;
            sy := ifx ray_dir.y >= 0.0 then 1 else -1;
            sz := ifx ray_dir.z >= 0.0 then 1 else -1;

            tdx := abs(1.0 / ray_dir.x);
            tdy := abs(1.0 / ray_dir.y);
            tdz := abs(1.0 / ray_dir.z);

            nx  := ifx ray_dir.x >= 0.0 then cast(float)(ix + 1) else cast(float)ix;
            ny  := ifx ray_dir.y >= 0.0 then cast(float)(iy + 1) else cast(float)iy;
            nz  := ifx ray_dir.z >= 0.0 then cast(float)(iz + 1) else cast(float)iz;
            tmx := (nx - o.x) / ray_dir.x;
            tmy := (ny - o.y) / ray_dir.y;
            tmz := (nz - o.z) / ray_dir.z;

            fn  : Vector3 = .{0.0, 1.0, 0.0};
            hit : bool;
            hc  : Vector3;

            for 0..199 {
                if ix >= 0 && ix < 16 && iy >= 0 && iy < 16 && iz >= 0 && iz < 16 {
                    if !trile.trixels[ix][iy][iz].empty {
                        hit = true;
                        hc  = trile.trixels[ix][iy][iz].material.color;
                        break;
                    }
                }
                if tmx < tmy && tmx < tmz {
                    fn = .{cast(float)-sx, 0.0, 0.0};
                    ix += sx;
                    tmx += tdx;
                } else if tmy < tmz {
                    fn = .{0.0, cast(float)-sy, 0.0};
                    iy += sy;
                    tmy += tdy;
                } else {
                    fn = .{0.0, 0.0, cast(float)-sz};
                    iz += sz;
                    tmz += tdz;
                }
            }

            pidx := (py * THUMB_SIZE + px) * 4;
            if hit {
                diff  := max(0.0, dot(fn, -light_dir));
                brite := 0.3 + diff * 0.7;
                (out.*)[pidx]   = xx clamp(cast(int)(hc.x * brite * 255.0 + 0.5), 0, 255);
                (out.*)[pidx+1] = xx clamp(cast(int)(hc.y * brite * 255.0 + 0.5), 0, 255);
                (out.*)[pidx+2] = xx clamp(cast(int)(hc.z * brite * 255.0 + 0.5), 0, 255);
                (out.*)[pidx+3] = 255;
            } else {
                val : u8 = ifx ((px / 8 + py / 8) % 2 == 0) then cast(u8)55 else cast(u8)38;
                (out.*)[pidx]   = val;
                (out.*)[pidx+1] = val;
                (out.*)[pidx+2] = val;
                (out.*)[pidx+3] = 255;
            }
        }
    }
}

upload_atlas :: () {
    imgdata : sg_image_data;
    imgdata.subimage[0][0] = .{ g_thumbnail_atlas_buf.data, cast(u64)(ATLAS_SIZE * ATLAS_SIZE * 4) };
    sg_update_image(g_thumbnail_atlas.tex, *imgdata);
}

#scope_export

g_thumbnail_atlas : Ui_Texture;

get_thumbnail_uv :: (name: string) -> (uv_min: Vector2, uv_max: Vector2, found: bool) {
    ptr := table_find_pointer(*g_thumbnail_slot_map, name);
    if !ptr return .{}, .{}, false;
    slot := ptr.*;
    col  := slot % ATLAS_COLS;
    row  := slot / ATLAS_COLS;
    inv  := 1.0 / cast(float)ATLAS_SIZE;
    u0   := cast(float)(col * THUMB_SIZE) * inv;
    v0   := cast(float)(row * THUMB_SIZE) * inv;
    u1   := cast(float)((col + 1) * THUMB_SIZE) * inv;
    v1   := cast(float)((row + 1) * THUMB_SIZE) * inv;
    return .{u0, v0}, .{u1, v1}, true;
}

update_trile_thumbnail :: (name: string) {
    trile := get_trile(name);
    if !trile return;

    ptr  := table_find_pointer(*g_thumbnail_slot_map, name);
    slot : int;
    if ptr {
        slot = ptr.*;
    } else {
        slot = g_thumbnail_slot_count;
        table_set(*g_thumbnail_slot_map, name, slot);
        g_thumbnail_slot_count += 1;
    }

    thumb : [THUMB_SIZE * THUMB_SIZE * 4] u8;
    render_thumbnail(trile, *thumb);
    blit_slot(*thumb, slot);

    if g_thumbnail_atlas.tex.id != INVALID_ID {
        upload_atlas();
    }
}

init_trile_thumbnails :: () {
    tpt := get_trile_table_ptr();
    for v : tpt {
        trile := get_trile(v.name);
        if !trile continue;

        slot := g_thumbnail_slot_count;
        table_set(*g_thumbnail_slot_map, v.name, slot);
        g_thumbnail_slot_count += 1;

        thumb : [THUMB_SIZE * THUMB_SIZE * 4] u8;
        render_thumbnail(trile, *thumb);
        blit_slot(*thumb, slot);
    }

    desc := sg_image_desc.{
        width        = xx ATLAS_SIZE,
        height       = xx ATLAS_SIZE,
        pixel_format = .RGBA8,
        usage        = .DYNAMIC,
    };
    g_thumbnail_atlas.tex = sg_make_image(*desc);
    upload_atlas();
}
