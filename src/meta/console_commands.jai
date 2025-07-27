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

            if expression.flags & .SCOPE_FILE {
        	    compiler_report(sprint("Command % is file scoped, that is not okay. Commands must be exported.", expression.name), make_location(cast(*Code_Node)expression), .ERROR);
            }
            arg_count := header.arguments.count;
            arg_count_min := header.arguments.count;

            for arg, i : header.arguments {
                if arg.expression != null then arg_count_min -= 1;
            }


            builder : String_Builder;
            print_to_builder(*builder, "%__command_front :: (args: []string) -> string {\n", expression.name);
            print_to_builder(*builder, "if !verify_argument_count(%, %, args.count) return sprint(\"Wrong number of arguments! Expected \%, got \%.\", %, args.count);\n", arg_count_min, arg_count, arg_count);

            get_call_string :: (num: int) -> string {
                sep := "";
                call_args_builder : String_Builder;
                for 0..num-1 {
                    print_to_builder(*call_args_builder, "%xx a%", sep, it);
                    sep = ", ";
                }                
                return builder_to_string(*call_args_builder);
            }

            
            for arg, i : header.arguments {
                type_tag := arg.type_inst.result.type;
                arg_name := arg.name;
                if type_tag == {
                    case .INTEGER;
                        print_to_builder(*builder, "a% : int; success% : bool;\n", i, i);
                        print_to_builder(*builder, "if args.count > % {\n", i);
                        print_to_builder(*builder, "a%, success% = string_to_int(args[%]);\n", i, i, i);
                        print_to_builder(*builder, "if !success% then return sprint(\"Can't parse value \% for argument % at position % to type %.\", args[%]);\n", i, arg_name, i, type_tag, i);
                        print_to_builder(*builder, "}\n");
                    case .FLOAT;
                        print_to_builder(*builder, "a% : float; success% : bool;\n", i, i);
                        print_to_builder(*builder, "if args.count > % {\n", i);
                        print_to_builder(*builder, "a%, success% = string_to_float(args[%]);\n", i, i, i);
                        print_to_builder(*builder, "if !success% then return sprint(\"Can't parse value \% for argument % at position % to type %.\", args[%]);\n", i, arg_name, i, type_tag, i);
                        print_to_builder(*builder, "}\n");
                    case .BOOL;
                        print_to_builder(*builder, "a% : bool; success% : bool;\n", i, i);
                        print_to_builder(*builder, "if args.count > % {\n", i);
                        print_to_builder(*builder, "a%, success% = string_to_bool(args[%]);\n", i, i, i);
                        print_to_builder(*builder, "if !success% then return sprint(\"Can't parse value \% for argument % at position % to type %.\", args[%]);\n", i, arg_name, i, type_tag, i);
                        print_to_builder(*builder, "}\n");
                    case .STRING;
                        print_to_builder(*builder, "a% : string;;\n", i);
                        print_to_builder(*builder, "if args.count > % {\n", i);
                        print_to_builder(*builder, "a% := args[%];\n", i, i);
                        print_to_builder(*builder, "}\n");
                    case;
                	    compiler_report(sprint("Argument % is of type %, which is not handled by automatic command registration.", arg_name, type_tag), make_location(cast(*Code_Node)arg), .ERROR);
                }
            }
            for arg_count_min..arg_count {
                print_to_builder(*builder, "if args.count == % then return sprint(\"\%\", %(%));\n", it, expression.name, get_call_string(it));
            }
            print_to_builder(*builder, "return \"Something really really weird has happened. Your argument count somehow went trough all the return checks....\";\n");
            print_to_builder(*builder, "}\n");
            str := builder_to_string(*builder);
            array_add(*console_commands_to_register, sprint("%", expression.name));
            add_build_string(str, w.*);
            free(str);
    	}
	}
	return;
    
}
