Voxel_Theme_Config :: struct {
    primary_color    : Vector4 = .{1.0, 0.95, 0.65, 1.0};  // accent, selection, slider fill
    on_primary_color : Vector4 = .{0.08, 0.06, 0.03, 1.0};  // text on primary-colored surfaces
    text_color       : Vector4 = .{0.55, 0.65, 0.7,  1.0};  // normal text
    bg_color         : Vector4 = .{0.05, 0.08, 0.12, 1.0};  // large backgrounds
    surface_color    : Vector4 = .{0.13, 0.16, 0.22, 1.0};  // widget panel / button BG
    frame_color      : Vector4 = .{0.25, 0.30, 0.38, 0.5};  // widget borders
}

g_voxel_theme_config : Voxel_Theme_Config;

set_voxel_theme_config :: (cfg: Voxel_Theme_Config) {
    g_voxel_theme_config = cfg;
}

#scope_file

voxel_shape_framed : GR.Rectangle_Shape;
voxel_shape_bare   : GR.Rectangle_Shape;

apply_voxel_btn :: (t: *GR.Button_Theme, cfg: Voxel_Theme_Config, with_frame: bool) {
    shape := ifx with_frame then voxel_shape_framed else voxel_shape_bare;
    surface_over := Vector4.{cfg.surface_color.x + 0.07, cfg.surface_color.y + 0.07, cfg.surface_color.z + 0.07, 1.0};
    surface_down := Vector4.{cfg.surface_color.x * 0.7, cfg.surface_color.y * 0.7, cfg.surface_color.z * 0.7, 1.0};
    frm_over     := Vector4.{cfg.primary_color.x, cfg.primary_color.y, cfg.primary_color.z, 0.6};

    t.rectangle_shape     = shape;
    t.surface_color       = cfg.surface_color;
    t.surface_color_over  = surface_over;
    t.surface_color_down  = surface_down;
    t.surface_color_flash = surface_over;
    t.frame_color         = cfg.frame_color;
    t.frame_color_over    = frm_over;
    t.frame_color_down    = frm_over;
    t.frame_color_flash   = frm_over;
    t.text_color          = cfg.text_color;
    t.text_color_over     = cfg.primary_color;
    t.text_color_pressed  = cfg.primary_color;
}

#scope_export

