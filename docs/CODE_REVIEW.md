# Trueno Engine — Code Review

Overall this is a solid, well-structured engine. The architecture is clean, the compile-time
metaprogramming is used thoughtfully, and the explicit resource lifetime management is a real
strength. Below are the issues found, ordered from most critical downward.

---

## 1. Real Bugs

### WAV loader discards right channel but reports stereo
`src/assets/loaders.jai:44-49`

```jai
for sample, i: audio_samples {
    if i % 2 == 0 {   // only keeps L channel
        array_add(*audio.data, cast(float)sample / 32768.0);
    }
}
audio.channels = format.nChannels;  // but still reports 2
```

The loader keeps every other sample (L only for stereo PCM) but stores the original `nChannels`
count. The mixer then uses `source_channels` to index into this data, reading out-of-range
positions for the right channel. Fix: either (a) fully decode both channels, or (b) store
`channels = 1` when you've downmixed to mono. The channel count and data layout are currently
inconsistent.

### `clear_world` leaks RDM GPU textures
`src/world.jai:148-158`

`clear_world()` frees instances/groups but never calls `sg_destroy_image` for chunks with
`rdm_valid == true`. `unload_current_world()` has the correct GPU cleanup loop — `clear_world`
needs the same treatment, or it should delegate to `unload_current_world` and re-init.

---

## 2. Memory / Resource Leaks

### `free_resources_from_pack` is empty
`src/assets/asset_manager.jai:279-281`

```jai
free_resources_from_pack :: (pack: *Loaded_Pack) {
    // empty
}
```

`add_resources_from_pack` uploads GPU textures (`sg_make_image`), copies audio data into heap
arrays, and allocates animation frame arrays. None of this is ever freed. If packs are ever
hot-reloaded or unloaded, every `sg_image`, every `Audio_Data.data` array, and every
`Animation.frames` array leaks.

### `to_c_string` in `asset_manager_tick` leaks per fetch
`src/assets/asset_manager.jai:325-329`

```jai
sfetch_send(*(sfetch_request_t.{
    path = to_c_string(req.path),   // heap allocation, never freed
    ...
}));
```

`to_c_string` allocates from the heap allocator. The pointer is discarded after `sfetch_send`.
One small leak per asset load. Store the result, pass it, then free it after the call (or
allocate with `temp` if sokol copies the path internally).

### `fetch_callback` for PACK uses `NewArray` whose memory is never freed
`src/assets/asset_manager.jai:76-77`

```jai
mem := NewArray(res.data.size.(s64), u8, false);
memcpy(mem.data, res.data.ptr, res.data.size.(s64));
```

This heap-allocates the entire pack contents. With `free_resources_from_pack` being empty, this
memory is never freed.

---

## 3. Crash on Corrupt Data

### `read_value`/`read_string` use `assert()` for file bounds checks
`src/world.jai:240-250`

```jai
read_value :: (data: []u8, cursor: *s64, $T: Type) -> T {
    assert(cursor.* + size_of(T) <= data.count, "read_value: out of bounds");
    ...
}
```

`assert` crashes on a malformed or truncated world file. Since this data comes from disk it can
be corrupted or truncated. The `load_world_from_data` pattern of returning `(World, bool)` is
already in place — extend that into `read_value` returning `(T, bool)` so corrupt files are
rejected gracefully rather than crashing the process.

---

## 4. Fixed Timestep "Spiral of Death"

### No cap on `delta_time_accumulator`
`src/main.jai:198-201`

```jai
while delta_time_accumulator > (1.0/60.0) {
    game_tick(1.0/60.0);
    delta_time_accumulator -= (1.0/60.0);
}
```

If a frame takes longer than one tick (debugging, loading spike, OS sleep), the accumulator grows
without bound. On the next frame many ticks run back-to-back, making that frame slow too — the
classic spiral. Add a cap before the while loop:

```jai
delta_time_accumulator = min(delta_time_accumulator, 0.25);
```

There is also a **first-frame spike**: when loading finishes, `delta_time` includes all the time
spent loading (potentially seconds), blowing up the accumulator immediately. Reset
`last_frame_time` when `init_after_core_done` flips to true.

---

## 5. Missing `sg_commit` During Loading

### No frame commit when returning early
`src/main.jai:168-183`

When `mandatory_loads_done()` returns false, `frame()` returns without calling `render()` (which
calls `sg_commit()`). Some backends accumulate state that must be flushed each frame. At minimum
do a clear pass + `sg_commit()` when returning early during loading, or call it unconditionally
at the end of `frame()`.

---

## 6. World File Robustness

### Instance count silently truncated to `u16`
`src/world.jai:311`

```jai
count := cast(u16) group.instances.count;
```

