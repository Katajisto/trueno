// Entity types are plain structs declared in game code, registered with an
// @Entity note the way console commands register with @Command. The metaprogram
// (src/meta/entity_types.jai) collects them into ENTITY_TYPES, and spawning,
// dispatch, editor UI and saving all come from that. Marking a struct @Entity
// without embedding Entity, or embedding Entity without the note, is an error.
//
//   Foo :: struct {
//       #as using base : Entity;
//       base.type = Foo;
//       PARTS :: Entity_Part.[...];          // visuals, may be empty
//       EDITOR_MARKER :: "pack.animation";   // optional, editor-only billboard
//   } @Entity
//   entity_tick :: (using foo: *Foo, dt: float) {}   // optional
//   entity_draw :: (foo: *Foo) {}                    // optional
//
// Fields of type float, s32, bool, string or Vector3 are editable and saved;
// @Slider / @Color notes pick the editor widget.
//
// Each frame the game calls tick_entities, then tick_entity_emitters, then
// add_entity_render_tasks. The level editor calls the last two only: it shows
// entities and their particles without running their game logic.

#scope_export

Entity :: struct {
    type        : Type;
    id          : u32;
    position    : Vector3;
    orientation : u8;   // 0..23, see orientation.jai
    emitters    : [..]Particle_Emitter_Instance;   // built from PARTS, not saved
}

Entity_Part_Kind :: enum {
    TRILE;
    BILLBOARD;
    EMITTER;
}

Entity_Part :: struct {
    kind        : Entity_Part_Kind;
    trile       : string;   // TRILE
    orientation : u8;       // TRILE, 0..23
    animation   : string;   // BILLBOARD, e.g. "game_core.ball"
    emitter     : string;   // EMITTER, a particle definition name
    offset      : Vector3;
}

Entity_Type_Info :: struct {
    name          : string;
    type          : Type;
    parts         : []Entity_Part;
    editor_marker : string;
    create        : () -> *Entity;
}

#insert #run,stallable gen_entity_type_table();

get_entity_type_info :: (type: Type) -> *Entity_Type_Info {
    for * ENTITY_TYPE_TABLE  if it.type == type  return it;
    return null;
}

get_entity_parts :: (type: Type) -> []Entity_Part {
    info := get_entity_type_info(type);
    return ifx info then info.parts else .[];
}

get_entity_editor_marker :: (type: Type) -> string {
    info := get_entity_type_info(type);
    return ifx info then info.editor_marker else "";
}

entity_type_name :: (type: Type) -> string {
    return (cast(*Type_Info_Struct) type).name;
}

// Entities turn about the middle of their own cell, so a rotated entity stays
// on the block it was placed on.
ENTITY_PIVOT :: Vector3.{0.5, 0.5, 0.5};

entity_point :: (e: *Entity, offset: Vector3) -> Vector3 {
    return e.position + ENTITY_PIVOT + rotate_by_orientation(e.orientation, offset - ENTITY_PIVOT);
}

// A trile part fills a cell rather than being a point, so the pivot cancels out.
entity_trile_point :: (e: *Entity, offset: Vector3) -> Vector3 {
    return e.position + rotate_by_orientation(e.orientation, offset);
}

// Orientation is taken up front rather than assigned afterwards because the
// emitters are placed relative to it.
spawn_entity :: (world: *World, type_name: string, position: Vector3, orientation: u8 = 0) -> *Entity {
    for ENTITY_TYPE_TABLE {
        if it.name != type_name  continue;
        e := it.create();
        e.position    = position;
        e.orientation = orientation;
        e.id = world.next_entity_id;
        world.next_entity_id += 1;
        init_entity_emitters(e);
        array_add(*world.entities, e);
        return e;
    }
    log_error("Unknown entity type: %", type_name);
    return null;
}

get_first_entity :: (world: *World, type: Type) -> *Entity {
    for e: world.entities  if e.type == type  return e;
    return null;
}

remove_entity :: (world: *World, e: *Entity) {
    for other, i: world.entities {
        if other != e  continue;
        array_ordered_remove_by_index(*world.entities, i);
        free_entity(e);
        return;
    }
}

free_entity :: (e: *Entity) {
    array_free(e.emitters);
    free(e);
}

free_all_entities :: (world: *World) {
    for e: world.entities  free_entity(e);
    array_reset(*world.entities);
}

// Concrete per-type overloads in game code take precedence over these.
entity_tick :: (e: *$T/Entity, dt: float) {}
entity_draw :: (e: *$T/Entity) { draw_entity_parts(e); }

tick_entities :: (world: *World, dt: float) {
    for e: world.entities  entity_dispatch_tick(e, dt);
}

entity_dispatch_tick :: (e: *Entity, dt: float) {
    #insert #run,stallable gen_entity_dispatch("entity_tick(cast(*%)e, dt)");
}

entity_dispatch_draw :: (e: *Entity) {
    #insert #run,stallable gen_entity_dispatch("entity_draw(cast(*%)e)");
}

