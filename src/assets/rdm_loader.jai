// RDM streaming helpers.
// The unified fetch queue lives in asset_manager.jai; these functions
// add and remove RDM entries from that shared queue.

#scope_export

rdm_loader_enqueue_world :: (world: *World) {
    for *chunk: world.chunks {
        if chunk.rdm_valid then continue;

        // Skip if this chunk is already in-flight on the RDM channel.
        af_rdm := *g_asset_manager.active[CHANNEL_RDM];
        if af_rdm.occupied {
            cf := af_rdm.req;
            if (cf.type == .RDM_ATLAS || cf.type == .RDM_LOOKUP) &&
               cf.world_name == world.name && cf.chunk_key == chunk.coord then continue;
        }

        // Skip if already queued (either as atlas or its follow-up lookup).
        already_queued := false;
        for g_asset_manager.rdm_queue {
            if (it.type == .RDM_ATLAS || it.type == .RDM_LOOKUP) &&
               it.world_name == world.name && it.chunk_key == chunk.coord {
                already_queued = true;
                break;
            }
        }
        if already_queued then continue;

        req : Fetch_Request;
        req.type       = .RDM_ATLAS;
        req.world_name = world.name;
        req.chunk_key  = chunk.coord;
        if chunk.rdm_atlas_path.count > 0 {
            req.path = sprint("%/worlds/%/%", GAME_RESOURCES_DIR, world.name, chunk.rdm_atlas_path);
        } else {
            req.path = rdm_chunk_filename(world.name, chunk.coord, "rdm_atlas");
        }
        array_add(*g_asset_manager.rdm_queue, req);
    }
}

// Remove all pending RDM fetches from the queue and invalidate any in-flight
// RDM fetch so its callback discards the result.
rdm_loader_cancel_all :: () {
    // Destroy any atlas images stored in queued RDM_LOOKUP requests, then drain.
    for i: 0..g_asset_manager.rdm_queue.count - 1 {
        item := g_asset_manager.rdm_queue[i];
        if item.rdm_pending_atlas.id != 0 then sg_destroy_image(item.rdm_pending_atlas);
    }
    array_reset(*g_asset_manager.rdm_queue);

    // Blank the world name on the in-flight RDM request so its callback discards.
    af := *g_asset_manager.active[CHANNEL_RDM];
    if af.occupied &&
       (af.req.type == .RDM_ATLAS || af.req.type == .RDM_LOOKUP) {
        if af.req.rdm_pending_atlas.id != 0 {
            sg_destroy_image(af.req.rdm_pending_atlas);
            af.req.rdm_pending_atlas = .{};
        }
        af.req.world_name = "";
    }
}
