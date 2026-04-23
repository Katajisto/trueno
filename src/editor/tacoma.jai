#run {
    #load "../meta/ascii.jai";
    print("%\n", ascii_tacoma);
}

Tacoma :: #import "Tacoma";

Tacoma_Screenshot :: struct {
    image  : sg_image;
    width  : s32;
    height : s32;
    valid  : bool = false;
}

current_screenshot : Tacoma_Screenshot;

// Single global atlas entry: stored on the World once baked.
RDM_Atlas_Entry_Bake :: struct {
    world_pos:  Vector3;
    x, y:       s32;      // top-left in atlas pixels
    w, h:       s32;      // pixel size of this RDM (= 2*size, 3*size)
}

RDM_ATLAS_MAX_SIZE :: 16384;  // GPU 2D texture ceiling.

ctx : *Tacoma.Tacoma_Context;

RDM_Bake_Job :: struct {
    world_trile_index: s32;
    world_pos:         Vector3;
    size:              s32;  // per-instance RDM side in px (tile = 2*size x 3*size).
}

RDM_Global_Bake :: struct {
    data        : *float;         // CPU atlas buffer (RGBA32F during bake)
    width       : s32;
    height      : s32;
    cursor_x    : s32;
    cursor_y    : s32;
    row_height  : s32;
    entries     : [..]RDM_Atlas_Entry_Bake;
}

RDM_Bake_State :: struct {
    active      : bool = false;
    quality     : s32  = 100;
    jobs        : [..]RDM_Bake_Job;
    current_job : s32  = 0;
    atlas       : RDM_Global_Bake;
}

rdm_bake : RDM_Bake_State;

SH_Bake_State :: struct {
    active        : bool;
    quality       : s32;
    include_water : bool;
    chunk_keys    : [..]Chunk_Key;
    current_chunk : s32;
}

sh_bake : SH_Bake_State;

rdm_job_quality :: (job: RDM_Bake_Job) -> s32 {
    return rdm_bake.quality;
}

rdm_sort_jobs_by_height_desc :: (jobs: *[..]RDM_Bake_Job) {
    n := jobs.count;
    for i: 1..n-1 {
        key := jobs.data[i];
        j := i - 1;
        while j >= 0 && jobs.data[j].size < key.size {
            jobs.data[j + 1] = jobs.data[j];
            j -= 1;
        }
        jobs.data[j + 1] = key;
    }
}

// Simulate shelf pack of the current jobs array into a square atlas of `atlas_size`.
// Returns true if all fit. Assumes jobs are already sorted by tile height descending.
rdm_simulate_shelf_pack :: (jobs: []RDM_Bake_Job, atlas_size: s32) -> bool {
    cursor_x : s32 = 0;
    cursor_y : s32 = 0;
    row_h    : s32 = 0;
    for job: jobs {
        w := 2 * job.size;
        h := 3 * job.size;
        if w > atlas_size || h > atlas_size return false;
        if cursor_x + w > atlas_size {
            cursor_y += row_h;
            cursor_x = 0;
            row_h    = 0;
        }
        if cursor_y + h > atlas_size return false;
        cursor_x += w;
        if h > row_h then row_h = h;
    }
    return true;
}

// Choose min pow2 square atlas fitting all jobs (variable tile sizes). Caps at RDM_ATLAS_MAX_SIZE.
rdm_calc_global_atlas_size :: (jobs: []RDM_Bake_Job) -> (s32, s32) {
    if jobs.count == 0 return 16, 16;
    target : s32 = 16;
    while target < RDM_ATLAS_MAX_SIZE {
        if rdm_simulate_shelf_pack(jobs, target) return target, target;
        target *= 2;
    }
    if !rdm_simulate_shelf_pack(jobs, RDM_ATLAS_MAX_SIZE) {
        log_warn("RDM atlas cap reached (%); some instances may not fit.", RDM_ATLAS_MAX_SIZE);
    }
    return RDM_ATLAS_MAX_SIZE, RDM_ATLAS_MAX_SIZE;
}

