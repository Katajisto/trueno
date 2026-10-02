#import,dir "../../modules/sokol-jai/sokol/gfx"(DEBUG = !FLAG_RELEASE_BUILD);
#import,dir "../../modules/sokol-jai/sokol/glue"(DEBUG = !FLAG_RELEASE_BUILD);

#load "shaders/jai/ui.jai";
#load "ui.jai";

renderer_init :: () {
    sg_setup(*(sg_desc.{
        environment = cast,force(sg_environment) sglue_environment(),
        logger      = .{ func = slog_func },
    }));

    white := u8.[255, 255, 255, 255];
    renderer.white = make_image(1, 1, white);

    ui_init();
}

renderer_shutdown :: () {
    sg_shutdown();
}

renderer_texture_create :: (width: s32, height: s32, pixels: []u8) -> u32 {
    slot : *Renderer_Texture;
    index : int;
    if renderer.free_textures.count {
        index = pop(*renderer.free_textures);
        slot  = *renderer.textures[index];
    } else {
        index = renderer.textures.count;
        slot  = array_add(*renderer.textures);
    }
    slot.width  = width;
    slot.height = height;
    slot.image  = make_image(width, height, pixels);
    return xx (index + 1);
}

// Immutable images are recreated rather than updated, so a texture can be
// updated any number of times in a frame.
renderer_texture_update :: (id: u32, pixels: []u8) {
    slot := *renderer.textures[id - 1];
    sg_destroy_image(slot.image);
    slot.image = make_image(slot.width, slot.height, pixels);
}

renderer_texture_destroy :: (id: u32) {
    slot := *renderer.textures[id - 1];
    sg_destroy_image(slot.image);
    slot.* = .{};
    array_add(*renderer.free_textures, xx (id - 1));
}

renderer_render :: (scene: *Scene, width: s32, height: s32) {
    ui_upload(scene);

    pass_action : sg_pass_action;
    pass_action.colors[0] = .{ load_action = .CLEAR, clear_value = .{0, 0, 0, 1} };
    sg_begin_pass(*(sg_pass.{ action = pass_action, swapchain = cast,force(sg_swapchain) sglue_swapchain() }));
    ui_draw(scene, width, height);
    sg_end_pass();
    sg_commit();
}

texture_image :: (id: u32) -> sg_image {
    if id == 0  return renderer.white;
    return renderer.textures[id - 1].image;
}

#scope_file

Renderer_Texture :: struct {
    image  : sg_image;
    width  : s32;
    height : s32;
}

renderer : struct {
    textures      : [..]Renderer_Texture;
    free_textures : [..]s32;
    white         : sg_image;
}

make_image :: (width: s32, height: s32, pixels: []u8) -> sg_image {
    desc := sg_image_desc.{
        width        = width,
        height       = height,
        pixel_format = .RGBA8,
    };
    desc.data.subimage[0][0] = .{ pixels.data, xx pixels.count };
    return sg_make_image(*desc);
}