get_voxel_theme :: () -> GR.Overall_Theme {
    cfg := g_voxel_theme_config;

    voxel_shape_framed.roundedness          = 0.0;
    voxel_shape_framed.frame_thickness_type = .ABSOLUTE_FROM_THEME_FIELD;
    voxel_shape_framed.frame_thickness      = 1.0;

    voxel_shape_bare.roundedness          = 0.0;
    voxel_shape_bare.frame_thickness_type = .ABSOLUTE_FROM_THEME_FIELD;
    voxel_shape_bare.frame_thickness      = 0.0;

    base_proc := GR.default_theme_procs[0];
    t := base_proc();

    apply_voxel_btn(*t.button_theme, cfg, true);

    // Propagate button theme to checkbox and dropdown before per-widget overrides
    t.checkbox_theme.button_theme               = t.button_theme;
    t.checkbox_theme.button_color_selected      = cfg.primary_color;
    t.checkbox_theme.text_color                 = cfg.text_color;
    t.checkbox_theme.text_color_over            = cfg.primary_color;
    t.checkbox_theme.text_color_pressed         = cfg.primary_color;

    apply_voxel_btn(*t.dropdown_theme.theme_for_current_value,  cfg, true);
    apply_voxel_btn(*t.dropdown_theme.theme_for_each_choice,    cfg, true);
    apply_voxel_btn(*t.dropdown_theme.theme_for_current_choice, cfg, true);
    t.dropdown_theme.theme_for_current_choice.surface_color      = cfg.primary_color;
    t.dropdown_theme.theme_for_current_choice.surface_color_over = cfg.primary_color;
    t.dropdown_theme.theme_for_current_choice.text_color         = cfg.on_primary_color;
    t.dropdown_theme.theme_for_current_choice.text_color_over    = cfg.on_primary_color;

    // Slider
    apply_voxel_btn(*t.slider_theme.foreground, cfg, false);
    t.slider_theme.foreground.surface_color       = cfg.primary_color;
    t.slider_theme.foreground.surface_color_over  = cfg.primary_color;
    t.slider_theme.foreground.surface_color_down  = cfg.primary_color;
    t.slider_theme.foreground.surface_color_flash = cfg.primary_color;
    t.slider_theme.foreground.frame_color         = .{0, 0, 0, 0};
    t.slider_theme.foreground.frame_color_over    = .{0, 0, 0, 0};
    t.slider_theme.foreground.text_color          = cfg.on_primary_color;
    t.slider_theme.foreground.text_color_over     = cfg.on_primary_color;
    t.slider_theme.foreground.text_color_pressed  = cfg.on_primary_color;

    sld_bg := Vector4.{cfg.bg_color.x + 0.05, cfg.bg_color.y + 0.05, cfg.bg_color.z + 0.07, 1.0};
    apply_voxel_btn(*t.slider_theme.background, cfg, true);
    t.slider_theme.background.surface_color       = sld_bg;
    t.slider_theme.background.surface_color_over  = sld_bg;
    t.slider_theme.background.surface_color_down  = sld_bg;
    t.slider_theme.background.surface_color_flash = sld_bg;
    t.slider_theme.background.frame_color         = cfg.frame_color;
    t.slider_theme.background.frame_color_over    = cfg.frame_color;

    apply_voxel_btn(*t.slider_theme.spinbox_theme, cfg, true);

    t.slider_theme.surface_style  = .EXTEND_FROM_LEFT;
    t.slider_theme.surface_margin = 0.08;
    t.slider_theme.use_spinboxes  = false;
    t.slider_theme.text_editable  = false;

    // Scrollable region
    srt := *t.scrollable_region_theme;
    apply_voxel_btn(*srt.scrollbar_nib_theme, cfg, false);
    srt.scrollbar_nib_theme.surface_color       = cfg.surface_color;
    srt.scrollbar_nib_theme.surface_color_over  = Vector4.{cfg.surface_color.x + 0.07, cfg.surface_color.y + 0.07, cfg.surface_color.z + 0.07, 1.0};
    srt.scrollbar_nib_theme.surface_color_down  = cfg.primary_color;
    srt.scrollbar_nib_theme.surface_color_flash = cfg.primary_color;
    srt.scrollbar_nib_theme.frame_color         = cfg.frame_color;
    srt.scrollbar_nib_theme.frame_color_over    = .{cfg.primary_color.x, cfg.primary_color.y, cfg.primary_color.z, 0.6};
    srt.scrollbar_nib_theme.rectangle_shape.roundedness_type = .ABSOLUTE_FROM_THEME_FIELD;
    srt.scrollbar_nib_theme.rectangle_shape.roundedness      = 0;

    srt.region_background.color             = cfg.bg_color;
    srt.region_background.frame_color       = cfg.frame_color;
    srt.region_background.shape.roundedness_type = .ABSOLUTE_FROM_THEME_FIELD;
    srt.region_background.shape.roundedness      = 0;
    srt.region_background.shape.rounding_flags   = 0;

    scroll_bar_bg := Vector4.{cfg.bg_color.x + 0.04, cfg.bg_color.y + 0.04, cfg.bg_color.z + 0.05, 1.0};
    srt.scrollbar_background.color             = scroll_bar_bg;
    srt.scrollbar_background.frame_color       = cfg.frame_color;
    srt.scrollbar_background.shape.roundedness_type = .ABSOLUTE_FROM_THEME_FIELD;
    srt.scrollbar_background.shape.roundedness      = 0;
    srt.scrollbar_background.shape.rounding_flags   = 0;

    // Label
    t.label_theme.text_color = cfg.text_color;

    t.background_color        = cfg.bg_color;
    t.background_color_bright = Vector4.{cfg.bg_color.x + 0.05, cfg.bg_color.y + 0.05, cfg.bg_color.z + 0.07, 1.0};
    t.text_color              = cfg.text_color;
    t.title_bar_color         = Vector4.{cfg.surface_color.x, cfg.surface_color.y, cfg.surface_color.z + 0.05, 1.0};
    t.title_bar_color_hilit   = Vector4.{cfg.primary_color.x*0.3, cfg.primary_color.y*0.25, cfg.primary_color.z*0.15, 1.0};

    return t;
}
