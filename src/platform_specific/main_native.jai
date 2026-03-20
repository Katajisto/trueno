#load "common.jai";

main :: () {
    default_context = context;
    sapp_init();
}

logger :: (message: string, data: *void, info: Log_Info) {
    _logger_proc(message, data, info);
}
