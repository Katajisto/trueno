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

RDM_Atlas_Entry :: struct {
    world_pos:  Vector3;
    roughness:  s32;
    x, y:       s32;      // position in atlas (pixels)
    w, h:       s32;      // size of this RDM
}

// Per-chunk atlas bake state (CPU-side, used during baking only).
RDM_Chunk_Bake :: struct {
    data:        *float;              // CPU atlas buffer (RGBA32F)
    width:       s32;
    height:      s32;
    cursor_x:    s32;
    cursor_y:    s32;
    row_height:  s32;
    entries:     [..]RDM_Atlas_Entry;
}

RDM_ATLAS_SIZE :: 4096;
RDM_LOOKUP_SIZE :: 512; // 512x512 = 32*32*32*8 = 262144 texels

rdm_chunk_bakes : Table(Chunk_Key, RDM_Chunk_Bake, chunk_key_hash, chunk_key_compare);

ctx : *Tacoma.Tacoma_Context;

// --- Chunk RDM bake queue ---

// A single RDM render job: one world_trile at one roughness level.
RDM_Bake_Job :: struct {
    world_trile_index: s32;
    roughness:         s32;
    world_pos:         Vector3;
}

RDM_Bake_State :: struct {
    active           : bool = false;
    quality          : s32 = 100;
    jobs             : [..]RDM_Bake_Job;
    current_job      : s32 = 0;
}

rdm_bake : RDM_Bake_State;

// Get the set of roughness values present in a trile's trixels.
// Always includes 7 (used for diffuse light). Returns a bitmask.
get_trile_roughness_set :: (trile_name: string) -> u8 {
    trile := get_trile(trile_name);
    mask : u8 = 1 << 7; // Always include roughness 7.
    for x: 0..15 {
        for y: 0..15 {
            for z: 0..15 {
                if !trile.trixels[x][y][z].empty {
                    mask |= cast(u8)(1 << trile.trixels[x][y][z].material.roughness);
                }
            }
        }
    }
    return mask;
}

// Predicted pixel dimensions of a single RDM entry at a given roughness level.
// roughness 0 → 512×768, roughness 1 → 256×384, ..., roughness 7 → 4×6.
rdm_entry_predicted_size :: (roughness: s32) -> (w: s32, h: s32) {
    size : s32 = cast(s32)(1 << (8 - roughness));
    return 2 * size, 3 * size;
}

// Simulate shelf-pack of jobs into a canvas of given width; return total height used.
rdm_simulate_pack_height :: (jobs: []RDM_Bake_Job, canvas_w: s32) -> s32 {
    cx : s32 = 0;
    cy : s32 = 0;
    rh : s32 = 0;
    for job: jobs {
        w, h := rdm_entry_predicted_size(job.roughness);
        if cx + w > canvas_w { cy += rh; cx = 0; rh = 0; }
        cx += w;
        if h > rh  rh = h;
    }
    cy += rh;
    return cy;
}

// Simulate shelf-packing for a chunk's sorted job list and return minimum
// power-of-2 atlas dimensions, capped at RDM_ATLAS_SIZE.
rdm_calc_chunk_atlas_size :: (jobs: []RDM_Bake_Job) -> (s32, s32) {
    if jobs.count == 0  return 16, 16;

    // Estimate canvas width from sqrt(total pixel area).
    total_area : s64 = 0;
    for job: jobs {
        w, h := rdm_entry_predicted_size(job.roughness);
        total_area += cast(s64) w * cast(s64) h;
    }
    target_w : s32 = 16;
    sqrt_area := cast(s32) sqrt(cast(float) total_area) + 1;
    while target_w < sqrt_area  target_w *= 2;

    // Widen until the packed height fits within the width (roughly square).
    while target_w < RDM_ATLAS_SIZE {
        if rdm_simulate_pack_height(jobs, target_w) <= target_w  break;
        target_w *= 2;
    }

    // Round height up to next power of 2.
    final_height := rdm_simulate_pack_height(jobs, target_w);
    target_h : s32 = 16;
    while target_h < final_height  target_h *= 2;

    if target_w > RDM_ATLAS_SIZE  target_w = RDM_ATLAS_SIZE;
    if target_h > RDM_ATLAS_SIZE  target_h = RDM_ATLAS_SIZE;
    return target_w, target_h;
}

