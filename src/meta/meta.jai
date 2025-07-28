#load "ascii.jai";
#load "pack.jai";
#load "lint.jai";
#load "console_commands.jai";
#load "shaderload.jai";

custom_message_handler :: (message: *Message, w: *Workspace) {
    lint_checks(message);
    add_console_commands(message, w);
}
