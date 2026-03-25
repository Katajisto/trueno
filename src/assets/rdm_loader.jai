// RDM streaming helpers.
// The unified fetch queue lives in asset_manager.jai; these functions
// add and remove RDM entries from that shared queue.

#scope_export

rdm_loader_enqueue_world :: (world: *World) {
    for *chunk: world.chunks {
        if chunk.rdm_valid then continue;

        // Skip if this chunk is already in-flight.
        if g_asset_manager.is_fetching {
            cf := g_asset_manager.current_fetch;
            if (cf.type == .RDM_ATLAS || cf.type == .RDM_LOOKUP) &&
               cf.world_name == world.name && cf.chunk_key == chunk.coord then continue;
        }

        // Skip if already queued (either as atlas or its follow-up lookup).
        already_queued := false;
        for g_asset_manager.fetch_queue {
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
        array_add(*g_asset_manager.fetch_queue, req);
    }
}

// Remove all pending RDM fetches from the queue and invalidate any in-flight
// RDM fetch so its callback discards the result.
rdm_loader_cancel_all :: () {
    // Filter out RDM items, destroying any atlas images stored inside them.
    new_count := 0;
    for i: 0..g_asset_manager.fetch_queue.count - 1 {
        item := g_asset_manager.fetch_queue[i];
        if item.type == .RDM_ATLAS || item.type == .RDM_LOOKUP {
            if item.rdm_pending_atlas.id != 0 then sg_destroy_image(item.rdm_pending_atlas);
            continue;
        }
        g_asset_manager.fetch_queue[new_count] = item;
        new_count += 1;
    }
    g_asset_manager.fetch_queue.count = new_count;

    // Blank the world name on the in-flight request so its callback discards.
    if g_asset_manager.is_fetching &&
       (g_asset_manager.current_fetch.type == .RDM_ATLAS ||
        g_asset_manager.current_fetch.type == .RDM_LOOKUP) {
        if g_asset_manager.current_fetch.rdm_pending_atlas.id != 0 {
            sg_destroy_image(g_asset_manager.current_fetch.rdm_pending_atlas);
            g_asset_manager.current_fetch.rdm_pending_atlas = .{};
        }
        g_asset_manager.current_fetch.world_name = "";
    }
}
