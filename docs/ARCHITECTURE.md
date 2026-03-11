# Trueno Engine — Architecture Overview

**Version:** 0.6
**Language:** Jai
**Target platforms:** macOS (native), Linux (native), WebAssembly (via Emscripten)

---

## High-Level Structure

Trueno is a purpose-built 3D game engine for a beach volleyball game. The codebase is split into
three clear layers:

```
┌─────────────────────────────────────────────────┐
│                  game/                          │  Game logic (volleyball rules, players, state)
├─────────────────────────────────────────────────┤
│                   src/                          │  Engine systems
├─────────────────────────────────────────────────┤
│  sokol / stb_image / GetRect / Jaison / ...     │  Third-party modules/
└─────────────────────────────────────────────────┘
```

The engine layer (`src/`) owns the main loop, rendering, audio, asset loading, and editor. The
game layer (`game/`) only implements game-specific logic and calls into the engine. There is no
formal interface between the two — they share a single Jai compilation unit — but the separation
is clean in practice.

---

## Entry Points and the Frame Loop

```
sokol_app
  └─ init()           -- one-shot startup
  └─ frame()          -- called every display frame
  └─ event()          -- input / window events
  └─ cleanup()        -- shutdown
```

`src/platform_specific/` contains two thin files: `main_native.jai` (desktop) and `main_web.jai`
(WASM). Both call into `common.jai` which sets up sokol and then calls the engine's `init()`,
`frame()`, `event()`, `cleanup()` in `src/main.jai`.

### Deferred Initialization

Engine startup is split into three phases to handle async asset loading:

```
frame() tick 1..N
  │
  ├─ asset_manager_tick()          ← drives sokol_fetch async I/O
  │
  ├─ mandatory_loads_done()?  ──no─→ return   (blocks entire frame)
  │         yes
  ├─ init_after_mandatory()        ← (currently empty, reserved)
  │
  ├─ show_loading_screen()?   ──yes→ return   (shows loading UI)
  │         no
  └─ init_after_core()             ← init UI, audio, game, pipelines
```

The two boolean flags (`init_after_mandatory_done`, `init_after_core_done`) ensure each phase
runs exactly once after its prerequisite packs have loaded.

### Fixed Timestep Game Loop

```jai
delta_time_accumulator += delta_time;
while delta_time_accumulator > (1.0/60.0) {
    game_tick(1.0/60.0);
    delta_time_accumulator -= (1.0/60.0);
}
```

Game logic runs at a fixed 60 Hz regardless of render frame rate. Rendering always runs at the
display's native rate. The editor bypasses the accumulator entirely — when `in_editor_view` is
true, no game ticks run.

---

## Directory Map

