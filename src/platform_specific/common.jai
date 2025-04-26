#import,dir "../../modules/sokol-jai/sokol/app";
#import,dir "../../modules/sokol-jai/sokol/gfx";
#import,dir "../../modules/sokol-jai/sokol/gl";
#import,dir "../../modules/sokol-jai/sokol/glue";
#import,dir "../../modules/sokol-jai/sokol/fontstash";
#import,dir "../../modules/sokol-jai/sokol/log";
#import,dir "../../modules/sokol-jai/sokol/time";
#import,dir "../../modules/sokol-jai/sokol/fetch";

#load "../main.jai";

default_context: #Context;

sapp_init :: () {
    push_context,defer_pop default_context;
    context.logger = logger;

    wi := get_window_info();

    sapp_run(*(sapp_desc.{
        init_cb = init_plat,
        frame_cb = frame_plat,
        cleanup_cb = cleanup_plat,
        event_cb = event_plat,
        width = wi.width,
        height = wi.height,
        window_title = wi.title,
        // icon = .{ sokol_default = true },
        logger = .{ func = slog_func },
    }));
}

init_plat :: () #c_call {
    push_context,defer_pop default_context;
    init();
}

frame_plat :: () #c_call {
    push_context,defer_pop default_context;
    frame();
}

event_plat :: (e: *sapp_event) #c_call {
    push_context,defer_pop default_context;
    handle_event(e);
}

cleanup_plat :: () #c_call {
    push_context,defer_pop default_context;
    cleanup();
}