// Build the Tacoma scene from the world, and emit bake jobs for selected chunks.
// If chunk_keys is null, all chunks are queued.
rdm_bake_start :: (world: World, quality: s32, include_water: bool, chunk_keys: []Chunk_Key = .[]) {
    if rdm_bake.active then return;

    trile_list : [..]Tacoma.Trile_Data;
    trile_list.allocator = temp;
    world_triles : [..]Tacoma.World_Trile;
    world_triles.allocator = temp;

    trile_name_to_index: Table(string, s32);
    trile_name_to_index.allocator = temp;

    // Per world_trile: which roughnesses to bake.
    world_trile_roughnesses : [..]u8;
    world_trile_roughnesses.allocator = temp;

    // Cache roughness sets per trile type.
    roughness_cache: Table(string, u8);
    roughness_cache.allocator = temp;

    bake_all := chunk_keys.count == 0;

    // Build a set of chunk keys to bake if specific ones were requested.
    chunk_key_set: Table(Chunk_Key, bool, chunk_key_hash, chunk_key_compare);
    chunk_key_set.allocator = temp;
    if !bake_all {
        for key: chunk_keys {
            table_set(*chunk_key_set, key, true);
        }
    }

    for chunk: world.chunks {
        should_bake := bake_all || table_contains(*chunk_key_set, chunk.coord);
        for group: chunk.groups {
            success, idx := table_find(*trile_name_to_index, group.trile_name);
            if !success {
                trile := get_trile(group.trile_name);
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

            // Get roughness set for this trile type (cached).
            roughness_mask : u8;
            found_r, cached_mask := table_find(*roughness_cache, group.trile_name);
            if found_r {
                roughness_mask = cached_mask;
            } else {
                roughness_mask = get_trile_roughness_set(group.trile_name);
                table_set(*roughness_cache, group.trile_name, roughness_mask);
            }

            for inst: group.instances {
                world_trile_idx := cast(s32) world_triles.count;
                wx, wy, wz := chunk_local_to_world(chunk.coord, inst.x, inst.y, inst.z);
                wpos := Vector3.{cast(float) wx, cast(float) wy, cast(float) wz};
                array_add(*world_triles, Tacoma.World_Trile.{idx, wpos});
                array_add(*world_trile_roughnesses, roughness_mask);

                if should_bake {
                    // Emit one job per roughness level present.
                    for r: 0..7 {
                        if roughness_mask & cast(u8)(1 << r) {
                            array_add(*rdm_bake.jobs, .{world_trile_index = world_trile_idx, roughness = cast(s32) r, world_pos = wpos});
                        }
                    }
                }
            }
        }
    }

    sky : Tacoma.Sky_Config;
    sky.skyBase = world.conf.skyBase;
    sky.skyTop = world.conf.skyTop;
    sky.sunDisk = world.conf.sunDisk;
    sky.horizonHalo = world.conf.horizonHalo;
    sky.sunHalo = world.conf.sunHalo;
    sky.sunLightColor = world.conf.sunLightColor;
    sky.sunPosition = world.conf.sunPosition;
    sky.sunIntensity = world.conf.sunIntensity;
    sky.skyIntensity = world.conf.skyIntensity;

    blases : Tacoma.Trile_Set = .{trile_list.data, cast(s32)trile_list.count};
    tlas : Tacoma.World = .{world_triles.data, cast(s32)world_triles.count};

    ctx = Tacoma.tacoma_init("./modules/Tacoma/");
    Tacoma.tacoma_load_scene(ctx, sky, blases, tlas, cast(s32) include_water);

    // Sort jobs by roughness ascending (lowest roughness = biggest images first).
    // Simple insertion sort, N is small.
    if rdm_bake.jobs.count > 1 {
        for i: 1..cast(s32)(rdm_bake.jobs.count - 1) {
            key := rdm_bake.jobs[i];
            j := i - 1;
            while j >= 0 && rdm_bake.jobs[j].roughness > key.roughness {
                rdm_bake.jobs[j + 1] = rdm_bake.jobs[j];
                j -= 1;
            }
            rdm_bake.jobs[j + 1] = key;
        }
    }

    // Clean up any previous per-chunk bake data.
    rdm_cleanup_chunk_bakes();

    // Clean up any previous RDM results stored in chunks.
    curworld := get_current_world();
    for *chunk: curworld.world.chunks {
        if chunk.rdm_valid {
            sg_destroy_image(chunk.rdm_atlas);
            sg_destroy_image(chunk.rdm_lookup);
            chunk.rdm_valid = false;
        }
    }

    // Pre-allocate per-chunk atlas CPU buffers with optimal (minimum) sizes.
    {
        // Collect unique chunk keys.
        unique_chunk_keys : [..]Chunk_Key;
        unique_chunk_keys.allocator = temp;
        for job: rdm_bake.jobs {
            ck := world_to_chunk_coord(cast(s32) job.world_pos.x, cast(s32) job.world_pos.y, cast(s32) job.world_pos.z);
            already := false;
            for unique_chunk_keys { if it == ck { already = true; break; } }
            if !already  array_add(*unique_chunk_keys, ck);
        }

        for chunk_key: unique_chunk_keys {
            // Collect this chunk's jobs (already sorted by roughness ascending).
            this_jobs : [..]RDM_Bake_Job;
            this_jobs.allocator = temp;
            for job: rdm_bake.jobs {
                ck := world_to_chunk_coord(cast(s32) job.world_pos.x, cast(s32) job.world_pos.y, cast(s32) job.world_pos.z);
                if ck == chunk_key  array_add(*this_jobs, job);
            }

            atlas_w, atlas_h := rdm_calc_chunk_atlas_size(this_jobs);
            log_info("RDM atlas for chunk %: %x% (%.1f MB, was % MB)",
                chunk_key, atlas_w, atlas_h,
                cast(float)(cast(s64) atlas_w * atlas_h * 4 * size_of(float)) / (1024.0 * 1024.0),
                RDM_ATLAS_SIZE * RDM_ATLAS_SIZE * 4 * size_of(float) / (1024 * 1024));

            atlas_bytes := cast(s64) atlas_w * cast(s64) atlas_h * 4 * size_of(float);
            bake : RDM_Chunk_Bake;
            bake.width  = atlas_w;
            bake.height = atlas_h;
            bake.data   = cast(*float) alloc(atlas_bytes);
            memset(bake.data, 0, atlas_bytes);
            table_set(*rdm_chunk_bakes, chunk_key, bake);
        }
    }

    rdm_bake.active = true;
    rdm_bake.quality = quality;

    if rdm_bake.jobs.count == 0 {
        rdm_bake_finish();
    }
}

// Queue all chunks for RDM baking.
rdm_bake_all_chunks :: (world: World, quality: s32, include_water: bool) {
    rdm_bake_start(world, quality, include_water);
}

// Queue specific chunks for RDM baking.
rdm_bake_chunks :: (chunk_keys: []Chunk_Key, world: World, quality: s32, include_water: bool) {
    rdm_bake_start(world, quality, include_water, chunk_keys);
}

// Called once per frame to process at most one RDM.
rdm_bake_tick :: () {
    if !rdm_bake.active then return;
    if rdm_bake.current_job >= cast(s32) rdm_bake.jobs.count {
        rdm_bake_finish();
        return;
    }

    job := rdm_bake.jobs[rdm_bake.current_job];

    w, h : s32;
    ptr := Tacoma.tacoma_render_rdm(ctx, job.world_trile_index, job.roughness, rdm_bake.quality, *w, *h);

    // Find this job's per-chunk bake state.
    chunk_key := world_to_chunk_coord(cast(s32) job.world_pos.x, cast(s32) job.world_pos.y, cast(s32) job.world_pos.z);
    bake := table_find_pointer(*rdm_chunk_bakes, chunk_key);

    if bake != null {
        // Shelf-pack this RDM into the chunk's atlas.
        if bake.cursor_x + w > bake.width {
            bake.cursor_y += bake.row_height;
            bake.cursor_x = 0;
            bake.row_height = 0;
        }

        ax := bake.cursor_x;
        ay := bake.cursor_y;

        if ay + h <= bake.height {
            // Copy pixels row-by-row into the chunk's atlas CPU buffer.
            src := cast(*u8) ptr;
            row_bytes := cast(s64) w * 4 * size_of(float);
            for row: 0..h-1 {
                dst_offset := (cast(s64)(ay + row) * cast(s64) bake.width + cast(s64) ax) * 4 * size_of(float);
                src_offset := cast(s64) row * row_bytes;
                memcpy(cast(*u8) bake.data + dst_offset, src + src_offset, row_bytes);
            }

            entry : RDM_Atlas_Entry;
            entry.world_pos = job.world_pos;
            entry.roughness = job.roughness;
            entry.x = ax;
            entry.y = ay;
            entry.w = w;
            entry.h = h;
            array_add(*bake.entries, entry);
        } else {
            log_warn("RDM atlas overflow for chunk %, skipping (pos=%, roughness=%)", chunk_key, job.world_pos, job.roughness);
        }

        bake.cursor_x += w;
        if h > bake.row_height then bake.row_height = h;
    }

    // Still update the preview screenshot.
    tacoma_handle_result(ptr, w, h);

    rdm_bake.current_job += 1;
}

rdm_bake_finish :: () {
    if ctx != null then tacoma_stop();

    curworld := get_current_world();
    total_entries : s64 = 0;
    chunk_count : s64 = 0;

    // Collect unique chunk keys from jobs.
    bake_chunk_keys : [..]Chunk_Key;
    bake_chunk_keys.allocator = temp;
    for job: rdm_bake.jobs {
        ck := world_to_chunk_coord(cast(s32) job.world_pos.x, cast(s32) job.world_pos.y, cast(s32) job.world_pos.z);
        already := false;
        for bake_chunk_keys { if it == ck { already = true; break; } }
        if !already then array_add(*bake_chunk_keys, ck);
    }

    lookup_texels :: RDM_LOOKUP_SIZE * RDM_LOOKUP_SIZE;
    lookup_bytes  :: lookup_texels * 4 * size_of(float);

    for chunk_key: bake_chunk_keys {
        bake := table_find_pointer(*rdm_chunk_bakes, chunk_key);
        if bake == null || bake.entries.count == 0 then continue;

        // a) Upload per-chunk atlas to GPU.
        atlas_imgdata : sg_image_data;
        atlas_byte_size := cast(u64) bake.width * cast(u64) bake.height * 4 * size_of(float);
        atlas_imgdata.subimage[0][0] = .{bake.data, atlas_byte_size};

        atlas_desc : sg_image_desc = .{
            render_target = false,
            width         = bake.width,
            height        = bake.height,
            pixel_format  = sg_pixel_format.RGBA32F,
            sample_count  = 1,
            data          = atlas_imgdata
        };
        atlas_image := sg_make_image(*atlas_desc);

        // b) Generate lookup texture (512x512 RGBA32F).
        lookup_data := cast(*float) alloc(lookup_bytes);
        memset(lookup_data, 0, lookup_bytes);

        atlas_w := cast(float) bake.width;
        atlas_h := cast(float) bake.height;

        for entry: bake.entries {
            lx, ly, lz := world_to_local(cast(s32) entry.world_pos.x, cast(s32) entry.world_pos.y, cast(s32) entry.world_pos.z);
            index := cast(s32) lx + cast(s32) ly * 32 + cast(s32) lz * 32 * 32 + entry.roughness * 32 * 32 * 32;
            tx := index % RDM_LOOKUP_SIZE;
            ty := index / RDM_LOOKUP_SIZE;
            pixel_offset := (ty * RDM_LOOKUP_SIZE + tx) * 4;
            lookup_data[pixel_offset + 0] = cast(float) entry.x / atlas_w;
            lookup_data[pixel_offset + 1] = cast(float) entry.y / atlas_h;
            lookup_data[pixel_offset + 2] = cast(float) entry.w / atlas_w;
            lookup_data[pixel_offset + 3] = cast(float) entry.h / atlas_h;
        }

        lookup_imgdata : sg_image_data;
        lookup_imgdata.subimage[0][0] = .{lookup_data, lookup_bytes};

        lookup_desc : sg_image_desc = .{
            render_target = false,
            width         = RDM_LOOKUP_SIZE,
            height        = RDM_LOOKUP_SIZE,
            pixel_format  = sg_pixel_format.RGBA32F,
            sample_count  = 1,
            data          = lookup_imgdata
        };
        lookup_image := sg_make_image(*lookup_desc);
        free(lookup_data);

        // c) Store in Chunk.
        chunk := table_find_pointer(*curworld.world.chunks, chunk_key);
        if chunk != null {
            if chunk.rdm_valid {
                sg_destroy_image(chunk.rdm_atlas);
                sg_destroy_image(chunk.rdm_lookup);
            }
            chunk.rdm_atlas = atlas_image;
            chunk.rdm_lookup = lookup_image;
            chunk.rdm_valid = true;
        }

        total_entries += cast(s64) bake.entries.count;
        chunk_count += 1;
    }

    log_info("RDM bake complete: % chunks, % total entries", chunk_count, total_entries);

    // Save baked RDM data to disk.
    rdm_save_all_chunks_to_disk();

    // Clean up CPU bake data.
    rdm_cleanup_chunk_bakes();

    array_free(rdm_bake.jobs);
    rdm_bake = .{};
}

rdm_cleanup_chunk_bakes :: () {
    for *bake: rdm_chunk_bakes {
        if bake.data != null then free(bake.data);
        array_free(bake.entries);
    }
    deinit(*rdm_chunk_bakes);
    rdm_chunk_bakes = .{};
}

tacoma_start :: (world: World, include_water: bool) {
    // Trile BLASes.
    trile_list : [..]Tacoma.Trile_Data;
    trile_list.allocator = temp;
    // BLAS instances to create TLAS.
    world_triles : [..]Tacoma.World_Trile;
    world_triles.allocator = temp;

    // Build trile type list and gather world positions from chunks.
    trile_name_to_index: Table(string, s32);
    trile_name_to_index.allocator = temp;

    for chunk: world.chunks {
        for group: chunk.groups {
            // Ensure this trile type is in the list.
            success, idx := table_find(*trile_name_to_index, group.trile_name);
            if !success {
                trile := get_trile(group.trile_name);
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
                wx, wy, wz := chunk_local_to_world(chunk.coord, inst.x, inst.y, inst.z);
                array_add(*world_triles, Tacoma.World_Trile.{idx, Vector3.{cast(float) wx, cast(float) wy, cast(float) wz}});
            }
        }
    }

    sky : Tacoma.Sky_Config;

    sky.skyBase = world.conf.skyBase;
    sky.skyTop = world.conf.skyTop;
    sky.sunDisk = world.conf.sunDisk;
    sky.horizonHalo = world.conf.horizonHalo;
    sky.sunHalo = world.conf.sunHalo;
    sky.sunLightColor = world.conf.sunLightColor;
    sky.sunPosition = world.conf.sunPosition;
    sky.sunIntensity = world.conf.sunIntensity;
    sky.skyIntensity = world.conf.skyIntensity;

    blases : Tacoma.Trile_Set = .{trile_list.data, cast(s32)trile_list.count};
    for world_triles {
        log_debug("World trile %", it);
    }
    tlas : Tacoma.World = .{world_triles.data, cast(s32)world_triles.count};

    ctx = Tacoma.tacoma_init("./modules/Tacoma/");
    log_debug("CTX: %", ctx);

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
    tacoma_start(world, include_water);
    ptr := Tacoma.tacoma_render_reference(ctx, w, h, eye, target, 0.01, quality);
    tacoma_handle_result(ptr, w, h);
    tacoma_stop();
}

gen_rdm :: (quality: s32, include_water: bool, world: World) {
    tacoma_start(world, include_water);
    w, h : s32;
    ptr := Tacoma.tacoma_render_rdm(ctx, 0, 0, quality, *w, *h);
    tacoma_handle_result(ptr, w, h);
    tacoma_stop();
}

// --- RDM disk persistence ---
// (RDM_File_Header, RDM_FILE_MAGIC, rdm_chunk_filename, rdm_load_from_disk
//  are defined in rdm_disk.jai which is always loaded on non-WASM builds.)

rdm_save_image_to_file :: (path: string, data: *float, width: s32, height: s32) {
    #if OS != .WASM {
        file :: #import "File";
        builder: String_Builder;
        header := RDM_File_Header.{
            magic = RDM_FILE_MAGIC,
            width = width,
            height = height,
        };
        write_bytes(*builder, *header, size_of(RDM_File_Header));
        pixel_bytes := cast(s64) width * cast(s64) height * 4 * size_of(float);
        write_bytes(*builder, data, pixel_bytes);
        file.write_entire_file(path, builder_to_string(*builder));
    }
}