```
beachgame/
├── first.jai                  Build metaprogram (compile-time build script)
├── build.sh / build_web.sh    Shell wrappers around the Jai compiler
│
├── src/
│   ├── main.jai               Engine core: init, frame loop, window info
│   ├── events.jai             Sokol event dispatch → Input module
│   ├── load.jai               Asset loading flags, init state
│   ├── time.jai               get_time() / get_apollo_time() abstraction
│   ├── trile.jai              Trile/Trixel/Material types, JSON serialization
│   ├── world.jai              World/chunk data model, binary serialization
│   ├── ray.jai                Ray-casting helpers
│   ├── utils.jai              sign(), mix() math helpers
│   ├── profiling.jai          Frame-level profiling points
│   ├── buffers.jai
│   ├── shapes.jai
│   │
│   ├── assets/
│   │   ├── asset_manager.jai  Async fetch queue, pack/world/RDM loading
│   │   ├── loaders.jai        PNG / WAV / string loaders from raw memory
│   │   └── rdm_loader.jai     RDM chunk streaming enqueue/cancel
│   │
│   ├── audio/
│   │   ├── audio.jai          Audio init/cleanup, Audio_Data type
│   │   ├── backend.jai        Sokol audio stream callback bridge
│   │   ├── load.jai           WAV loading helpers
│   │   └── mixer.jai          Software float32 mixer (buses, tasks, mutex)
│   │
│   ├── rendering/
│   │   ├── rendering.jai      Module root, window-resize handler
│   │   ├── core.jai           init_rendering(), render() entry point
│   │   ├── tasks.jai          Rendering_Task types and task→command conversion
│   │   ├── backend.jai        Command bucket types, process_command_buckets()
│   │   ├── backend_sokol.jai  All sokol draw call implementations
│   │   ├── backend_sokol_helpers.jai
│   │   ├── pipelines.jai      Pipeline creation, all render target images
│   │   ├── camera.jai         Camera struct, perspective/lookat math
│   │   ├── meshgen.jai        Quad mesh generation from trile voxel data
│   │   ├── animation.jai      Sprite animation player, Aseprite JSON structs
│   │   ├── helpers.jai        create_world_rendering_tasks(), uniform helpers
│   │   ├── arbtri.jai         Immediate-mode triangle batch renderer (UI)
│   │   ├── post_processing.jai Post-process config, LUT management
│   │   ├── sky.jai            Sky rendering helpers
│   │   └── ssao.jai           SSAO kernel/noise generation
│   │
│   ├── editor/
│   │   ├── editor.jai         Editor root: three views, F3 toggle
│   │   ├── console.jai        In-game console (F1), command dispatch
│   │   ├── level_editor.jai   Level editing camera and trile placement tools
│   │   ├── trile_editor.jai   Voxel painting editor
│   │   ├── tacoma.jai         Path tracer (Tacoma) integration
│   │   ├── no_tacoma.jai      Stub when Tacoma is unavailable
│   │   ├── rdm_disk.jai       RDM bake result disk I/O
│   │   ├── picker.jai         Mouse picker
│   │   ├── iprof.jai          Iprof profiler integration
│   │   └── textureDebugger.jai Texture visualization tool
│   │
│   ├── input/
│   │   └── hotkeys.jai
│   │
│   ├── ui/
│   │   ├── ui.jai             UI backend: GetRect integration, font, triangles
│   │   ├── component_themes.jai Custom UI themes
│   │   └── autoedit.jai       Reflection-based automatic struct editors
│   │
│   ├── pseudophysics/
│   │   ├── core.jai
│   │   └── colliders.jai      Rect-circle collision
│   │
│   ├── platform_specific/
│   │   ├── common.jai         Sokol imports, sapp_run, context/temp storage
│   │   ├── main_native.jai    Desktop entry point
│   │   ├── main_web.jai       WASM entry point
│   │   ├── main.c             C glue for Emscripten link
│   │   ├── runtime.js         JS runtime helpers
│   │   └── shell.html         WASM HTML shell
│   │
│   ├── meta/
│   │   ├── meta.jai           Metaprogram: message handler entry point
│   │   ├── pack.jai           Asset pack creation at build time
│   │   ├── shaderload.jai     Adds compiled shaders to workspace
│   │   ├── lint.jai           Compile-time snake_case linter
│   │   ├── console_commands.jai @Command auto-registration code generator
│   │   ├── ascii.jai          ASCII art logo
│   │   └── hacks.jai          Metaprogram workarounds
│   │
│   └── shaders/
│       ├── *.glsl             GLSL shader sources (~12 shaders)
│       ├── jai/*.jai          Compiled shader descriptors (sokol-shdc output)
│       └── compile_shaders*.sh
│
├── game/
│   ├── game.jai               Game init, fixed-step tick, draw
│   ├── player.jai             Player struct and input handling
│   └── state.jai              Game state machine and scoring
│
├── modules/                   Third-party / custom Jai modules
│   ├── sokol-jai/             Jai bindings for sokol (gfx, app, audio, fetch)
│   ├── stb_image/             stb_image bindings
│   ├── Jaison/                JSON parsing/serialization
│   ├── Simple_Package_Reader/ .pack file reader
│   ├── Input/                 Input module with sokol bindings
│   ├── Tacoma/                Path tracer integration
│   └── Walloc.jai             WASM allocator
│
├── resources/                 Engine-level assets (fonts, textures, audio)
├── game/resources/            Game-level assets (worlds, sprites, audio)
└── packs/                     Compiled .pack files (build output)
```

---

## Core Systems

### Asset Manager

All file I/O flows through a single sequential fetch queue backed by `sokol_fetch`. Only one file
is ever in-flight at a time.

```
load_pack() / load_world()
        │
        ▼
  fetch_queue [..]Fetch_Request
        │
        ▼  (asset_manager_tick, once per frame)
  sfetch_send()  ──async──►  fetch_callback()
                                    │
                          resolve by Fetch_Type
                          ┌─────────┬──────────┬────────────┐
                        PACK      WORLD    RDM_ATLAS    RDM_LOOKUP
                          │         │          │             │
                     Loaded_Pack  World    sg_make_image  sg_make_image
                     in loadedPacks  in current_world    in chunk
```

Static pre-allocated I/O buffers are used for each fetch type (200 MB for packs/worlds, smaller
buffers for RDM data) so no runtime heap allocation occurs during file loading.

