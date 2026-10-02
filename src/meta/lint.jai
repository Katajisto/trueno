/*
	Custom linting rules to maintain some style things in the
	engine, just so I don't forget to follow the style I want to follow,
	mostly with function names and variable names.
*/

lint_errors_found := 0;

lint_checks :: (message: *Message) -> bool {
	// We are only interested declarations being typechecked, and we'll look at
	// them after typechecking.
    if message.kind != .TYPECHECKED then return true;
    code := cast(*Message_Typechecked) message;
	
	lint_ok := lint_sokol_graphics(code);

	for code.declarations {
		import := it.expression.enclosing_load.enclosing_import;
		if import.module_type != .MAIN_PROGRAM then return true;
		if !lint_declaration(it.expression) {
			lint_ok = false;
		}
	}
	return lint_ok;
}

lint_declaration :: (expression: Code_Declaration) -> bool {
	if expression.expression && expression.expression.kind == .PROCEDURE_HEADER {
		return lint_procedure_name(expression.name, expression.expression);
	}
	return true;
}

lint_procedure_name :: (name: string, node: Code_Node) -> bool {
	name_ok := true;
	wrong_char : u8;
	for name {
		if it >= #char "a" && it <= #char "z" then continue;
		if it == #char "_" then continue;
		if it == #char "+" then continue;
		if it == #char "=" then continue;
		if it == #char "<" then continue;
		if it == #char ">" then continue;
		if it >= #char "0" && it <= #char "9" then continue;
		name_ok = false;
		wrong_char = it;
		break;
	}
	if !name_ok {
		error := sprint("Linter: Name % contains illegal char % for procedure names\n", name, wrong_char);
	    compiler_report(error, make_location(*node), .ERROR);
		lint_errors_found += 1;
		return false;
	} else {
		return true;
	}
}

lint_sokol_graphics :: (code: *Message_Typechecked) -> bool {
	SOKOL_GRAPHICS_MODULES :: string.["gfx", "glue", "gl", "shape", "debugtext", "fontstash"];

	is_sokol_graphics :: (path: string) -> bool {
		for SOKOL_GRAPHICS_MODULES {
			if contains(path, tprint("/sokol-jai/sokol/%/", it)) then return true;
		}
		return false;
	}

	ok := true;
	for code.all {
		load := it.expression.enclosing_load;
		if !load || !load.enclosing_import || load.enclosing_import.module_type != .MAIN_PROGRAM then continue;
		if contains(load.fully_pathed_filename, "/renderer_sokol/") then continue;
		in_scene := ends_with(load.fully_pathed_filename, "/rendering/scene.jai");

		for sub: it.subexpressions {
			if sub.kind != .IDENT then continue;
			decl := (cast(*Code_Ident) sub).resolved_declaration;
			if !decl || !decl.enclosing_load then continue;
			decl_path := decl.enclosing_load.fully_pathed_filename;
			if is_sokol_graphics(decl_path) {
				compiler_report(sprint("Linter: % is sokol graphics; only src/renderer_sokol/ may use it\n", decl.name), make_location(sub), .ERROR);
			} else if contains(decl_path, "/renderer_sokol/") && !in_scene {
				compiler_report(sprint("Linter: % is part of the renderer; only src/rendering/scene.jai may use it\n", decl.name), make_location(sub), .ERROR);
			} else {
				continue;
			}
			lint_errors_found += 1;
			ok = false;
		}
	}
	return ok;
}
