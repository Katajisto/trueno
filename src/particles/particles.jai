#scope_export

g_pending_emitter_world_name : string;

particles_process_deferred_loads :: () {
    if g_pending_emitter_world_name.count == 0 then return;
    name := g_pending_emitter_world_name;
    g_pending_emitter_world_name = "";
    load_emitters_for_world(name);
    free(name.data);
}

Particle_Emitter_Definition :: struct {
    name             : string;
    sprite_sheet     : string;
    emission_rate    : float = 10.0;
    lifetime_min     : float = 0.5;
    lifetime_max     : float = 2.0;
    velocity         : Vector3;
    velocity_spread  : Vector3;
    size_start       : float = 0.5;
    size_end         : float = 0.0;
    color_start      : Vector4 = .{1, 1, 1, 1};
    color_end        : Vector4 = .{1, 1, 1, 0};
    frame_count      : int = 1;
    gravity          : float = 2.0;

    sprite_image     : sg_image; // resolved at runtime from sprite_sheet name
}

Particle_Emitter_Instance :: struct {
    definition        : *Particle_Emitter_Definition;
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
    definition : *Particle_Emitter_Definition;
}

MAX_PARTICLES : s32 : 2048;

g_particles          : [2048] Particle;
g_emitter_instances  : [..] Particle_Emitter_Instance;
g_emitter_defs       : [..] Particle_Emitter_Definition;

tick_particles :: (dt: float) {
    for *p: g_particles {
        if !p.alive then continue;
        p.age += dt;
        if p.age >= p.lifetime {
            p.alive = false;
            continue;
        }
        p.velocity.y   -= p.gravity * dt;
        p.position     += p.velocity * dt;
    }

    for *inst: g_emitter_instances {
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

add_particle_render_tasks :: () {
    for *def: g_emitter_defs {
        if def.sprite_image.id == 0 then continue;

        instances : [..] Particle_Instance_Data;
        instances.allocator = temp;

        for *p: g_particles {
            if !p.alive then continue;
            if p.definition != def then continue;

            t := p.age / p.lifetime;
            t = clamp(t, 0.0, 1.0);

            frame_count := cast(s32) max(def.frame_count, 1);
            frame_idx   := cast(s32)(t * cast(float) frame_count);
            frame_idx    = clamp(frame_idx, 0, frame_count - 1);

            frame_w  := 1.0 / cast(float) frame_count;
            uv_rect  := Vector4.{frame_idx * frame_w, 0.0, frame_w, 1.0};

            size  := def.size_start + (def.size_end - def.size_start) * t;
            color := lerp_color(def.color_start, def.color_end, t);

            inst : Particle_Instance_Data;
            inst.pos_size = .{p.position.x, p.position.y, p.position.z, size};
            inst.uv_rect  = uv_rect;
            inst.color    = color;
            array_add(*instances, inst);
        }

        if instances.count == 0 then continue;

        task : Rendering_Task_Particles;
        task.instances    = instances;
        task.sprite_image = def.sprite_image;
        add_rendering_task(task);
    }
}

clear_particle_emitter_instances :: () {
    array_reset(*g_emitter_instances);
    for *p: g_particles {
        p.alive = false;
    }
}

place_emitter :: (def_name: string, position: Vector3) {
    inst : Particle_Emitter_Instance;
    inst.definition_name = sprint("%", def_name);
    inst.position        = position;
    inst.active          = true;
    resolve_emitter_definition(*inst);
    array_add(*g_emitter_instances, inst);
}

remove_emitter_at_index :: (idx: int) {
    if idx < 0 || idx >= g_emitter_instances.count then return;
    array_unordered_remove_by_index(*g_emitter_instances, idx);
}

resolve_all_emitter_instances :: () {
    for *inst: g_emitter_instances {
        resolve_emitter_definition(inst);
    }
}

get_emitter_def_names :: () -> []string {
    names : [..] string;
    names.allocator = temp;
    for def: g_emitter_defs {
        array_add(*names, def.name);
    }
    return names;
}

save_particle_definition :: (def: Particle_Emitter_Definition) {
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

load_emitters_for_world :: (world_name: string) {
    #if OS != .WASM {
        file :: #import "File";
        path := tprint("./game/resources/worlds/%/emitters.json", world_name);
        data, ok := file.read_entire_file(path);
        if !ok then return;
        defer free(data.data);

        Emitter_Entry :: struct {
            definition : string;
            position   : [3] float;
        }
        success, entries := Jaison.json_parse_string(cast(string) data, [] Emitter_Entry,, temp);
        if !success {
            log_error("Failed to parse emitters.json for world '%'", world_name);
            return;
        }
        for entry: entries {
            pos := Vector3.{entry.position[0], entry.position[1], entry.position[2]};
            place_emitter(entry.definition, pos);
        }
        log_info("Loaded % emitters for world '%'", entries.count, world_name);
    }
}

save_emitters_for_world :: (world_name: string) {
    #if OS != .WASM {
        file :: #import "File";
        dir := tprint("./game/resources/worlds/%", world_name);
        file.make_directory_if_it_does_not_exist(dir, recursive = true);
        path := tprint("%/emitters.json", dir);

        Emitter_Entry :: struct {
            definition : string;
            position   : [3] float;
        }
        entries : [..] Emitter_Entry;
        entries.allocator = temp;
        for inst: g_emitter_instances {
            e : Emitter_Entry;
            e.definition   = inst.definition_name;
            e.position[0]  = inst.position.x;
            e.position[1]  = inst.position.y;
            e.position[2]  = inst.position.z;
            array_add(*entries, e);
        }
        json := Jaison.json_write_string(entries,, temp);
        file.write_entire_file(path, json);
        log_info("Saved % emitters for world '%'", entries.count, world_name);
    }
}

#scope_file

Random :: #import "Random";

rng :: inline (lo: float, hi: float) -> float {
    return lo + Random.random_get_zero_to_one() * (hi - lo);
}

spawn_one_particle :: (position: Vector3, def: *Particle_Emitter_Definition) {
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

resolve_emitter_definition :: (inst: *Particle_Emitter_Instance) {
    for *def: g_emitter_defs {
        if def.name == inst.definition_name {
            inst.definition = def;
            return;
        }
    }
    inst.definition = null;
}