// Build the Tacoma scene from the world and emit one bake job per RDM-flagged instance.
// chunk_keys is accepted for API compatibility but ignored — bakes always cover every flagged
// instance because the global atlas + manifest is rewritten as a whole.
rdm_bake_start :: (world: World, quality: s32, include_water: bool, chunk_keys: []Chunk_Key = .[]) {
    if rdm_bake.active then return;

    trile_list : [..]Tacoma.Trile_Data;
    trile_list.allocator = temp;
    world_triles : [..]Tacoma.World_Trile;
    world_triles.allocator = temp;

    trile_name_to_index: Table(string, s32);
    trile_name_to_index.allocator = temp;

    for chunk: world.chunks {
        for group: chunk.groups {
            success, idx := table_find(*trile_name_to_index, group.trile_name);
            if !success {
                trile, trile_ok := get_trile(group.trile_name);
                if !trile_ok  continue;
                ttrile : Tacoma.Trile_Data;
                for x: 0..15 {
                    for y: 0..15 {
                        for z: 0..15 {
                            ttrile.trixels[x][y][z] = .{
                                trile.trixels[x][y][z].empty,
                                trile.trixels[x][y][z].material.color,
                                material_encode_to_float(trile.trixels[x][y][z].material)
                            };
                        }
                    }
                }
                gfx := get_trile_gfx(group.trile_name);
                ttrile.vertices = gfx.vertices.data;
                ttrile.vertexCount = cast(s32) (gfx.vertices.count / 3);
                idx = cast(s32) trile_list.count;
                array_add(*trile_list, ttrile);
                table_set(*trile_name_to_index, group.trile_name, idx);
            }

            for inst: group.instances {
                world_trile_idx := cast(s32) world_triles.count;
                wx, wy, wz := chunk_local_to_world(chunk.coord, inst.x, inst.y, inst.z);
                wpos := Vector3.{cast(float) wx, cast(float) wy, cast(float) wz};
                array_add(*world_triles, Tacoma.World_Trile.{idx, wpos, cast(s32) inst.orientation});

                inst_size := get_rdm_instance_size(*world, wx, wy, wz);
                if inst_size > 0 {
                    array_add(*rdm_bake.jobs, .{
                        world_trile_index = world_trile_idx,
                        world_pos         = wpos,
                        size              = inst_size,
                    });
                }
            }
        }
    }

    sky    : Tacoma.Sky_Config = world_to_sky_config(world);
    blases : Tacoma.Trile_Set  = .{trile_list.data,   cast(s32) trile_list.count};
    tlas   : Tacoma.World      = .{world_triles.data, cast(s32) world_triles.count};
    ctx = Tacoma.tacoma_init("./modules/Tacoma/");
    Tacoma.tacoma_load_scene(ctx, sky, blases, tlas, cast(s32) include_water);

    // Sort jobs tallest-first for a tighter shelf pack.
    rdm_sort_jobs_by_height_desc(*rdm_bake.jobs);

    // Allocate global CPU atlas large enough for all jobs.
    aw, ah := rdm_calc_global_atlas_size(rdm_bake.jobs);
    atlas_bytes := cast(s64) aw * cast(s64) ah * 4 * size_of(float);
    rdm_bake.atlas.width  = aw;
    rdm_bake.atlas.height = ah;
    rdm_bake.atlas.data   = cast(*float) alloc(atlas_bytes);
    memset(rdm_bake.atlas.data, 0, atlas_bytes);
    log_info("RDM global atlas: %x% (% MB) for % jobs",
        aw, ah, cast(float)atlas_bytes / (1024.0 * 1024.0), rdm_bake.jobs.count);

    rdm_bake.active = true;
    rdm_bake.quality = quality;

    if rdm_bake.jobs.count == 0 {
        rdm_bake_finish();
    }
}

// Queue all RDM-flagged instances. (chunk_keys parameter is ignored — see rdm_bake_start.)
rdm_bake_all_chunks :: (world: World, quality: s32, include_water: bool) {
    rdm_bake_start(world, quality, include_water);
}

rdm_bake_chunks :: (chunk_keys: []Chunk_Key, world: World, quality: s32, include_water: bool) {
    rdm_bake_start(world, quality, include_water, chunk_keys);
}

// Process at most one RDM per frame.
rdm_bake_tick :: () {
    if !rdm_bake.active then return;
    if rdm_bake.current_job >= cast(s32) rdm_bake.jobs.count {
        rdm_bake_finish();
        return;
    }

    job := rdm_bake.jobs[rdm_bake.current_job];

    size : s32 = job.size;
    w    := 2 * size;
    h    := 3 * size;
    ptr  := Tacoma.tacoma_render_rdm(ctx, job.world_trile_index, 0, rdm_job_quality(job), size);

    bake := *rdm_bake.atlas;

    if bake.cursor_x + w > bake.width {
        bake.cursor_y += bake.row_height;
        bake.cursor_x = 0;
        bake.row_height = 0;
    }

    ax := bake.cursor_x;
    ay := bake.cursor_y;

    if ay + h <= bake.height {
        src := cast(*u8) ptr;
        row_bytes := cast(s64) w * 4 * size_of(float);
        for row: 0..h-1 {
            dst_offset := (cast(s64)(ay + row) * cast(s64) bake.width + cast(s64) ax) * 4 * size_of(float);
            src_offset := cast(s64) row * row_bytes;
            memcpy(cast(*u8) bake.data + dst_offset, src + src_offset, row_bytes);
        }

        entry : RDM_Atlas_Entry_Bake;
        entry.world_pos = job.world_pos;
        entry.x = ax;
        entry.y = ay;
        entry.w = w;
        entry.h = h;
        array_add(*bake.entries, entry);
    } else {
        log_warn("RDM global atlas overflow, skipping (pos=%)", job.world_pos);
    }

    bake.cursor_x += w;
    if h > bake.row_height then bake.row_height = h;

    tacoma_handle_result(ptr, w, h);
    rdm_bake.current_job += 1;
}

