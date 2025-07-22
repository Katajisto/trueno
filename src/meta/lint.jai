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
	
	lint_ok := true;

		
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
