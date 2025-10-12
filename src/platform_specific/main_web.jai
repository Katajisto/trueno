#load "common.jai";

#program_export
_main :: () #c_call {
    push_context,defer_pop default_context;
    sapp_init();
}

log_warn :: (format_string: string, args: .. Any, loc := #caller_location, flags := Log_Flags.NONE, user_flags : u32 = 0, section : *Log_Section = null) {
    log(format_string, ..args, loc = loc, flags = flags | .WARNING, user_flags = user_flags, section = section);
} @PrintLike

log_content :: (format_string: string, args: .. Any, loc := #caller_location, flags := Log_Flags.NONE, user_flags : u32 = 0, section : *Log_Section = null) {
    log(format_string, ..args, loc = loc, flags = flags | .CONTENT, user_flags = user_flags, section = section);
} @PrintLike

logger :: (message: string, data: *void, info: Log_Info) {
    // wasm_write_string :: (count: s64, data: *void, log_flag: Log_Flags) #foreign; // You will need to provide this function as JS code in your WASM environment. :JaiWasm:
    // wasm_write_string(message.count, message.data, info.common_flags);
}