If a chunk accumulates more than 65,535 instances of one trile type the count wraps silently on
save and the file is then unloadable. At minimum add an `assert(group.instances.count <= 0xFFFF)`
or widen to `u32`.

### No file integrity check

The binary format has magic + version but no CRC32 or checksum. A truncated or bit-flipped file
passes all header checks and then hits the assert crash. Even a simple FNV-1a checksum appended
at the end would let you detect corruption cleanly and emit a helpful error.

### Chunk data offsets are `u32`

Large worlds (>4 GB total chunk data) would overflow `running_offset`. Not a present concern but
worth noting if worlds grow significantly.

---

## 7. Audio Mixer Output Clipping

### No output saturation
`src/audio/mixer.jai:126`

```jai
buffer[out_index] += sample * vol;
```

Multiple loud tracks sum without clamping. Sokol audio expects `[-1.0, 1.0]` float PCM. Values
outside that range clip hard on most backends or cause driver-level distortion. After the mixing
loop, clamp each output sample:

```jai
buffer[i] = clamp(buffer[i], -1.0, 1.0);
```

---

## 8. Queue Performance

### O(n) front removal in `asset_manager_tick`
`src/assets/asset_manager.jai:316-319`

```jai
for i: 0..g_asset_manager.fetch_queue.count - 2 {
    g_asset_manager.fetch_queue[i] = g_asset_manager.fetch_queue[i + 1];
}
g_asset_manager.fetch_queue.count -= 1;
```

This shifts the entire array on every dequeue. With only a handful of queued fetches at a time
this is fine in practice, but a simple head-index (`fetch_queue_head: int`) avoids the shift
entirely.

---

## 9. `find_pack_by_name` Returns by Value

`src/assets/asset_manager.jai:283-292`

```jai
find_pack_by_name :: (name: string) -> (bool, Loaded_Pack) { ... }
```

`Loaded_Pack` contains `Table` structs. Copying them and then calling `table_find_pointer` into
the copy is technically safe (the backing heap arrays are shared), but semantically wrong — you
get a copy of the struct, not a stable pointer into `g_asset_manager.loadedPacks`. If the
`loadedPacks` array is ever reallocated (another pack added while the copy is held), things get
subtly wrong. Change the return type to `*Loaded_Pack` and return null on not-found.

---

## 10. `load_string_from_pack` Returns a Raw View

`src/assets/asset_manager.jai:404-419`

The function even comments "you are circumventing the asset management system." The returned
`string.data` points directly into the pack's internal content buffer. If the pack is ever freed
or `loadedPacks` reallocated, this string dangles. Either document that callers must
`copy_string` the result, or return a heap copy directly from this function.

---

## 11. Minor Items

- **`get_window_info()` returns hardcoded 1920x1080** (`src/main.jai:63-70`). The actual window
  size is read from `sapp_width()/sapp_height()` everywhere else. This function appears to be
  dead code — worth deleting to avoid confusion.

- **`print("Should show loading screen....\n")` on every loading frame** (`src/main.jai:176`).
  This spams stdout at 60 fps for the entire loading phase. Remove or guard with a one-shot flag.

- **RDM header doesn't validate `width × height` fits within the static buffer**
  (`src/assets/asset_manager.jai:121`). A malformed file with huge dimension values could cause
  the `sg_image_data` range to extend past `rdm_atlas_buf`. Add an explicit bounds check:
  `if atlas_pixel_bytes > RDM_ATLAS_MAX_BYTES - header_size then { ...; return; }`.

- **`World_Config_Binary` field set is not versioned independently.** Adding new fields to
  `World_Config` without bumping `WORLD_VERSION` silently breaks existing saved worlds. Consider
  a migration path or at minimum a compile-time size check.

---

## Summary

| Priority   | Area       | Issue                                                    |
|------------|------------|----------------------------------------------------------|
| Bug        | Audio      | WAV loader discards right channel but reports stereo     |
| Bug        | World      | `clear_world` leaks RDM GPU textures                     |
| Leak       | Assets     | `free_resources_from_pack` is empty; nothing freed       |
| Leak       | Assets     | `to_c_string` result never freed per fetch               |
| Crash      | World      | `assert()` on corrupt file data instead of error return  |
| Stability  | Game loop  | No cap on `delta_time_accumulator` (spiral of death)     |
| Stability  | Game loop  | First post-loading frame has enormous delta spike        |
| Correctness| Rendering  | No `sg_commit` during loading frames                     |
| Robustness | World      | `u16` instance count silently truncates on save          |
| Robustness | World      | No file checksum / integrity check                       |
| Audio      | Mixer      | No output clamping; overlapping tracks clip              |
| Performance| Assets     | O(n) queue front removal on every tick                   |
| Correctness| Assets     | `find_pack_by_name` returns copy instead of pointer      |
