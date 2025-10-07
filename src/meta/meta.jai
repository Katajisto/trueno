#load "ascii.jai";
#load "pack.jai";
#load "lint.jai";
#load "hacks.jai";
#load "console_commands.jai";
#load "shaderload.jai";

endframe_modified := false;
pointerimage_modified := false;

custom_message_handler :: (message: *Message, w: *Workspace) {
    lint_checks(message);

    remove_getrect_custom_cursor(message, w);
        
    add_console_commands(message, w);
}
