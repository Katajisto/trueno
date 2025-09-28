#load "ascii.jai";
#load "pack.jai";
#load "lint.jai";
#load "console_commands.jai";
#load "shaderload.jai";

endframe_modified := false;
pointerimage_modified := false;

// This function is causing issues and I don't want to deal with it.
remove_getrect_custom_cursor :: (message: *Message, w: *Workspace) {
    if message.kind == {
      case .TYPECHECKED;
        tc_message := cast(*Message_Typechecked) message;
        for tc : tc_message.procedure_bodies {
            body := tc.expression;
            assert(body.block != null);
            if body.header.name == "pointer_end_frame" && !endframe_modified {
                print("Found and killed %\n", body.header.name);
                new_statements : [..] *Code_Node;
                body.block.statements = new_statements;
                compiler_modify_procedure(message.workspace, body);
                endframe_modified = true;
            }
            if body.header.name == "getrect_set_pointer_image" && !pointerimage_modified {
                print("Found and killed %\n", body.header.name);
                new_statements : [..] *Code_Node;
                body.block.statements = new_statements;
                compiler_modify_procedure(message.workspace, body);
                pointerimage_modified = true;
            }
        }
    }

}

custom_message_handler :: (message: *Message, w: *Workspace) {
    lint_checks(message);

    remove_getrect_custom_cursor(message, w);
        
    add_console_commands(message, w);
}
