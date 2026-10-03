#run {
    #load "../meta/ascii.jai";
    print("%\n", ascii_tacoma);
}

Tacoma :: #import "Tacoma";

ctx : *Tacoma.Tacoma_Context;

tacoma_preview : struct {
    texture : Texture;
    width   : s32;
    height  : s32;
}

// Light given off by a fully emissive swatch, relative to full sun on a white face.
bake_emissive_light : float = 10.0;

// Probes where more of the rays than this hit the back of a face are inside geometry.
PROBE_INSIDE_BACKFACES :: 0.25;

Probe_Bake :: struct {
    active     : bool;
    quality    : s32;
    world_name : string;
    keys       : [..]Chunk_Key;
    results    : [..]*float;   // from Tacoma, one per baked key
}

probe_bake : Probe_Bake;

bake_probes :: (quality: s32 = 100) {
    if probe_bake.active  return;
    curworld := get_current_world();
    if !curworld.valid { log_warn("bake_probes: no world loaded"); return; }

    for _, key: curworld.world.chunks  array_add(*probe_bake.keys, key);
    if !probe_bake.keys.count  return;

    tacoma_init_scene(*curworld.world);
    probe_bake.active     = true;
    probe_bake.quality    = quality;
    probe_bake.world_name = copy_string(curworld.world.name);
} @Command

// Bakes one chunk per call.
probe_bake_tick :: () {
    if !probe_bake.active  return;
    curworld := get_current_world();
    if !curworld.valid || curworld.world.name != probe_bake.world_name {
        log_warn("Probe bake cancelled: the world changed");
        probe_bake_end();
        return;
    }
    if probe_bake.results.count == probe_bake.keys.count {
        probe_bake_finish();
        return;
    }

    key := probe_bake.keys[probe_bake.results.count];
    x, y, z := chunk_local_to_world(key, 0, 0, 0);
    data := Tacoma.tacoma_render_sh_chunk(ctx, xx x, xx y, xx z, CHUNK_SIZE, 1.0, probe_bake.quality);
    array_add(*probe_bake.results, data);
    log_info("Baked probes for chunk % (%/%)", key, probe_bake.results.count, probe_bake.keys.count);
}

gen_reference :: (w: s32, h: s32, eye: Vector3, target: Vector3, quality: s32, world: *World) {
    tacoma_init_scene(world);
    data := Tacoma.tacoma_render_reference(ctx, w, h, eye, target, 0.01, quality);
    tacoma_stop();

    pixels := NewArray(w * h * 4, u8,, temp);
    for i: 0..w * h - 1 {
        for c: 0..2  pixels[i * 4 + c] = xx (clamp(data[i * 4 + c], 0, 1) * 255 + 0.5);
        pixels[i * 4 + 3] = 255;
    }
    Tacoma.tacoma_free_result(data);

    if tacoma_preview.texture.id  texture_destroy(tacoma_preview.texture);
    tacoma_preview.texture = texture_create(w, h, pixels);
    tacoma_preview.width   = w;
    tacoma_preview.height  = h;
}

#scope_file

tacoma_init_scene :: (world: *World) {
    trile_list          : [..]Tacoma.Trile_Data;  trile_list.allocator          = temp;
    world_triles        : [..]Tacoma.World_Trile; world_triles.allocator        = temp;
    trile_name_to_index : Table(string, s32);     trile_name_to_index.allocator = temp;

    for chunk: world.chunks {
        for group: chunk.groups {
            success, idx := table_find(*trile_name_to_index, group.trile_name);
            if !success {
                trile, trile_ok := get_trile(group.trile_name);
                if !trile_ok  continue;
                vertices, indices := mesh_trile(trile);
                positions := NewArray(indices.count * 3, float,, temp);
                for indices  for c: 0..2  positions[it_index * 3 + c] = vertices[it].position.component[c];

                ttrile : Tacoma.Trile_Data;
                ttrile.trixels     = trile.trixels;
                ttrile.vertices    = positions.data;
                ttrile.vertexCount = xx indices.count;
                idx = cast(s32) trile_list.count;
                array_add(*trile_list, ttrile);
                table_set(*trile_name_to_index, group.trile_name, idx);
            }
            for inst: group.instances {
                wx, wy, wz := chunk_local_to_world(chunk.coord, inst.x, inst.y, inst.z);
                array_add(*world_triles, Tacoma.World_Trile.{idx, .{xx wx, xx wy, xx wz}, xx inst.orientation});
            }
        }
    }

    swatches : [Tacoma.SWATCH_COUNT]Tacoma.Swatch;
    for g_swatches {
        if !it.used  continue;
        color := swatch_color(xx it_index);
        emission := color * (min(cast(int) it.emittance, 127) / 127.0) * bake_emissive_light;
        swatches[it_index] = .{color, emission, xx it.glass};
    }

    env := world_environment(world);
    sky : Tacoma.Sky_Config;
    sky.skyBase       = env.sky_base;
    sky.skyTop        = env.sky_top;
    sky.sunDisk       = env.sun_disk;
    sky.horizonHalo   = env.horizon_halo;
    sky.sunHalo       = env.sun_halo;
    sky.sunLightColor = env.sun_color;
    sky.sunPosition   = env.sun_direction;
    sky.sunIntensity  = 1;
    sky.skyIntensity  = ifx env.sky then env.sky_intensity else 0;

    blases : Tacoma.Trile_Set = .{trile_list.data,   xx trile_list.count};
    tlas   : Tacoma.World     = .{world_triles.data, xx world_triles.count};
    ctx = Tacoma.tacoma_init("./modules/Tacoma/");
    Tacoma.tacoma_load_scene(ctx, sky, swatches.data, blases, tlas, xx env.water);
}

