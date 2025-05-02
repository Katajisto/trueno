GR :: #import "GetRect_LeftHanded"()(Type_Indicator = Ui_Type_Indicator);
Input :: #import "Input";


Ui_Font_Glyph :: struct {
    advance : u32 = 1;
};

Ui_Font :: struct {
    em_width                       : int = 1;
    character_height               : int = 30;
    typical_descender              : int = 1;
    typical_ascender               : int = 1;
    fons_font                      : s32 = 0;
    temporary_glyphs               : [..]Ui_Font_Glyph;
    temporary_glyphs_byte_offsets  : [..]u32;
};

ui_init_font_fields :: (font: *Ui_Font) {
    m_str := "M";
    fonsSetFont(state.fons, xx font.fons_font);
    fonsSetSize(state.fons, xx font.character_height);

    ascender, descender, line_h : float;
    fonsVertMetrics(state.fons, *ascender, *descender, *line_h);
    
    font.typical_descender = cast(int) descender;
    font.typical_ascender  = cast(int) (ascender * 0.85); // @stupid fix to make the ascender not be so big.
    
    w := fonsTextBounds(state.fons, 0.0, 0.0, m_str.data, m_str.data + m_str.count, null);
    font.em_width = xx w;
}

Ui_Texture :: struct {
    tex: sg_image;
}

Ui_Rect :: struct {
    x, y, w, h: s32;  
};

Ui_Type_Indicator :: struct {
    Texture      : Type : Ui_Texture;
    Window_Type  : Type : s32;
    Font         : Type : Ui_Font;
    Font_Effects : Type : u32;
};

Font :: Ui_Font;

defaultFont: Font;

ui_texture_counter : u32 = 0;

texture_load_from_memory :: (texture: *Ui_Texture, memory: []u8, srgb: bool, build_mipmaps: bool) -> bool {
    x : s32;
    y : s32;
    channels : s32;
    data := stbi.stbi_load_from_memory(memory.data, xx memory.count, *x, *y, *channels, 4);
    img := sg_alloc_image();

    subimg : [6][16]sg_range;
    subimg[0][0] = .{
        ptr = data,
        size = xx (x * y * 4)
    };

    sg_init_image(*img, *(sg_image_desc.{
        width = x,
        height = y,
        pixel_format = sg_pixel_format.RGBA8,
        data = .{
            subimage = subimg
        }
    }));

    stbi.stbi_image_free(data);
    texture.tex = img;
    return true;
}

gScissor : Ui_Rect;
gScissorActive : bool = false;

get_render_size :: () -> (s32, s32) {
    return 700, 700;
}

set_scissor :: (x0: s32, y0: s32, x1: s32, y1: s32)  {
    w,h := get_render_size();
    gScissor = .{x0, y0, x1 - x0, y1 - y0};
    gScissorActive = true;
}
clear_scissor :: () {
    gScissorActive = false;
}

gCurrentTexture : *Ui_Texture = null;

set_shader_for_color :: (enable_blend := false) {
    gCurrentTexture = null;
}


set_shader_for_images :: (texture: *Ui_Texture) {
    gPipelines.arbtri.bind.images[0] = texture.tex;
    gCurrentTexture = texture;
}

gPreppedText: string;
gPreppedTextWidth : s32;

prepare_text :: (font: *Ui_Type_Indicator.Font, text: string, effects: Ui_Type_Indicator.Font_Effects = 0) -> s64 {
    fonsSetFont(state.fons, state.font_default.fons_font);
    fonsSetSize(state.fons, xx font.character_height);
    w := fonsTextBounds(state.fons, 0.0, 0.0, text.data, text.data + text.count, null);
    gPreppedText = text;
    gPreppedTextWidth = cast(s32) w;

    array_reset(*font.temporary_glyphs);
    array_reset(*font.temporary_glyphs_byte_offsets);

    for 0..(text.count-1) {
        glyph : Ui_Font_Glyph;

        glyph.advance = cast(u32) fonsTextBounds(state.fons, 0.0, 0.0, text.data + it, text.data + it + 1, null);
        
        array_add(*font.temporary_glyphs, glyph);
        array_add(*font.temporary_glyphs_byte_offsets, cast(u32) it);
    }
    
    return cast(s64) w;
}
draw_prepared_text :: (font: *Ui_Type_Indicator.Font, x: s64, y: s64, text_color: Vector4, effects: Ui_Type_Indicator.Font_Effects = 0) {
    color := sfons_rgba(xx (255.0 * text_color.x), xx (255.0 * text_color.y), xx (255.0 * text_color.z), xx (255.0 * text_color.w));
    fonsSetColor(state.fons, color);
    result := cast(*u8) temporary_alloc(gPreppedText.count + 1);  // Add 1 for the zero.
    memcpy(result, gPreppedText.data, gPreppedText.count);
    result[gPreppedText.count] = 0;
    fonsDrawText(state.fons, xx x, xx y, result, null);
}
get_mouse_pointer_position :: (window: Ui_Type_Indicator.Window_Type, right_handed: bool) -> (x: int, y: int, success: bool) {
    return xx input_mouse_x, xx input_mouse_y, true;
}
get_font_at_size :: (memory: [] u8, pixel_height: int) -> *Font {
    f : *Font = New(Font);
    f.character_height = cast(u32) pixel_height;
    ui_init_font_fields(f);
    return f;
}

