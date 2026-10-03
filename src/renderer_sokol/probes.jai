// Each chunk's probes are a brick in one 3D atlas, found through an index
// texture with one texel per chunk. The trile shader filters them itself.

PROBE_BRICKS_PER_COLUMN :: 16;   // bricks stack along y, then the next column along z

probes_init :: () {
    zero : [8]u8;
    probes.empty_index = make_volume(1, 1, 1, .RGBA8,   .{4, zero.data});
    probes.empty_atlas = make_volume(1, 1, 1, .RGBA16F, .{8, zero.data});
    probes.index = probes.empty_index;
    probes.atlas = probes.empty_atlas;
}

renderer_probes_set :: (key: Chunk_Key, data: []Probe) {
    brick := table_find_pointer(*probes.bricks, key);
    if brick  array_free(brick.*);
    else      brick = table_set(*probes.bricks, key, .[]);
    brick.* = array_copy(data);
    probes.dirty = true;
}

renderer_probes_clear :: () {
    for probes.bricks  array_free(it);
    table_reset(*probes.bricks);
    probes.dirty = true;
}

probes_upload :: () {
    if !probes.dirty  return;
    probes.dirty = false;
    if probes.index.id != probes.empty_index.id  sg_destroy_image(probes.index);
    if probes.atlas.id != probes.empty_atlas.id  sg_destroy_image(probes.atlas);
    probes.index = probes.empty_index;
    probes.atlas = probes.empty_atlas;
    probes.min   = .[0, 0, 0, 0];
    probes.size  = .[0, 0, 0, 0];
    count := probes.bricks.count;
    if !count  return;

    lo := Chunk_Key.{S32_MAX, S32_MAX, S32_MAX};
    hi := Chunk_Key.{S32_MIN, S32_MIN, S32_MIN};
    for probes.bricks {
        lo = .{min(lo.x, it_index.x), min(lo.y, it_index.y), min(lo.z, it_index.z)};
        hi = .{max(hi.x, it_index.x), max(hi.y, it_index.y), max(hi.z, it_index.z)};
    }
    size := s32.[hi.x - lo.x + 1, hi.y - lo.y + 1, hi.z - lo.z + 1];
    index := NewArray(size[0] * size[1] * size[2] * 4, u8,, temp);

    N :: CHUNK_SIZE;
    columns := min(count, PROBE_BRICKS_PER_COLUMN);
    layers  := (count + PROBE_BRICKS_PER_COLUMN - 1) / PROBE_BRICKS_PER_COLUMN;
    atlas_w, atlas_h, atlas_d := N * 3, N * columns, N * layers;
    atlas := NewArray(atlas_w * atlas_h * atlas_d * 4, u16,, temp);

    brick_index := 0;
    for brick, key: probes.bricks {
        number := brick_index + 1;
        i := ((key.z - lo.z) * size[1] + (key.y - lo.y)) * size[0] + (key.x - lo.x);
        index[i * 4 + 0] = xx (number & 0xFF);
        index[i * 4 + 1] = xx (number >> 8);

        y0 := (brick_index % PROBE_BRICKS_PER_COLUMN) * N;
        z0 := (brick_index / PROBE_BRICKS_PER_COLUMN) * N;
        for z: 0..N-1  for y: 0..N-1  for x: 0..N-1 {
            probe := *brick[x + y * N + z * N * N];
            row := ((z0 + z) * atlas_h + (y0 + y)) * atlas_w + x * 3;
            memcpy(*atlas[row * 4], probe.sh.data, size_of(Probe));
        }
        brick_index += 1;
    }

    probes.index = make_volume(size[0], size[1], size[2], .RGBA8, index);
    probes.atlas = make_volume(xx atlas_w, xx atlas_h, xx atlas_d, .RGBA16F, .{atlas.count * size_of(u16), xx atlas.data});
    probes.min   = .[xx lo.x, xx lo.y, xx lo.z, 1];
    probes.size  = .[xx size[0], xx size[1], xx size[2], 0];
}

probes_set_params :: (params: *Trile_Fs_Params) {
    params.probe_min  = probes.min;
    params.probe_size = probes.size;
}

probes_bind :: (bind: *sg_bindings) {
    bind.images[IMG_probe_index] = probes.index;
    bind.images[IMG_probe_atlas] = probes.atlas;
    bind.samplers[SMP_probe_smp] = samplers.nearest_clamp;
}

#scope_file

probes : struct {
    bricks : Table(Chunk_Key, []Probe, chunk_key_hash, chunk_key_compare);
    dirty  : bool;

    index       : sg_image;
    atlas       : sg_image;
    empty_index : sg_image;
    empty_atlas : sg_image;
    min         : [4]float;   // first chunk in the index; w = 1 when there are probes
    size        : [4]float;   // index size in chunks
}

make_volume :: (width: s32, height: s32, depth: s32, format: sg_pixel_format, data: []u8) -> sg_image {
    desc := sg_image_desc.{ type = ._3D, width = width, height = height, num_slices = depth, pixel_format = format };
    desc.data.subimage[0][0] = .{ data.data, xx data.count };
    return sg_make_image(*desc);
}
