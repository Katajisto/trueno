// SH probe grid streaming helpers.
// The unified fetch queue lives in asset_manager.jai; these functions
// add entries to that queue and handle completed/failed fetches.

#scope_export

shgrid_loader_enqueue_world :: (world: *World) {
    for *chunk: world.chunks {
        if chunk.sh_valid then continue;

        already := false;
        for g_asset_manager.slots {
            if !it.occupied then continue;
            if it.req.type == .SHGRID &&
               it.req.world_name == world.name && it.req.chunk_key == chunk.coord {
                already = true;
                break;
            }
        }
        if already then continue;

        for g_asset_manager.queue {
            if it.type == .SHGRID &&
               it.world_name == world.name && it.chunk_key == chunk.coord {
                already = true;
                break;
            }
        }
        if already then continue;

        req : Fetch_Request;
        req.type       = .SHGRID;
        req.priority   = .LOADING_SCREEN;
        req.world_name = world.name;
        req.chunk_key  = chunk.coord;
        req.path       = shgrid_filename(world.name, chunk.coord);
        array_add(*g_asset_manager.queue, req);
    }
}

sh_loader_handle_failed :: (req: *Fetch_Request) {
    log_error("SH: failed to load probe grid for chunk %", req.chunk_key);
}

sh_loader_handle_completed :: (req: *Fetch_Request, data: []u8) {
    curworld := get_current_world();
    if !curworld.valid || curworld.world.name != req.world_name then return;

    header_size := cast(s64) size_of(SH_Grid_File_Header);
    if data.count < header_size {
        log_error("SH: probe grid too small for chunk %", req.chunk_key);
        return;
    }
    sh_header := cast(*SH_Grid_File_Header) data.data;
    if sh_header.magic != SH_FILE_MAGIC {
        log_error("SH: bad magic for chunk %", req.chunk_key);
        return;
    }
    n := sh_header.probe_n;
    if n != SH_PROBE_N {
        log_error("SH: probe_n mismatch for chunk % (file=%, expected=%) — re-bake required", req.chunk_key, n, SH_PROBE_N);
        return;
    }
    total_values  := cast(s64) n * n * n * 12;
    bytes_per_val := ifx sh_header.version >= 2 then size_of(u16) else size_of(float);
    if data.count < header_size + total_values * bytes_per_val {
        log_error("SH: probe grid data too short for chunk %", req.chunk_key);
        return;
    }

    // Pack flat [n^3 * 12] coefficients → 3-RGBA16F-texels-per-probe 2D texture layout.
    // Texture dims: (n*3) x (n*n).  Probe (px,py,pz) at row (pz*n+py), col (px*3+k).
    // Coefficient layout in 3 texels (12 slots):
    //   t0: R.c0-3  t1: G.c0-3  t2: B.c0-3
    tex_w := n * 3;
    n_tex := cast(s64) tex_w * n * n;
    packed := NewArray(n_tex * 4, u16);
    if sh_header.version >= 2 {
        src := cast(*u16) (data.data + header_size);
        for pz: 0..n-1  for py: 0..n-1  for px: 0..n-1 {
            probe_idx := px + py * n + pz * n * n;
            s := src + probe_idx * 12;
            for k: 0..2 {
                tex_idx := (pz * n + py) * tex_w + (px * 3 + k);
                d := packed.data + tex_idx * 4;
                for ch: 0..3  d[ch] = (s + k * 4 + ch).*;
            }
        }
    } else {
        src := cast(*float) (data.data + header_size);
        for pz: 0..n-1  for py: 0..n-1  for px: 0..n-1 {
            probe_idx := px + py * n + pz * n * n;
            s := src + probe_idx * 12;
            for k: 0..2 {
                tex_idx := (pz * n + py) * tex_w + (px * 3 + k);
                d := packed.data + tex_idx * 4;
                for ch: 0..3  d[ch] = f32_to_f16((s + k * 4 + ch).*);
            }
        }
    }

    sh_imgdata : sg_image_data;
    sh_imgdata.subimage[0][0] = .{ packed.data, cast(u64)(n_tex * 4 * size_of(u16)) };
    sh_desc : sg_image_desc = .{
        width        = tex_w,
        height       = n * n,
        pixel_format = sg_pixel_format.RGBA16F,
        sample_count = 1,
        data         = sh_imgdata,
    };
    chunk := table_find_pointer(*curworld.world.chunks, req.chunk_key);
    if chunk != null {
        if chunk.sh_probe_grid.id != 0 then sg_destroy_image(chunk.sh_probe_grid);
        chunk.sh_probe_grid = sg_make_image(*sh_desc);
        chunk.sh_valid = true;
        log_debug("SH: loaded probe grid for chunk %", req.chunk_key);
    }
    free(packed.data);
}
