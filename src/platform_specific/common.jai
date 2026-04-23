#import,dir "../../modules/sokol-jai/sokol/app"(DEBUG = !FLAG_RELEASE_BUILD);
#import,dir "../../modules/sokol-jai/sokol/gfx"(DEBUG = !FLAG_RELEASE_BUILD);
#import,dir "../../modules/sokol-jai/sokol/gl"(DEBUG = !FLAG_RELEASE_BUILD);
#import,dir "../../modules/sokol-jai/sokol/glue"(DEBUG = !FLAG_RELEASE_BUILD);
#import,dir "../../modules/sokol-jai/sokol/shape"(DEBUG = !FLAG_RELEASE_BUILD);
#import,dir "../../modules/sokol-jai/sokol/fontstash";
#import,dir "../../modules/sokol-jai/sokol/log"(DEBUG = !FLAG_RELEASE_BUILD);
#import,dir "../../modules/sokol-jai/sokol/time"(DEBUG = !FLAG_RELEASE_BUILD);
#import,dir "../../modules/sokol-jai/sokol/fetch"(DEBUG = !FLAG_RELEASE_BUILD);
#import,dir "../../modules/sokol-jai/sokol/audio"(DEBUG = !FLAG_RELEASE_BUILD);

#load "../main.jai";

default_context: #Context;
default_allocator: Allocator;

temporary_storage: Temporary_Storage;
temporary_storage_data: [TEMPORARY_STORAGE_SIZE] u8 #align 64;

sapp_init :: () {
    platconf := get_plat_conf();
    default_context.temporary_storage = *temporary_storage;
    temporary_storage.data = temporary_storage_data.data;
    temporary_storage.size = temporary_storage_data.count;
    temporary_storage.original_data = temporary_storage_data.data;
    temporary_storage.original_size = temporary_storage_data.count;    
    default_allocator = default_context.allocator;

    push_context default_context {
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
        sample_count = 1, // I think I'll end up pixelifying the whole thing, so I don't think we need MSAA.
    }));
    }
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

Platform_Conf :: struct {
    sample_count: s32;
}

get_plat_conf :: () -> Platform_Conf {
    #if OS == .WASM {
        return .{
            sample_count = 1,  
        };
    }
    #if OS == .LINUX {
        return .{
            sample_count = 4,  
        };
    }
    #if OS == .MACOS {
        return .{
            sample_count = 4,  
        };
    }
}
