#load "ascii.jai";
#load "../resource_mirror.jai";
#load "pack.jai";
#load "lint.jai";
#load "hacks.jai";
#load "console_commands.jai";
#load "entity_types.jai";
#load "shaderload.jai";

endframe_modified := false;
pointerimage_modified := false;

custom_message_handler :: (message: *Message, w: *Workspace) {
    lint_checks(message);

    remove_getrect_custom_cursor(message, w);
        
    add_console_commands(message, w);

    add_entity_types(message, w);
}
