#scope_export

Particle_Blend_Mode :: enum {
    ADDITIVE;
    ALPHA;
}

Particle_Emitter_Config :: struct {
    name             : string;
    animation_name   : string;
    emission_rate    : float = 10.0;
    lifetime_min     : float = 0.5;
    lifetime_max     : float = 2.0;
    velocity         : Vector3;
    velocity_spread  : Vector3;
    position_spread  : Vector3;
    size_start       : float = 0.5;
    size_end         : float = 0.0;
    color_start      : Vector4 = .{1, 1, 1, 1};
    color_end        : Vector4 = .{1, 1, 1, 0};
    gravity          : float = 2.0;
    blend_mode       : Particle_Blend_Mode = .ADDITIVE;
}

Particle_Emitter_Instance :: struct {
    definition        : *Particle_Emitter_Config;
    definition_name   : string;
    position          : Vector3;
    active            : bool = true;
    spawn_accumulator : float;
}

Particle :: struct {
    position   : Vector3;
    velocity   : Vector3;
    age        : float;
    lifetime   : float;
    gravity    : float;
    alive      : bool;
    definition : *Particle_Emitter_Config;
}

MAX_PARTICLES : s32 : 2048;

g_particles    : [2048] Particle;
g_emitter_defs : [..] Particle_Emitter_Config;

tick_particles :: (dt: float) {
    for *p: g_particles {
        if !p.alive then continue;
        p.age += dt;
        if p.age >= p.lifetime {
            p.alive = false;
            continue;
        }
        p.velocity.y -= p.gravity * dt;
        p.position   += p.velocity * dt;
    }

    curworld := get_current_world();
    if !curworld.valid then return;
    for *inst: curworld.world.emitter_instances {
        if !inst.active then continue;
        if inst.definition == null {
            inst.definition = get_emitter_def(inst.definition_name);
            if inst.definition == null then continue;
        }
        def := inst.definition;
        inst.spawn_accumulator += def.emission_rate * dt;
        while inst.spawn_accumulator >= 1.0 {
            inst.spawn_accumulator -= 1.0;
            spawn_one_particle(inst.position, def);
        }
    }
}

tick_emitter_instance :: (inst: *Particle_Emitter_Instance, dt: float) {
    if !inst.active then return;
    if inst.definition == null then return;
    def := inst.definition;
    inst.spawn_accumulator += def.emission_rate * dt;
    while inst.spawn_accumulator >= 1.0 {
        inst.spawn_accumulator -= 1.0;
        spawn_one_particle(inst.position, def);
    }
}

add_particle_render_tasks :: () {
    Batch :: struct {
        anim_name  : string;
        blend_mode : Particle_Blend_Mode;
        anim       : *Animation;
        task       : *Rendering_Task_Particles;
        count      : s32;
    }

    batches : [..] Batch;
    batches.allocator = temp;

    for *p: g_particles {
        if !p.alive then continue;

        if p.definition == null then continue;
        def := p.definition;
        if def.animation_name.count == 0 then continue;

        batch : *Batch = null;
        for *b: batches {
            if b.anim_name == def.animation_name && b.blend_mode == def.blend_mode {
                batch = b;
                break;
            }
        }

        if batch == null {
            anim := get_animation_from_string(def.animation_name);
            if anim == null then continue;
            array_add(*batches, .{ anim_name = def.animation_name, blend_mode = def.blend_mode, anim = anim, task = New(Rendering_Task_Particles,, temp) });
            batch = *batches[batches.count - 1];
            batch.task.sheet = anim.sheet;
            batch.task.blend_mode = def.blend_mode;
        }

        if batch.count >= MAX_PARTICLES then continue;

        t := p.age / p.lifetime;
        size := def.size_start + (def.size_end - def.size_start) * t;
        col := lerp_color(def.color_start, def.color_end, t);

        idx := batch.count;
        batch.task.pos_size[idx] = .{p.position.x, p.position.y, p.position.z, size};

        anim := batch.anim;
        frame_count := anim.frames.count;
        if frame_count == 0 then continue;
        frame := cast(s32)(t * cast(float)(frame_count - 1));
        if frame < 0 then frame = 0;
        if frame >= frame_count then frame = cast(s32)(frame_count - 1);
        f := anim.frames[frame];
        batch.task.uv_rects[idx] = .{
            cast(float)f.x / cast(float)anim.sheet_w,
            cast(float)f.y / cast(float)anim.sheet_h,
            cast(float)f.w / cast(float)anim.sheet_w,
            cast(float)f.h / cast(float)anim.sheet_h,
        };

        batch.task.colors[idx] = col;
        batch.count += 1;
    }

    for *b: batches {
        if b.count > 0 {
            b.task.count = b.count;
            add_rendering_task(b.task.*);
        }
    }
}

get_emitter_def :: (name: string) -> *Particle_Emitter_Config {
    for *def: g_emitter_defs {
        if def.name == name then return def;
    }
    return null;
}

spawn_particles_at :: (position: Vector3, def_name: string) {
    for *def: g_emitter_defs {
        if def.name == def_name {
            spawn_one_particle(position, def);
            return;
        }
    }
}

register_emitter_def :: (def: Particle_Emitter_Config) {
    for *existing: g_emitter_defs {
        if existing.name == def.name {
            existing.* = def;
            return;
        }
    }
    array_add(*g_emitter_defs, def);
}

get_emitter_def_names :: () -> []string {
    names : [..] string;
    names.allocator = temp;
    for def: g_emitter_defs {
        array_add(*names, def.name);
    }
    return names;
}

save_particle_defs :: () {
    #if OS != .WASM {
        file :: #import "File";
        json := Jaison.json_write_string(g_emitter_defs, " ");
        file.write_entire_file(tprint("%/game_core/particles.json", GAME_RESOURCES_DIR), json);
        log_info("Saved % particle definitions", g_emitter_defs.count);
    }
}

#scope_file

Random :: #import "Random";

rng :: inline (lo: float, hi: float) -> float {
    return lo + Random.random_get_zero_to_one() * (hi - lo);
}

spawn_one_particle :: (position: Vector3, def: *Particle_Emitter_Config) {
    for *p: g_particles {
        if p.alive then continue;
        p.alive    = true;
        p.age      = 0;
        p.lifetime = rng(def.lifetime_min, def.lifetime_max);
        p.position = position + Vector3.{
            rng(-def.position_spread.x, def.position_spread.x),
            rng(-def.position_spread.y, def.position_spread.y),
            rng(-def.position_spread.z, def.position_spread.z),
        };
        p.velocity = def.velocity + Vector3.{
            rng(-def.velocity_spread.x, def.velocity_spread.x),
            rng(-def.velocity_spread.y, def.velocity_spread.y),
            rng(-def.velocity_spread.z, def.velocity_spread.z),
        };
        p.gravity    = def.gravity;
        p.definition = def;
        return;
    }
}

lerp_color :: (a: Vector4, b: Vector4, t: float) -> Vector4 {
    return a * (1.0 - t) + b * t;
}