rdm_save_all_chunks_to_disk :: () {
    #if OS != .WASM {
        curworld := get_current_world();
        if !curworld.valid then return;
        world_name := curworld.world.name;

        for *bake, chunk_key: rdm_chunk_bakes {
            if bake.entries.count == 0 then continue;

            // Save atlas.
            atlas_path := rdm_chunk_filename(world_name, chunk_key, "rdm_atlas");
            rdm_save_image_to_file(atlas_path, bake.data, bake.width, bake.height);

            // Regenerate and save lookup.
            lookup_texels :: RDM_LOOKUP_SIZE * RDM_LOOKUP_SIZE;
            lookup_floats :: lookup_texels * 4;
            lookup_data : [lookup_floats]float;
            memset(lookup_data.data, 0, size_of(type_of(lookup_data)));

            atlas_w := cast(float) bake.width;
            atlas_h := cast(float) bake.height;
            for entry: bake.entries {
                lx, ly, lz := world_to_local(cast(s32) entry.world_pos.x, cast(s32) entry.world_pos.y, cast(s32) entry.world_pos.z);
                index := cast(s32) lx + cast(s32) ly * 32 + cast(s32) lz * 32 * 32 + entry.roughness * 32 * 32 * 32;
                tx := index % RDM_LOOKUP_SIZE;
                ty := index / RDM_LOOKUP_SIZE;
                pixel_offset := (ty * RDM_LOOKUP_SIZE + tx) * 4;
                lookup_data[pixel_offset + 0] = cast(float) entry.x / atlas_w;
                lookup_data[pixel_offset + 1] = cast(float) entry.y / atlas_h;
                lookup_data[pixel_offset + 2] = cast(float) entry.w / atlas_w;
                lookup_data[pixel_offset + 3] = cast(float) entry.h / atlas_h;
            }

            lookup_path := rdm_chunk_filename(world_name, chunk_key, "rdm_lookup");
            rdm_save_image_to_file(lookup_path, lookup_data.data, RDM_LOOKUP_SIZE, RDM_LOOKUP_SIZE);

            log_info("Saved RDM data for chunk % to disk", chunk_key);
        }
    }
}