**Blocking modes:**
- `should_block_engine` — halt entire frame (used for the boot pack; engine cannot run without it)
- `should_block` — show loading screen (used for core/game packs)

### Rendering Pipeline

The rendering system uses a three-stage data flow:

```
Game/Editor code
      │  add_rendering_task()
      ▼
[Rendering_Task list]          (per-frame, temp allocated)
      │  tasks_to_commands()
      ▼
[Command Buckets]              setup / shadow / reflection / gbuffer / main / ui
      │  backend_process_command_buckets()
      ▼
Sokol GFX draw calls
```

**Render passes per frame (in order):**

| Pass         | Output                         | Notes                                  |
|--------------|--------------------------------|----------------------------------------|
| Setup        | GPU position/uniform buffers   | Uploads trile instance stream data     |
| Shadow       | 1000×1000 depth texture        | Orthographic sun directional light; PCF soft edges (Gaussian-weighted sampling) |
| Reflection   | Half-res RGBA32F texture       | Planar water reflection: camera Y-flipped around water plane; handles dynamic objects that RDMs cannot |
| G-Buffer     | Position + Normal RGBA16F      | Used by SSAO and deferred effects      |
| SSAO         | Single-channel AO texture      | Random sample kernel, 64 samples       |
| SSAO Blur    | Blurred AO texture             | Separable blur                         |
| Main         | RGBA32F HDR target             | Forward render: sun direct + RDM indirect (specular + diffuse) + SSAO |
| Post chain   | Bloom → DoF ping-pong          | Between postprocess_a / postprocess_b  |
| Final        | Swapchain                      | Tonemap, LUT grade, vignette, grain    |

**Trile rendering** uses GPU instancing. Each trile type's mesh is generated once (quad mesher,
`src/rendering/meshgen.jai`) and uploaded as a static vertex buffer. Per-frame instance
positions are streamed via `sg_append_buffer` into a dynamic buffer, with one draw call per
trile type per pass.

Mesh generation merges visible trixel faces into larger coplanar quads (greedy meshing), reducing
triangle count dramatically vs. rendering each trixel individually. The mesh triangles no longer
correspond 1:1 to trixels, so the shader resolves the trixel under a fragment by offsetting the
surface position slightly inward along the normal to land cleanly inside the trixel grid.

**Trixel material encoding:** each trixel stores 4 bytes — 3 bytes of RGB albedo and 1 byte
packed as: roughness (3 bits → 8 levels), metallic (2 bits → 4 levels), light emission (2 bits →
4 levels), plus 1 reserved bit. All material values map to the [0 … 1] range in the shader.

**RDM (Rhombic Dodecahedron Mapping)** is the pre-baked indirect lighting system for static
trile geometry. Each chunk optionally carries an `rdm_atlas` (RGBA32F 4096×4096) and an
`rdm_lookup` (RGBA32F 512×512) GPU texture. The trile shader uses these for indirect diffuse
and specular, falling back to flat ambient when unavailable.

The RDM concept: because all trile surface normals are axis-aligned, incoming light for a block
can be captured by storing exactly one hemisphere per face (6 total). Each hemisphere is encoded
with the **hemi-oct** projection (Cigolle et al. 2014) — the hemisphere is folded into a pyramid
and then flattened to a square. The six hemisphere squares are arranged in a 2×3 grid; together
they form a rhombic dodecahedron shape, giving the technique its name.

Each hemisphere stores both **radiance** (RGBA32F) and **depth-to-first-hit** in the same
texel, encoded via a 4-channel HDR image (3 colour channels + 1 depth channel). The depth
is used at runtime for parallax-corrected sampling: a ray is stepped outward from the surface
point to find where it would intersect the geometry visible in the stored hemisphere, correcting
the angular discrepancy between the hemisphere's centre-of-face origin and the actual shading
point.

**Multiple roughness levels:** the Tacoma path tracer pre-filters each RDM for 8 discrete
roughness values. Hemisphere resolution scales as 3·2^roughness × 2·2^roughness pixels, so
rougher (blurrier) RDMs are physically smaller. The maximum-roughness RDM (always baked)
doubles as the diffuse irradiance probe. Per-instance transform data passed alongside the GPU
instancing matrices encodes atlas UV offsets for roughness levels 1–7; the maximum-roughness
position is looked up separately from the lookup texture.

**Specular evaluation:** the shader selects the RDM for the fragment's roughness, finds the
reflected view direction, steps the reflection vector to find the correct sampling direction via
stored depth, samples the hemisphere, then combines the result with a pre-computed BRDF
split-sum lookup (indexed by roughness and NoV) to form the full split-sum specular.