// TODO: Figure out what to do with the normal?
immediate_triangle :: (p0: Vector3, p1: Vector3, p2: Vector3, c0 := Vector4.{1,1,1,1}, c1 := Vector4.{1,1,1,1}, c2 := Vector4.{1,1,1,1}, uv0 := Vector2.{}, uv1 := Vector2.{}, uv2 := Vector2.{}, normal := Vector3.{z=1}) {
    tri: Arb_Tri;
    tri.pos[0] = p0;
    tri.pos[1] = p1;
    tri.pos[2] = p2;

    tri.col[0] = c0;
    tri.col[1] = c1;
    tri.col[2] = c2;
    
    // This UV symbolizes that the sampler should not be used.
    nullUV : Vector2 = .{-4, -2};

    if gCurrentTexture == null {
        tri.uv[0] = nullUV;
        tri.uv[1] = nullUV;
        tri.uv[2] = nullUV;
    } else {
        tri.uv[0] = uv0;
        tri.uv[1] = uv1;
        tri.uv[2] = uv2;
    }

    arb_tri_add(tri);
}

immediate_quad :: (p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, color := Vector4.{1,1,1,1}, uv0 := Vector2.{0,0}, uv1 := Vector2.{1,0}, uv2 := Vector2.{1,1}, uv3 := Vector2.{0, 1}) {
    to_3d_vec :: (v: Vector2) -> Vector3 {
        return .{v.x, v.y, 0.0};
    }
    immediate_triangle(to_3d_vec(p0), to_3d_vec(p1), to_3d_vec(p2), color, color, color, uv0, uv1, uv2);
    immediate_triangle(to_3d_vec(p0), to_3d_vec(p2), to_3d_vec(p3), color, color, color, uv0, uv2, uv3);
}

immediate_flush :: () {
    // arb_tri_flush();
}

init_ui :: () {
    dp : GR.Draw_Procs = .{
        texture_load_from_memory = texture_load_from_memory, // implemented 
        set_scissor = set_scissor,
        clear_scissor = clear_scissor,
        set_shader_for_color = set_shader_for_color, // implemented
        set_shader_for_images = set_shader_for_images,
        prepare_text = prepare_text, // implemented
        draw_prepared_text = draw_prepared_text, // implemented
        get_mouse_pointer_position = get_mouse_pointer_position, // implemented
        get_font_at_size = get_font_at_size, // implemented
        immediate_triangle = immediate_triangle, // implemented
        immediate_quad = immediate_quad, // implemented
        immediate_flush = immediate_flush // implemented
    };

    GR.ui_init("", *dp);
}

ui_events : [..]Input.Event;

add_ui_event :: (event: Input.Event) {
    array_add(*ui_events, event);
}

tick_ui :: () {
    w,h :=  get_window_size();
    for ui_events {
        GR.getrect_handle_event(it);
    }
    array_reset_keeping_memory(*ui_events);
    GR.ui_per_frame_update(1, xx w, xx h, get_time());
}

checkboxTest : bool = false;

get_font_at_size :: (pixel_height: int) -> *Font {
    list : []u8;
    return get_font_at_size(list, pixel_height);
}

idk : bool;

test_color : Vector3 = .{1.0, 0.0, 1.0};

render_ui :: () {
    proc := GR.default_theme_procs[0];
    my_theme := proc();
    GR.set_default_theme(my_theme);

    r := GR.get_rect(10, 10, 400, 30);
    pressed := GR.button(r, "GetRect render lfg!!", *my_theme.button_theme);
    if pressed {
    }

    r.y += 50;

    GR.text_input(r, "TTT", *my_theme.text_input_theme);
    
    r.y += 150;
    if GR.base_checkbox(r, "CHECK!!!", idk, null) {
        idk = !idk;
    }
    
    r.y += 150;
    r.h = 500;

    GR.color_picker(r, *test_color);
}


