// Text, as part of the Scene API. Fontstash lays out and rasterizes glyphs on
// the CPU into an atlas; the atlas is an ordinary Texture and the glyphs go into
// the UI stream as triangles, so nothing below the Scene API knows about fonts.

font_face_add :: (name: string, ttf: []u8) -> Font_Face {
    return .{fonsAddFontMem(text.fons, temp_c_string(name), ttf.data, xx ttf.count, 0)};
}

text_measure :: (face: Font_Face, size: float, s: string) -> float {
    if s.count < 1  return 0;
    fonsSetFont(text.fons, face.id);
    fonsSetSize(text.fons, size);
    return fonsTextBounds(text.fons, 0, 0, s.data, s.data + s.count, null);
}

text_vertical_metrics :: (face: Font_Face, size: float) -> (ascender: float, descender: float, line_height: float) {
    ascender, descender, line_height: float;
    fonsSetFont(text.fons, face.id);
    fonsSetSize(text.fons, size);
    fonsVertMetrics(text.fons, *ascender, *descender, *line_height);
    return ascender, descender, line_height;
}

// x, y is the left end of the baseline, in pixels from the top left.
ui_text :: (face: Font_Face, size: float, x: float, y: float, color: Vector4, s: string) {
    if s.count < 1  return;
    fonsSetFont(text.fons, face.id);
    fonsSetSize(text.fons, size);
    fonsSetColor(text.fons, pack_rgba8(color));
    fonsDrawText(text.fons, x, y, s.data, s.data + s.count);
}

text_init :: (atlas_size: s32) {
    params := FONSparams.{
        width        = atlas_size,
        height       = atlas_size,
        flags        = FONS_ZERO_TOPLEFT,
        renderCreate = atlas_create,
        renderResize = atlas_create,
        renderUpdate = atlas_mark_dirty,
        renderDraw   = glyphs_draw,
    };
    text.fons = fonsCreateInternal(*params);
}

// Drops every rasterized glyph, e.g. when UI font sizes change with the window.
text_reset_atlas :: () {
    fonsResetAtlas(text.fons, text.atlas_w, text.atlas_h);
}

// Before the UI stream is consumed: upload the atlas if glyphs were added.
text_end_frame :: () {
    fonsClearState(text.fons);
    if !text.atlas_dirty  return;
    text.atlas_dirty = false;

    w, h: s32;
    alpha := fonsGetTextureData(text.fons, *w, *h);
    for i: 0..w*h-1 {
        text.atlas_pixels[i*4 + 0] = 255;
        text.atlas_pixels[i*4 + 1] = 255;
        text.atlas_pixels[i*4 + 2] = 255;
        text.atlas_pixels[i*4 + 3] = alpha[i];
    }
    texture_update(text.atlas, text.atlas_pixels);
}

#scope_file

#import "Fontstash";

text : struct {
    fons         : *FONScontext;
    atlas        : Texture;
    atlas_w      : s32;
    atlas_h      : s32;
    atlas_pixels : []u8;
    atlas_dirty  : bool;
}

pack_rgba8 :: (c: Vector4) -> u32 {
    byte :: (f: float) -> u32 { return cast(u32) clamp(f * 255 + 0.5, 0, 255); }
    return byte(c.x) | (byte(c.y) << 8) | (byte(c.z) << 16) | (byte(c.w) << 24);
}

atlas_create :: (uptr: *void, width: s32, height: s32) -> s32 #c_call {
    push_context,defer_pop default_context;
    if text.atlas.id  texture_destroy(text.atlas);
    array_free(text.atlas_pixels);
    text.atlas_w      = width;
    text.atlas_h      = height;
    text.atlas_pixels = NewArray(width * height * 4, u8);
    text.atlas        = texture_create(width, height, text.atlas_pixels);
    text.atlas_dirty  = true;
    return 1;
}

atlas_mark_dirty :: (uptr: *void, rect: *s32, data: *u8) #c_call {
    text.atlas_dirty = true;
}

glyphs_draw :: (uptr: *void, verts: *float, tcoords: *float, colors: *u32, nverts: s32) #c_call {
    push_context,defer_pop default_context;
    vertices := NewArray(nverts, Ui_Vertex,, temp);
    for *v, i: vertices {
        c := colors[i];
        v.position = .{verts[i*2], verts[i*2 + 1]};
        v.uv       = .{tcoords[i*2], tcoords[i*2 + 1]};
        v.color    = .{
            cast(float)( c        & 0xFF) / 255,
            cast(float)((c >>  8) & 0xFF) / 255,
            cast(float)((c >> 16) & 0xFF) / 255,
            cast(float)((c >> 24) & 0xFF) / 255,
        };
    }
    ui_triangles(vertices, text.atlas);
}
