#scope_export

Particle_Emitter_Config :: struct {
    name             : string;
    animation_name   : string;
    emission_rate    : float = 10.0;
    lifetime_min     : float = 0.5;
    lifetime_max     : float = 2.0;
    velocity         : Vector3;
    velocity_spread  : Vector3;
    size_start       : float = 0.5;
    size_end         : float = 0.0;
    color_start      : Vector4 = .{1, 1, 1, 1};
    color_end        : Vector4 = .{1, 1, 1, 0};
    gravity          : float = 2.0;

    animation        : *Animation; // resolved at runtime from animation_name
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
    return;
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

    for *inst: get_current_world().world.emitter_instances {
        if inst == null then continue;
        if !inst.active then continue;
        if inst.definition == null then continue;
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
    // TODO
}

get_emitter_def_names :: () -> []string {
    names : [..] string;
    names.allocator = temp;
    for def: g_emitter_defs {
        array_add(*names, def.name);
    }
    return names;
}

save_particle_definition :: (def: Particle_Emitter_Config) {
    #if OS != .WASM {
        file :: #import "File";
        dir := "./game/resources/particles";
        file.make_directory_if_it_does_not_exist(dir, recursive = true);
        path := tprint("%/%.emitter.json", dir, def.name);
        json := Jaison.json_write_string(def,, temp);
        file.write_entire_file(path, json);
        log_info("Saved particle definition '%'", def.name);
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
        p.position = position;
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