rdm_bake_finish :: () {
    if ctx != null then tacoma_stop();

    curworld := get_current_world();
    bake := *rdm_bake.atlas;

    if bake.entries.count > 0 {
        // a) Pack atlas into RGBA16F half-floats and upload to g_rdm_atlas.
        upload_global_atlas_image(bake);

        // b) Populate world.rdm_lookup with normalized UV rects.
        if curworld.valid {
            array_reset_keeping_memory(*curworld.world.rdm_lookup);
            atlas_w := cast(float) bake.width;
            atlas_h := cast(float) bake.height;
            for entry: bake.entries {
                e : Rdm_Atlas_Entry;
                e.x = cast(s32) entry.world_pos.x;
                e.y = cast(s32) entry.world_pos.y;
                e.z = cast(s32) entry.world_pos.z;
                e.atlas_rect = .{
                    cast(float) entry.x / atlas_w,
                    cast(float) entry.y / atlas_h,
                    cast(float) entry.w / atlas_w,
                    cast(float) entry.h / atlas_h,
                };
                array_add(*curworld.world.rdm_lookup, e);
            }
        }

        // c) Save atlas + manifest to disk.
        rdm_save_global_atlas_to_disk(bake);
        if curworld.valid then rdm_save_global_manifest_to_disk(curworld.world.name, curworld.world.rdm_lookup);
    }

    log_info("RDM bake complete: % entries", bake.entries.count);

    if bake.data != null then free(bake.data);
    array_free(bake.entries);
    array_free(rdm_bake.jobs);
    rdm_bake = .{};
}

// Convert RGBA32F CPU atlas to RGBA16F and upload to g_rdm_atlas.
upload_global_atlas_image :: (bake: *RDM_Global_Bake) {
    pixel_count := cast(s64) bake.width * cast(s64) bake.height * 4;
    halves := cast(*u16) alloc(pixel_count * size_of(u16));
    defer free(halves);
    for i: 0..pixel_count - 1  halves[i] = f32_to_f16(bake.data[i]);

    imgdata : sg_image_data;
    imgdata.subimage[0][0] = .{halves, cast(u64)(pixel_count * size_of(u16))};
    desc : sg_image_desc = .{
        render_target = false,
        width         = bake.width,
        height        = bake.height,
        pixel_format  = sg_pixel_format.RGBA16F,
        sample_count  = 1,
        data          = imgdata,
    };
    if g_rdm_atlas.id != 0 then sg_destroy_image(g_rdm_atlas);
    g_rdm_atlas = sg_make_image(*desc);
}

bake_sky_scale       : float = 1.0;
bake_sky_desaturation : float = 1.0;

world_to_sky_config :: (world: World) -> Tacoma.Sky_Config {
    sky : Tacoma.Sky_Config;
    sky.skyBase          = world.conf.skyBase;
    sky.skyTop           = world.conf.skyTop;
    sky.sunDisk          = world.conf.sunDisk;
    sky.horizonHalo      = world.conf.horizonHalo;
    sky.sunHalo          = world.conf.sunHalo;
    sky.sunLightColor    = world.conf.sunLightColor;
    sky.sunPosition      = world.conf.sunPosition;
    sky.sunIntensity     = world.conf.sunIntensity;
    sky.skyIntensity     = world.conf.skyIntensity * bake_sky_scale;
    sky.skyDesaturation  = bake_sky_desaturation;
    return sky;
}