tacoma_stop :: () {
    Tacoma.tacoma_destroy(ctx);
    ctx = null;
}

probe_bake_finish :: () {
    tacoma_stop();

    chunks := probes_from_bake(probe_bake.keys, probe_bake.results);
    for chunks  world_set_chunk_probes(it.key, it.probes);

    file :: #import "File";
    path := tprint("%/worlds/%/probes.bin", GAME_RESOURCES_DIR, probe_bake.world_name);
    if file.write_entire_file(path, save_probes(chunks))  log_info("Probe bake complete, saved %", path);
    else                                                  log_error("Probe bake complete, but writing % failed", path);

    for chunks  array_free(it.probes);
    probe_bake_end();
}

probe_bake_end :: () {
    if ctx  tacoma_stop();
    for probe_bake.results  Tacoma.tacoma_free_result(it);
    array_free(probe_bake.results);
    array_free(probe_bake.keys);
    free(probe_bake.world_name);
    probe_bake = .{};
}

// Marks probes inside geometry, and evens out bake noise by averaging each probe
// with its face neighbours, across chunk borders. Probes inside geometry take no part.
probes_from_bake :: (keys: []Chunk_Key, results: []*float) -> []Probe_Chunk {
    N :: CHUNK_SIZE;
    baked : Table(Chunk_Key, *float, chunk_key_hash, chunk_key_compare);
    baked.allocator = temp;
    for keys  table_set(*baked, it, results[it_index]);

    Baked :: type_of(baked);
    baked_probe :: (baked: *Baked, x: s32, y: s32, z: s32) -> *float {
        found, data := table_find(baked, world_to_chunk_coord(x, y, z));
        if !found  return null;
        lx, ly, lz := world_to_local(x, y, z);
        p := data + (cast(s64) lx + cast(s64) ly * N + cast(s64) lz * N * N) * Tacoma.PROBE_FLOATS;
        if p[12] > PROBE_INSIDE_BACKFACES  return null;
        return p;
    }

    NEIGHBOURS :: s32.[1, 0, 0,  -1, 0, 0,  0, 1, 0,  0, -1, 0,  0, 0, 1,  0, 0, -1];

    chunks := NewArray(keys.count, Probe_Chunk,, temp);
    for key, chunk_index: keys {
        probes := NewArray(PROBES_PER_CHUNK, Probe);
        for z: 0..N-1  for y: 0..N-1  for x: 0..N-1 {
            probe := *probes[x + y * N + z * N * N];
            wx, wy, wz := chunk_local_to_world(key, xx x, xx y, xx z);
            centre := baked_probe(*baked, wx, wy, wz);
            if !centre {
                probe.sh[0] = half_from_float(-1);
                continue;
            }
            sum : [12]float;
            for 0..11  sum[it] = centre[it];
            count := 1;
            for n: 0..5 {
                other := baked_probe(*baked, wx + NEIGHBOURS[n * 3], wy + NEIGHBOURS[n * 3 + 1], wz + NEIGHBOURS[n * 3 + 2]);
                if !other  continue;
                for 0..11  sum[it] += other[it];
                count += 1;
            }
            for 0..11  probe.sh[it] = half_from_float(sum[it] / count);
        }
        chunks[chunk_index] = .{key, probes};
    }
    return chunks;
}

half_from_float :: (f: float) -> u16 {
    bits     := (cast(*u32) *f).*;
    sign     := cast(u16) ((bits >> 16) & 0x8000);
    exponent := cast(s32) ((bits >> 23) & 0xFF) - 127 + 15;
    mantissa := bits & 0x7FFFFF;
    if exponent <= 0   return sign;
    if exponent >= 31  return sign | 0x7BFF;
    half := sign | cast(u16) (exponent << 10) | cast(u16) (mantissa >> 13);
    if mantissa & 0x1000  half += 1;
    return half;
}