// Dispatches a call on the entity's concrete type. '%' in 'call' becomes the type
// name. Also used by the editor to run autoedit on an entity's own fields.
gen_entity_dispatch :: (call: string) -> string {
    builder : String_Builder;
    for ENTITY_TYPES {
        name := (cast(*Type_Info_Struct) it).name;
        print_to_builder(*builder, "if e.type == % { %; return; }\n", name, tprint(call, name));
    }
    return builder_to_string(*builder);
}

init_entity_emitters :: (e: *Entity) {
    for part: get_entity_parts(e.type) {
        if part.kind != .EMITTER  continue;
        inst : Particle_Emitter_Instance;
        inst.definition_name = part.emitter;
        inst.definition      = get_emitter_def(part.emitter);
        inst.offset          = part.offset;
        inst.position        = entity_point(e, part.offset);
        inst.active          = true;
        array_add(*e.emitters, inst);
    }
}

tick_entity_emitters :: (world: *World, dt: float) {
    for e: world.entities {
        for *inst: e.emitters {
            if inst.definition == null {
                inst.definition = get_emitter_def(inst.definition_name);
                if inst.definition == null  continue;
            }
            inst.position = entity_point(e, inst.offset);
            tick_emitter_instance(inst, dt);
        }
    }
}

// Once per frame, from the game and from the editor. Trile draws are batched per
// (trile, chunk) and flushed as TRILE_DYNAMIC tasks at the end.
add_entity_render_tasks :: (world: *World) {
    array_reset_keeping_memory(*entity_trile_batches);
    for e: world.entities  entity_dispatch_draw(e);
    for *batch: entity_trile_batches {
        task : Rendering_Task_Trile_Dynamic;
        task.trile     = batch.trile;
        task.positions = batch.positions;
        task.chunk_key = batch.chunk_key;
        task.worldConf = *world.conf;
        add_rendering_task(task);
    }
}

entity_draw_trile :: (e: *Entity, trile: string, offset: Vector3, orientation: u8 = 0) {
    pos := entity_trile_point(e, offset);
    ori := compose_orientations(e.orientation, orientation);
    key := world_to_chunk_coord(cast(s32) floor(pos.x), cast(s32) floor(pos.y), cast(s32) floor(pos.z));
    instance := Vector4.{pos.x, pos.y, pos.z, cast(float) ori};

    for *batch: entity_trile_batches {
        if batch.trile == trile && batch.chunk_key == key {
            array_add(*batch.positions, instance);
            return;
        }
    }
    batch : Entity_Trile_Batch;
    batch.trile     = trile;
    batch.chunk_key = key;
    batch.positions.allocator = temp;
    array_add(*batch.positions, instance);
    array_add(*entity_trile_batches, batch);
}

entity_draw_billboard :: (e: *Entity, animation: string, offset: Vector3, frame: s32 = 0) {
    anim := get_animation_from_string(animation);
    if anim == null  return;
    task : Rendering_Task_Billboard;
    task.position  = entity_point(e, offset);
    task.animation = anim;
    task.frame     = frame;
    add_rendering_task(task);
}

draw_entity_parts :: (e: *Entity) {
    for part: get_entity_parts(e.type) {
        if part.kind == {
            case .TRILE;     entity_draw_trile(e, part.trile, part.offset, part.orientation);
            case .BILLBOARD; entity_draw_billboard(e, part.animation, part.offset);
            case .EMITTER;   // tick_entity_emitters handles these
        }
    }
}

// Fields are saved as name/value string pairs rather than typed JSON, so adding,
// removing or renaming one never breaks loading an older world.
Entity_Field :: struct {
    name  : string;
    value : string;
}

entity_fields_to_strings :: (e: *Entity) -> []Entity_Field {
    result : [..]Entity_Field;
    result.allocator = temp;
    for member: entity_saved_members(e.type) {
        ptr := (cast(*u8) e) + member.offset_in_bytes;
        value : string;
        if member.type == type_info(float)        value = tprint("%", (cast(*float)  ptr).*);
        else if member.type == type_info(s32)     value = tprint("%", (cast(*s32)    ptr).*);
        else if member.type == type_info(bool)    value = tprint("%", (cast(*bool)   ptr).*);
        else if member.type == type_info(string)  value = (cast(*string) ptr).*;
        else if member.type == type_info(Vector3) {
            v := (cast(*Vector3) ptr).*;
            value = tprint("% % %", v.x, v.y, v.z);
        } else continue;
        array_add(*result, .{member.name, value});
    }
    return result;
}

entity_apply_field :: (e: *Entity, name: string, value: string) {
    for member: entity_saved_members(e.type) {
        if member.name != name  continue;
        ptr := (cast(*u8) e) + member.offset_in_bytes;
        if member.type == type_info(float) {
            v, ok := string_to_float(value);
            if ok  { (cast(*float) ptr).* = v; }
        } else if member.type == type_info(s32) {
            v, ok := string_to_int(value);
            if ok  { (cast(*s32) ptr).* = cast(s32) v; }
        } else if member.type == type_info(bool) {
            (cast(*bool) ptr).* = (value == "true");
        } else if member.type == type_info(string) {
            (cast(*string) ptr).* = copy_string(value);
        } else if member.type == type_info(Vector3) {
            parts := split(value, " ",, temp);
            if parts.count != 3  return;
            v : Vector3;
            x, okx := string_to_float(parts[0]);
            y, oky := string_to_float(parts[1]);
            z, okz := string_to_float(parts[2]);
            if okx && oky && okz  { (cast(*Vector3) ptr).* = .{x, y, z}; }
        }
        return;
    }
    log_warn("Entity type % has no field '%', skipping", entity_type_name(e.type), name);
}

