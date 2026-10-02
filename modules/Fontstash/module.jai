// Fontstash with stb_truetype, as a plain C library: no rendering backend,
// glyphs reach the caller through FONSparams' render callbacks. Only the parts
// the engine uses are bound. Libraries are built with build.sh.

FONScontext :: struct {}

FONS_ZERO_TOPLEFT :: 1;

FONSparams :: struct {
    width, height : s32;
    flags         : u8;
    userPtr       : *void;
    renderCreate  : (uptr: *void, width: s32, height: s32) -> s32 #c_call;
    renderResize  : (uptr: *void, width: s32, height: s32) -> s32 #c_call;
    renderUpdate  : (uptr: *void, rect: *s32, data: *u8) #c_call;
    renderDraw    : (uptr: *void, verts: *float, tcoords: *float, colors: *u32, nverts: s32) #c_call;
    renderDelete  : (uptr: *void) #c_call;
}

fonsCreateInternal :: (params: *FONSparams) -> *FONScontext #foreign fontstash;
fonsResetAtlas     :: (s: *FONScontext, width: s32, height: s32) -> s32 #foreign fontstash;
fonsAddFontMem     :: (s: *FONScontext, name: *u8, data: *u8, ndata: s32, free_data: s32) -> s32 #foreign fontstash;
fonsClearState     :: (s: *FONScontext) #foreign fontstash;
fonsSetSize        :: (s: *FONScontext, size: float) #foreign fontstash;
fonsSetColor       :: (s: *FONScontext, color: u32) #foreign fontstash;
fonsSetFont        :: (s: *FONScontext, font: s32) #foreign fontstash;
fonsDrawText       :: (s: *FONScontext, x: float, y: float, str: *u8, end: *u8) -> float #foreign fontstash;
fonsTextBounds     :: (s: *FONScontext, x: float, y: float, str: *u8, end: *u8, bounds: *float) -> float #foreign fontstash;
fonsVertMetrics    :: (s: *FONScontext, ascender: *float, descender: *float, line_height: *float) #foreign fontstash;
fonsGetTextureData :: (s: *FONScontext, width: *s32, height: *s32) -> *u8 #foreign fontstash;

#scope_file

#if OS == .LINUX {
    fontstash :: #library,no_dll "linux/fontstash";
    #library,system,link_always "libm";
} else #if OS == .MACOS {
    fontstash :: #library,no_dll "macos/fontstash";
} else #if OS == .WASM {
    fontstash :: #library,no_dll "wasm/fontstash";
} else {
    #assert false "Fontstash has no library for this OS; see build.sh.";
}