**Diffuse evaluation:** the shader reads the maximum-roughness RDMs for the block and up to
three adjacent blocks (determined by which quadrant of the block face the fragment lies in),
samples each in the surface normal direction, and bilinearly blends the values. Missing
neighbours fall back to a static ambient constant.

**RDM streaming:** RDM data is loaded per chunk on demand via `src/assets/rdm_loader.jai`.
Each chunk's atlas and lookup textures are allocated as `sg_image` resources and destroyed
when the chunk is unloaded (`src/editor/rdm_disk.jai` handles disk I/O in the editor).

### World / Chunk System

The world is a sparse hash map of chunks. Each chunk is a 32×32×32 block of the world at
integer trile-space coordinates.

```
World
  └─ chunks: Table(Chunk_Key{x,y,z}, Chunk)
               └─ groups: [..]Chunk_Trile_Group
                    ├─ trile_name: string
                    └─ instances: [..]Trile_Instance{x,y,z,orientation}
```

**Coordinate math:**
- World integer position → chunk key: floor division (`floor_div`)
- World integer position → local position (0..31): floor modulo (`floor_mod`)
- Both handle negative coordinates correctly (rounds toward -infinity)

**Binary world format:**

```
[magic u32][version u16][name_len u16][name bytes]
[World_Config_Binary]
[num_chunks u32]
[chunk table: per chunk → chunk_x,y,z s32 × 3, data_offset u32, data_size u32]
[chunk data blobs]
```

### Lighting System

Trueno uses a **hybrid lighting model**: real-time direct light from the sun combined with
pre-baked indirect and emissive light stored in per-chunk RDM textures.

#### Direct lighting (sun)

A single directional light ("sun") is evaluated per-fragment at runtime. Visibility is determined
with a shadow map rendered each frame from an orthographic projection centred on the camera
target. Percentage-closer filtering (PCF) with Gaussian-weighted sampling produces soft shadow
edges. Surfaces outside the shadow map area are assumed unshadowed (no cascades currently).

#### Indirect lighting (RDM)

The Rhombic Dodecahedron Mapping technique (described in the Rendering Pipeline section above)
provides pre-baked indirect and emissive light for static trile geometry. The bake captures both
diffuse and specular (including sharp mirror-like reflections) from the path tracer.

**Emissive voxels:** materials with non-zero emission contribute to indirect lighting through the
RDM bake rather than being evaluated as real-time lights. This means dynamic objects only
receive sun light; they do not receive indirect light from emissive triles.

**Split-sum specular:** the specular term combines the pre-filtered RDM sample with a
pre-integrated BRDF lookup texture (indexed by roughness and the angle between view direction
and surface normal), following the split-sum approximation.

#### Water reflections (planar)

The ocean/water surface uses planar reflections: the entire scene is rendered a second time
with the camera flipped across the water plane into a half-resolution RGBA32F target. This
handles dynamic objects (players, ball) that do not appear in the static RDMs, and produces
sharp mirror-like reflections correct for large flat surfaces. Post-processing can add ripple
distortion to the reflection texture.

#### SSAO

Screen-space ambient occlusion darkens cavities and contact areas. A geometry pass outputs
world-space position and normal (RGBA16F G-buffer), then the SSAO pass samples 64 random
offsets to estimate local occlusion. The result is blurred with a separable filter and applied to
the ambient/diffuse contribution.

#### Pre-bake pipeline

RDM data is generated offline by **Tacoma** (`modules/Tacoma/`, integrated via
`src/editor/tacoma.jai`). Tacoma is a GPU path tracer (C++/Vulkan) that:

1. Builds a BLAS per unique trile type and assembles a TLAS with one instance per trile
   occurrence in the scene.
2. For each block, detects which of the 8 roughness levels are present in its trixels and
   renders one RDM per level. The maximum-roughness RDM is always rendered (needed for
   diffuse).
3. Saves per-RDM HDR images (3 colour + 1 depth channel) and packs them into a single atlas
   with a companion lookup file.

The editor (`Level Studio`) triggers this bake; results are saved to disk via `src/editor/rdm_disk.jai`
and loaded at runtime via the chunk streaming system.

### Audio Mixer

The mixer runs on a background audio thread (native) or on the main thread (WASM). The sokol
audio callback calls `mixer_get_samples()` which iterates all active `Mixer_Play_Task` entries,
accumulates float samples into the output buffer, and removes finished tasks.

