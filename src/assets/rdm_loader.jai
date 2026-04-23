// RDM streaming helpers.
// The unified fetch queue lives in asset_manager.jai; these functions
// enqueue and cancel the world-level global RDM atlas + manifest.

#scope_export

rdm_loader_enqueue_world :: (world: *World) {
    already_atlas    := false;
    already_manifest := false;

    for g_asset_manager.slots {
        if !it.occupied continue;
        if it.req.world_name != world.name continue;
        if it.req.type == .RDM_ATLAS     then already_atlas    = true;
        if it.req.type == .RDM_MANIFEST  then already_manifest = true;
    }
    for g_asset_manager.queue {
        if it.world_name != world.name continue;
        if it.type == .RDM_ATLAS     then already_atlas    = true;
        if it.type == .RDM_MANIFEST  then already_manifest = true;
    }

    if !already_atlas {
        req : Fetch_Request;
        req.type       = .RDM_ATLAS;
        req.priority   = .LOADING_SCREEN;
        req.world_name = world.name;
        req.path       = rdm_global_atlas_filename(world.name);
        array_add(*g_asset_manager.queue, req);
    }
    if !already_manifest {
        req : Fetch_Request;
        req.type       = .RDM_MANIFEST;
        req.priority   = .LOADING_SCREEN;
        req.world_name = world.name;
        req.path       = rdm_global_manifest_filename(world.name);
        array_add(*g_asset_manager.queue, req);
    }
}

// Drain all pending RDM work.
rdm_loader_cancel_all :: () {
    new_count := 0;
    for i: 0..g_asset_manager.queue.count - 1 {
        item := g_asset_manager.queue[i];
        if item.type != .RDM_ATLAS && item.type != .RDM_MANIFEST {
            g_asset_manager.queue[new_count] = item;
            new_count += 1;
        }
    }
    g_asset_manager.queue.count = new_count;

    for *slot: g_asset_manager.slots {
        if !slot.occupied then continue;
        if slot.req.type != .RDM_ATLAS && slot.req.type != .RDM_MANIFEST then continue;
        slot.req.world_name = "";
    }
}