// Build trile BLASes + world TLAS from a world, then initialize ctx.
tacoma_init_scene :: (world: World, include_water: bool) {
    trile_list          : [..]Tacoma.Trile_Data;  trile_list.allocator          = temp;
    world_triles        : [..]Tacoma.World_Trile; world_triles.allocator        = temp;
    trile_name_to_index : Table(string, s32);     trile_name_to_index.allocator = temp;

    for chunk: world.chunks {
        for group: chunk.groups {
            success, idx := table_find(*trile_name_to_index, group.trile_name);
            if !success {
                trile, trile_ok := get_trile(group.trile_name);
                if !trile_ok  continue;
                ttrile : Tacoma.Trile_Data;
                for x: 0..15  for y: 0..15  for z: 0..15 {
                    ttrile.trixels[x][y][z] = .{
                        trile.trixels[x][y][z].empty,
                        trile.trixels[x][y][z].material.color,
                        material_encode_to_float(trile.trixels[x][y][z].material)
                    };
                }
                gfx := get_trile_gfx(group.trile_name);
                ttrile.vertices    = gfx.vertices.data;
                ttrile.vertexCount = cast(s32)(gfx.vertices.count / 3);
                idx = cast(s32) trile_list.count;
                array_add(*trile_list, ttrile);
                table_set(*trile_name_to_index, group.trile_name, idx);
            }
            for inst: group.instances {
                wx, wy, wz := chunk_local_to_world(chunk.coord, inst.x, inst.y, inst.z);
                array_add(*world_triles, Tacoma.World_Trile.{idx,
                    Vector3.{cast(float) wx, cast(float) wy, cast(float) wz},
                    cast(s32) inst.orientation});
            }
        }
    }

    sky    : Tacoma.Sky_Config = world_to_sky_config(world);
    blases : Tacoma.Trile_Set  = .{trile_list.data,   cast(s32) trile_list.count};
    tlas   : Tacoma.World      = .{world_triles.data, cast(s32) world_triles.count};
    ctx = Tacoma.tacoma_init("./modules/Tacoma/");
    Tacoma.tacoma_load_scene(ctx, sky, blases, tlas, cast(s32) include_water);
}

tacoma_stop :: () {
    Tacoma.tacoma_destroy(ctx);
}

tacoma_handle_result :: (ptr: *float, w: s32, h: s32) {
    data := cast(*float) talloc(w*h*4*size_of(float));
    memcpy(data, ptr, w*h*4*4);
    for 0..(w*h) {
        color : Vector3;
        color.x = data[it * 4 + 0];
        color.y = data[it * 4 + 1];
        color.z = data[it * 4 + 2];

        data[it * 4 + 0] = color.x;
        data[it * 4 + 1] = color.y;
        data[it * 4 + 2] = color.z;

    }

    imgdata : sg_image_data;
    imgdata.subimage[0][0] = .{data, cast(u64) (w*h*4*4)};

    texdesc : sg_image_desc = .{
        render_target = false,
        width         = w,
        height        = h,
        pixel_format  = sg_pixel_format.RGBA32F,
        sample_count  = 1,
        data          = imgdata
    };

    if current_screenshot.valid {
        sg_destroy_image(current_screenshot.image);
    }

    current_screenshot = .{
        sg_make_image(*texdesc),
        w,
        h,
        true
    };
    Tacoma.tacoma_free_result(ptr);
}

gen_reference :: (w: s32, h: s32, eye: Vector3, target: Vector3, quality: s32, include_water: bool, world: World) {
    tacoma_init_scene(world, include_water);
    ptr := Tacoma.tacoma_render_reference(ctx, w, h, eye, target, 0.01, quality);
    tacoma_handle_result(ptr, w, h);
    tacoma_stop();
}

sh_bake_start :: (quality: s32 = 50, include_water: bool = false) {
    if sh_bake.active then return;
    curworld := get_current_world();
    if !curworld.valid { log_warn("sh_bake_start: no world loaded"); return; }

    world := *curworld.world;
    for _, key: world.chunks  array_add(*sh_bake.chunk_keys, key);

    if sh_bake.chunk_keys.count == 0 then return;

    tacoma_init_scene(world.*, include_water);
    sh_bake.active        = true;
    sh_bake.quality       = quality;
    sh_bake.include_water = include_water;
    sh_bake.current_chunk = 0;
} @Command

