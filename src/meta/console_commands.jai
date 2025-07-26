console_commands_to_register : [..]string;

add_console_registration_code :: (w: *Workspace) {
    builder : String_Builder;
    print_to_builder(*builder, "register_commands :: () {\n");
    for console_commands_to_register {
        print_to_builder(*builder, "array_add(*console_command_procs, %__command_front);\n", it);
        print_to_builder(*builder, "array_add(*console_command_names, \"%\");\n", it);
    }
    print_to_builder(*builder, "}\n");
    add_build_string(builder_to_string(*builder), w.*);
}

add_console_commands :: (message: *Message, w: *Workspace) {
    if message.kind == .PHASE {
        phase_message := cast(*Message_Phase) message;
        if phase_message.phase == .TYPECHECKED_ALL_WE_CAN {
            if console_commands_to_register.count > 0 {
                add_console_registration_code(w);
                array_reset(*console_commands_to_register);
            }
        }
    }
    if message.kind != .TYPECHECKED then return;
    code := cast(*Message_Typechecked) message;

    all_commands_builder : String_Builder;

	for code.declarations {
		import := it.expression.enclosing_load.enclosing_import;
        expression := it.expression;
    	if expression.expression && expression.expression.kind == .PROCEDURE_HEADER {
            header := cast(*Code_Procedure_Header) expression.expression;
            is_command := false;
            for expression.notes {
                if it.text == "Command" {
                    is_command = true;
                }
            }
            if !is_command then continue;
            print("Found console command called: %\n", expression.name);

            if expression.flags & .SCOPE_FILE {
        	    compiler_report(sprint("Command % is file scoped, that is not okay. Commands must be exported.", expression.name), make_location(cast(*Code_Node)expression), .ERROR);
            }

            // @ToDo: Count argument range properly.
            arg_count := header.arguments.count;

            builder : String_Builder;
            print_to_builder(*builder, "%__command_front :: (args: []string) -> string {\n", expression.name);
            print_to_builder(*builder, "if !verify_argument_count(%, %, args.count) return sprint(\"Wrong number of arguments! Expected \%, got \%.\", %, args.count);\n", arg_count, arg_count, arg_count);
            print_to_builder(*builder, "return sprint(\"\%\", %());\n", expression.name);
            print_to_builder(*builder, "}\n");
            str := builder_to_string(*builder);
            print("%\n", str);
            array_add(*console_commands_to_register, sprint("%", expression.name));
            add_build_string(str, w.*);
            free(str);
    	}
	}
	return;
    
}