```
Mixer
  ├─ config: Mixer_Config  (per-bus volume, master volume)
  ├─ tasks: [..]Mixer_Play_Task
  │    └─ audio: *Audio_Data (pointer into pack memory)
  │       bus: MUSIC | SOUND_EFFECT | DIALOGUE
  │       mode: ONESHOT | REPEAT
  │       curSample: s64
  └─ mutex (native only; no-op on WASM)
```

Thread safety: `mixer_add_task` and `mixer_get_samples` both acquire the mutex. On WASM, sokol
audio is single-threaded so the mutex is compiled out.

### UI System

The UI is built on top of `GetRect_LeftHanded` (immediate-mode retained UI) with a custom
immediate-mode triangle renderer (`arbtri`) as its drawing backend. All UI geometry is batched
into a single vertex buffer and drawn in the `ui` command bucket at the end of each frame.

A viewport-relative unit system (`vw`/`vh`, each = 1/100 of window dimension) is used throughout
for responsive sizing.

`autoedit.jai` provides reflection-based automatic struct editors: struct fields annotated with
`@Color`, `@Slider,min,max,step` etc. automatically get UI widgets generated at compile time via
Jai's type info system.

### Editor

The in-game editor (F3) has three views:

- **Trile Studio** — voxel painting on a 16×16×16 grid with material selection
- **Level Studio** — orbiting camera, ray-based trile placement, Y-layer selection, optional
  path-traced RDM bake via Tacoma integration
- **Material Studio** — lighting and world config parameters

The developer console (F1) dispatches commands registered at compile time. Functions annotated
`@Command` are processed by the metaprogram during compilation: argument-parsing front-ends
(`%__command_front`) are auto-generated and registered in `console_command_names` /
`console_command_procs` arrays — zero runtime overhead.

---

## Compile-Time Metaprogramming

`first.jai` is the build script, executed by the Jai compiler as a metaprogram. It:

1. Invokes `sokol-shdc` as a subprocess to compile GLSL shaders to backend-specific bytecode
   and generate Jai descriptor structs
2. Packs all files under `resources/` and `game/resources/` (excluding `.aseprite` and `/worlds/`)
   into binary `.pack` files
3. Adds the compiled shader descriptors to the compilation workspace
4. Runs the custom snake_case linter over all function declarations
5. Auto-generates `@Command` wrapper functions for the developer console

This means asset pipeline and code generation happen as part of compilation, with no separate
build step needed.

---

## Memory Model

| Lifetime        | Mechanism                                           |
|-----------------|-----------------------------------------------------|
| Per-frame temp  | `reset_temporary_storage()` at end of each frame    |
| Mesh generation | `Pool.Pool` reset after each trile mesh is uploaded |
| World lifetime  | `Pool.Pool` per `Current_World`, reset on unload    |
| Asset loading   | Static pre-allocated I/O buffers (never heap)       |
| GPU resources   | Explicit `sg_destroy_image/buffer` on replacement   |
| Leak detection  | `MEM_DEBUG :: true` enables Jai's memory debugger   |

---

## Platform Abstraction

Platform differences are handled with `#if OS == .WASM / .MACOS / .LINUX` throughout:

| Feature             | Native               | WASM                     |
|---------------------|----------------------|--------------------------|
| Audio thread mutex  | Thread.Mutex         | no-op                    |
| File I/O (editor)   | File module          | disabled                 |
| UV origin           | Metal: flipped       | WebGL: normal            |
| Allocator           | default Jai heap     | Walloc                   |
| Profiler            | Iprof available      | disabled                 |
| Stack size          | default              | 1 GB (emcc flag)         |
| WASM features       | —                    | bulk-memory enabled      |

---

## Third-Party Dependencies

| Library                  | Role                                         |
|--------------------------|----------------------------------------------|
| sokol_gfx                | Cross-platform graphics (Metal/GL/WebGL)     |
| sokol_app                | Window, input, event loop                    |
| sokol_audio              | PCM audio stream callback                    |
| sokol_fetch              | Async file / HTTP I/O                        |
| sokol_time               | High-resolution timer                        |
| sokol_gl / sokol_fontstash | Immediate-mode lines, font rendering       |
| stb_image                | PNG decode                                   |
| Jaison                   | JSON parse/serialize                         |
| GetRect_LeftHanded       | Immediate-mode retained UI layout            |
| Simple_Package_Reader    | Binary .pack file reader                     |
| Walloc                   | WASM-compatible allocator                    |
| Tacoma                   | GPU path tracer (C++/Vulkan) for offline RDM baking; integrated via editor |
| Iprof                    | Optional frame profiler                      |
