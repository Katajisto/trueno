#import,dir "../../modules/sokol-jai/sokol/gfx"(DEBUG = !FLAG_RELEASE_BUILD);
#import,dir "../../modules/sokol-jai/sokol/glue"(DEBUG = !FLAG_RELEASE_BUILD);
#import "Sort";

#load "shaders/jai/shaders.jai";
#load "gpu.jai";
#load "ui.jai";
#load "triles.jai";
#load "probes.jai";
#load "views.jai";
#load "water.jai";
#load "sprites.jai";
#load "sky.jai";
#load "lines.jai";

renderer_init :: (orientations: [ORIENTATION_COUNT]Matrix3) {
    sg_setup(*(sg_desc.{
        environment = cast,force(sg_environment) sglue_environment(),
        logger      = .{ func = slog_func },
        // Each view holds 10 attachments and 15 images; each trile mesh 2 buffers.
        attachments_pool_size = 64,
        image_pool_size       = 512,
        buffer_pool_size      = 1024,
    }));

    white := u8.[255, 255, 255, 255];
    renderer.white = make_image(1, 1, white);

    samplers_init();
    ui_init();
    triles_init(orientations);
    probes_init();
    views_init();
    water_init();
    sprites_init();
    sky_init();
    lines_init();
}

renderer_shutdown :: () {
    sg_shutdown();
}

renderer_texture_create :: (width: s32, height: s32, pixels: []u8) -> u32 {
    id, texture := slot_add(*renderer.textures);
    texture.width  = width;
    texture.height = height;
    texture.image  = make_image(width, height, pixels);
    return id;
}

// Immutable images are recreated rather than updated, so a texture can be
// updated any number of times in a frame.
renderer_texture_update :: (id: u32, pixels: []u8) {
    texture := slot_get(*renderer.textures, id);
    sg_destroy_image(texture.image);
    texture.image = make_image(texture.width, texture.height, pixels);
}

renderer_texture_destroy :: (id: u32) {
    sg_destroy_image(slot_get(*renderer.textures, id).image);
    slot_remove(*renderer.textures, id);
}

renderer_render :: (scene: *Scene, width: s32, height: s32) {
    triles_upload(scene);
    probes_upload();
    sprites_upload(scene);
    lines_upload(scene);
    ui_upload(scene);

    for view, view_index: scene.views {
        shadow := make_pass(scene, view_index, .SHADOW);
        view_begin_shadow_pass(view_index);
        triles_draw(*shadow);
        sprites_draw(*shadow, transparent = false);
        triles_draw_glass_shadow(*shadow);
        sg_end_pass();

        for kind: Pass_Kind.[.REFLECTION, .MAIN] {
            pass := make_pass(scene, view_index, kind);

            view_begin_pass(view_index, width, height, kind, opaque = true);
            sky_draw(*pass);
            water_draw_floor(*pass);
            triles_draw(*pass);
            sprites_draw(*pass, transparent = false);
            sg_end_pass();

            view_begin_pass(view_index, width, height, kind, opaque = false);
            water_draw(*pass);
            sprites_draw(*pass, transparent = true);
            lines_draw(*pass, width, height);
            sg_end_pass();

            if kind == .MAIN  view_shafts(*pass);
        }
        view_bloom(view_index);
    }

    action : sg_pass_action;
    action.colors[0] = .{ load_action = .CLEAR, clear_value = .{0, 0, 0, 1} };
    sg_begin_pass(*(sg_pass.{ action = action, swapchain = cast,force(sg_swapchain) sglue_swapchain() }));
    for scene.views  view_composite(it_index, view_environment(it));
    ui_draw(scene, width, height);
    sg_end_pass();
    sg_commit();
}

texture_image :: (id: u32) -> sg_image {
    texture := slot_get(*renderer.textures, id);
    if !texture || !texture.image.id  return renderer.white;
    return texture.image;
}

#scope_file

Renderer_Texture :: struct {
    image  : sg_image;
    width  : s32;
    height : s32;
}

renderer : struct {
    textures : Slots(Renderer_Texture);
    white    : sg_image;
}

make_image :: (width: s32, height: s32, pixels: []u8) -> sg_image {
    desc := sg_image_desc.{ width = width, height = height, pixel_format = .RGBA8 };
    desc.data.subimage[0][0] = .{ pixels.data, xx pixels.count };
    return sg_make_image(*desc);
}