sh_bake_tick :: () {
    if !sh_bake.active then return;
    if sh_bake.current_chunk >= cast(s32) sh_bake.chunk_keys.count {
        sh_bake_finish();
        return;
    }

    curworld := get_current_world();
    if !curworld.valid { sh_bake_finish(); return; }

    n     :: SH_PROBE_N;
    tex_w :: SH_TEX_W;

    chunk_key := sh_bake.chunk_keys[sh_bake.current_chunk];
    chunk := table_find_pointer(*curworld.world.chunks, chunk_key);
    sh_bake.current_chunk += 1;
    if chunk == null then return;

    ox, oy, oz := chunk_local_to_world(chunk_key, 0, 0, 0);
    SH_PAD     :: 2.0;
    SH_SPACING :: (32.0 + 2.0 * SH_PAD) / n;
    ptr := Tacoma.tacoma_render_sh_chunk(ctx,
        cast(float) ox - SH_PAD, cast(float) oy - SH_PAD, cast(float) oz - SH_PAD,
        n, SH_SPACING, sh_bake.quality);

    tex_halfs :: tex_w * n * n * 4;
    packed : *u16 = cast(*u16) alloc(tex_halfs * size_of(u16));
    defer free(packed);

    src := ptr;
    for pz: 0..n-1  for py: 0..n-1  for px: 0..n-1 {
        probe_idx := px + py * n + pz * n * n;
        s := src + probe_idx * 12;
        for k: 0..2 {
            tex_idx := (pz * n + py) * tex_w + (px * 3 + k);
            d := packed + tex_idx * 4;
            for ch: 0..3 {
                (d + ch).* = f32_to_f16((s + k * 4 + ch).*);
            }
        }
    }

    tex_byte_size := cast(u64)(tex_halfs * size_of(u16));
    imgdata : sg_image_data;
    imgdata.subimage[0][0] = .{packed, tex_byte_size};
    sh_desc : sg_image_desc = .{
        width        = tex_w,
        height       = n * n,
        pixel_format = sg_pixel_format.RGBA16F,
        sample_count = 1,
        data         = imgdata,
    };

    if chunk.sh_valid  sg_destroy_image(chunk.sh_probe_grid);
    chunk.sh_probe_grid = sg_make_image(*sh_desc);
    chunk.sh_valid  = true;
    chunk.sh_dirty  = false;

    #if OS != .WASM {
        shgrid_save_to_disk(curworld.world.name, chunk_key, ptr, n);
    }

    Tacoma.tacoma_free_result(ptr);
    log_info("SH baked chunk % (%/%)", chunk_key, sh_bake.current_chunk, sh_bake.chunk_keys.count);
}

sh_bake_finish :: () {
    tacoma_stop();
    array_free(sh_bake.chunk_keys);
    sh_bake = .{};
    log_info("SH bake complete.");
}

shgrid_save_to_disk :: (world_name: string, chunk_key: Chunk_Key, data: *float, probe_n: s32) {
    #if OS != .WASM {
        file :: #import "File";
        path := shgrid_filename(world_name, chunk_key);

        builder : String_Builder;
        header := SH_Grid_File_Header.{
            magic   = SH_FILE_MAGIC,
            version = 2,
            probe_n = probe_n,
        };
        write_bytes(*builder, *header, size_of(SH_Grid_File_Header));
        total_values := cast(s64) probe_n * probe_n * probe_n * 12;
        halves := NewArray(total_values, u16,, temp);
        for i: 0..total_values-1  halves[i] = f32_to_f16(data[i]);
        write_bytes(*builder, halves.data, total_values * size_of(u16));
        file.write_entire_file(path, builder_to_string(*builder));
    }
}

rdm_save_global_atlas_to_disk :: (bake: *RDM_Global_Bake) {
    #if OS != .WASM {
        file :: #import "File";
        curworld := get_current_world();
        if !curworld.valid then return;
        path := rdm_global_atlas_filename(curworld.world.name);

        builder : String_Builder;
        header := RDM_File_Header.{
            magic  = RDM_FILE_MAGIC,
            width  = bake.width,
            height = bake.height,
        };
        write_bytes(*builder, *header, size_of(RDM_File_Header));
        // Convert RGBA32F → RGBA16F for the on-disk atlas.
        pixel_count := cast(s64) bake.width * cast(s64) bake.height * 4;
        halves := NewArray(pixel_count, u16,, temp);
        for i: 0..pixel_count - 1  halves[i] = f32_to_f16(bake.data[i]);
        write_bytes(*builder, halves.data, pixel_count * size_of(u16));
        file.write_entire_file(path, builder_to_string(*builder));
        log_info("Saved RDM global atlas: %", path);
    }
}

rdm_save_global_manifest_to_disk :: (world_name: string, entries: []Rdm_Atlas_Entry) {
    #if OS != .WASM {
        file :: #import "File";
        path := rdm_global_manifest_filename(world_name);
        s := Jaison.json_write_string(entries);
        file.write_entire_file(path, s);
        log_info("Saved RDM manifest: % (% entries)", path, entries.count);
    }
}


