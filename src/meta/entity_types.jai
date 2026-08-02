/*
	Entity types register themselves with an @Entity note on the struct, the same
	way console commands register with @Command. The generators in entities.jai
	all read one list, ENTITY_TYPES, which is built here and injected once the
	rest of the program has been typechecked — that is why those generators are
	written as #run,stallable.
*/

#import "Sort";

entity_type_names    : [..]string;
entity_types_emitted := false;

add_entity_types :: (message: *Message, w: *Workspace) {
	if message.kind == .PHASE {
		phase := cast(*Message_Phase) message;
		if phase.phase == .TYPECHECKED_ALL_WE_CAN && !entity_types_emitted {
			entity_types_emitted = true;
			emit_entity_types(w);
		}
		return;
	}

	if message.kind != .TYPECHECKED then return;
	code := cast(*Message_Typechecked) message;

	for code.declarations {
		decl := it.expression;
		if !decl.expression || decl.expression.kind != .STRUCT then continue;
		if !is_main_program(decl) then continue;

		noted := false;
		for note: decl.notes  if note.text == "Entity"  noted = true;
		embeds := struct_embeds_entity(cast(*Code_Struct) decl.expression);

		// Without this the note is as easy to forget as the hand-written list it
		// replaced, and forgetting it is silent: the type compiles fine and is
		// simply invisible to spawning, the editor and saving.
		if embeds && !noted {
			report(decl, sprint("Struct % embeds Entity but is not marked @Entity, so nothing can spawn, edit or save it.", decl.name));
			continue;
		}
		if !noted then continue;

		if !embeds {
			report(decl, sprint("Struct % is marked @Entity but has no '#as using base : Entity;'.", decl.name));
			continue;
		}
		if decl.flags & .SCOPE_FILE {
			report(decl, sprint("Entity type % is file scoped, that is not okay. The generated type table has to name it.", decl.name));
			continue;
		}

		array_add(*entity_type_names, sprint("%", decl.name));
	}
}

#scope_file

// Emitted even when the game declares no entity types at all: the generators in
// entities.jai are stalled waiting for this name and would never come unstuck.
emit_entity_types :: (w: *Workspace) {
	// Sorted by name so the generated table — and with it the order of the
	// editor's spawn list — does not shuffle between builds just because
	// typechecking happened to finish in a different order.
	quick_sort(entity_type_names, compare_strings);

	builder : String_Builder;
	append(*builder, "ENTITY_TYPES :: Type.[");
	for entity_type_names {
		if it_index > 0 then append(*builder, ", ");
		append(*builder, it);
	}
	append(*builder, "];\n");
	add_build_string(builder_to_string(*builder), w.*);
}

struct_embeds_entity :: (s: *Code_Struct) -> bool {
	if !s.defined_type then return false;
	for s.defined_type.members {
		if !(it.flags & .USING) then continue;
		if it.type.type != .STRUCT then continue;
		if (cast(*Type_Info_Struct) it.type).name == "Entity" then return true;
	}
	return false;
}

// Game and engine code only. Module code never declares entity types, and
// build strings have no enclosing load to ask about.
is_main_program :: (decl: *Code_Declaration) -> bool {
	if !decl.enclosing_load then return false;
	if !decl.enclosing_load.enclosing_import then return false;
	return decl.enclosing_load.enclosing_import.module_type == .MAIN_PROGRAM;
}

report :: (decl: *Code_Declaration, error: string) {
	compiler_report(error, make_location(cast(*Code_Node) decl), .ERROR);
}