#scope_file

#import "String";

// The members an entity type declares itself: constants and the Entity base are
// neither editable nor saved.
entity_saved_members :: (type: Type) -> []Type_Info_Struct_Member {
    result : [..]Type_Info_Struct_Member;
    result.allocator = temp;
    for (cast(*Type_Info_Struct) type).members {
        if it.flags & (.CONSTANT | .USING)  continue;
        array_add(*result, it);
    }
    return result;
}

Entity_Trile_Batch :: struct {
    trile     : string;
    chunk_key : Chunk_Key;
    positions : [..]Vector4;
}

entity_trile_batches : [..]Entity_Trile_Batch;

#if FLAG_TEST_ENGINE {
    // The two placement helpers use different pivots, and getting them the wrong
    // way round only shows up as parts drifting off a rotated entity, so both are
    // pinned to the invariant they exist for.
    test_entity_part_placement :: () {
        s := begin_suite("entity part placement");

        e : Entity;
        e.position = .{10, 3, -5};

        // A trile part on the entity's own cell has to stay on that cell however
        // the entity is turned, or rotating would walk it off the block it was
        // placed on.
        on_its_block := true;
        for ori: 0..ORIENTATION_COUNT-1 {
            e.orientation = cast(u8) ori;
            if entity_trile_point(*e, .{0, 0, 0}) != e.position  on_its_block = false;
        }
        check(*s, "a trile part on the entity's own cell never moves", on_its_block);

        // Point parts turn about the middle of that same cell, so a part sitting
        // at the middle is the fixed point of all 24 rotations.
        at_the_middle := true;
        for ori: 0..ORIENTATION_COUNT-1 {
            e.orientation = cast(u8) ori;
            if entity_point(*e, ENTITY_PIVOT) != e.position + ENTITY_PIVOT  at_the_middle = false;
        }
        check(*s, "a point part at the middle never moves", at_the_middle);

        e.orientation = 0;
        check(*s, "unturned point parts sit at their authored offset",
            entity_point(*e, .{1, 2, 3}) == e.position + Vector3.{1, 2, 3});
        check(*s, "unturned trile parts sit at their authored offset",
            entity_trile_point(*e, .{1, 2, 3}) == e.position + Vector3.{1, 2, 3});

        // Orientation 1 is the quarter twist about Y, which sends X to Z.
        e.orientation = 1;
        check(*s, "a turned entity carries its parts around with it",
            entity_trile_point(*e, .{1, 0, 0}) == e.position + Vector3.{0, 0, 1});

        end_suite(s);
    }

    // Every declared type must reach the table, or it would be unspawnable and
    // unsaveable with no diagnostic anywhere.
    test_entity_type_table :: () {
        s := begin_suite("entity type table");
        check(*s, "the table covers every declared type", ENTITY_TYPE_TABLE.count == ENTITY_TYPES.count);

        found_all := true;
        for type: ENTITY_TYPES  if get_entity_type_info(type) == null  found_all = false;
        check(*s, "every declared type is findable by type", found_all);

        names_match := true;
        for info: ENTITY_TYPE_TABLE  if info.name != entity_type_name(info.type)  names_match = false;
        check(*s, "table names match the type names saves use", names_match);

        // Entity itself is never a declared type, so it stands in for one that
        // this build does not have.
        check(*s, "an unknown type has no info",  get_entity_type_info(Entity) == null);
        check(*s, "an unknown type has no parts", get_entity_parts(Entity).count == 0);
        end_suite(s);
    }

    // Stallable because the type table is: ENTITY_TYPES only exists once the
    // metaprogram has seen every @Entity in the program.
    #run,stallable {
        test_entity_part_placement();
        test_entity_type_table();
    }
}

gen_entity_type_table :: () -> string {
    builder : String_Builder;
    append(*builder, "ENTITY_TYPE_TABLE :: Entity_Type_Info.[\n");
    for ENTITY_TYPES {
        ti := cast(*Type_Info_Struct) it;
        marker := "\"\"";
        for member: ti.members {
            if member.name == "EDITOR_MARKER" && (member.flags & .CONSTANT) {
                marker = tprint("%.EDITOR_MARKER", ti.name);
                break;
            }
        }
        print_to_builder(*builder,
            "    .{name = \"%\", type = %, parts = %.PARTS, editor_marker = %, create = () -> *Entity { return New(%); }},\n",
            ti.name, ti.name, ti.name, marker, ti.name);
    }
    append(*builder, "];\n");
    return builder_to_string(*builder);
}
