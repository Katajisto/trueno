Log_Level :: enum {
    DEBUG;
    INFO;
    WARN;
    ERROR;
}

log_min_level : Log_Level = .INFO;

#scope_file

_emit :: (level: Log_Level, message: string) {
    if level < log_min_level return;

    prefix := ifx level == .DEBUG then "[DEBUG] "
              else ifx level == .WARN  then "[WARN]  "
              else ifx level == .ERROR then "[ERROR] "
              else                          "[INFO]  ";

    // Always allocate on the heap regardless of context.allocator (e.g. mesh pool).
    old_alloc := context.allocator;
    context.allocator = default_context.allocator;
    line := copy_string(tprint("%1%2", prefix, message));
    context.allocator = old_alloc;

    print("%\n", line);
    console_add_output_line(line);
}

#scope_export

logger :: (level: Log_Level, fmt: string, args: ..Any) {
    if level < log_min_level return;
    _emit(level, tprint(fmt, ..args));
}

// Hook for Jai's context.logger — catches log() calls from Basic and libraries.
_logger_proc :: (message: string, data: *void, info: Log_Info) {
    level : Log_Level;
    if info.common_flags & .ERROR                                                      then level = .ERROR;
    else if info.common_flags & .WARNING                                               then level = .WARN;
    else if (info.common_flags & .VERBOSE_ONLY) || (info.common_flags & .VERY_VERBOSE_ONLY) then level = .DEBUG;
    else                                                                               level = .INFO;
    _emit(level, message);
}

log_debug :: (fmt: string, args: ..Any) { logger(.DEBUG, fmt, ..args); }
log_info  :: (fmt: string, args: ..Any) { logger(.INFO,  fmt, ..args); }
log_warn  :: (fmt: string, args: ..Any) { logger(.WARN,  fmt, ..args); }
log_error :: (fmt: string, args: ..Any) { logger(.ERROR, fmt, ..args); }

set_log_level :: (level_str: string) -> string {
    if level_str == {
        case "DEBUG"; log_min_level = .DEBUG;
        case "INFO";  log_min_level = .INFO;
        case "WARN";  log_min_level = .WARN;
        case "ERROR"; log_min_level = .ERROR;
        case; return tprint("Unknown log level '%'. Use DEBUG, INFO, WARN or ERROR.", level_str);
    }
    return tprint("Log level set to %.", level_str);
} @Command
