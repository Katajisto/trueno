#import,dir "../../modules/sokol-jai/sokol/app";
#import,dir "../../modules/sokol-jai/sokol/gfx";
#import,dir "../../modules/sokol-jai/sokol/gl";
#import,dir "../../modules/sokol-jai/sokol/glue";
#import,dir "../../modules/sokol-jai/sokol/shape";
#import,dir "../../modules/sokol-jai/sokol/fontstash";
#import,dir "../../modules/sokol-jai/sokol/log";
#import,dir "../../modules/sokol-jai/sokol/time";
#import,dir "../../modules/sokol-jai/sokol/fetch";

#load "../main.jai";

default_context: #Context;

temporary_storage: Temporary_Storage;
temporary_storage_data: [TEMPORARY_STORAGE_SIZE] u8 #align 64;

sapp_init :: () {
    default_context.temporary_storage = *temporary_storage;
    temporary_storage.data = temporary_storage_data.data;
    temporary_storage.size = temporary_storage_data.count;
    temporary_storage.original_data = temporary_storage_data.data;
    temporary_storage.original_size = temporary_storage_data.count;    

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
        sample_count = 4,
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

