t_label_left :: (theme: *GR.Overall_Theme) -> GR.Label_Theme {
    t := theme.label_theme;
    t.alignment = GR.Text_Alignment.Left;
    return t;
}

t_button_tab :: (theme: *GR.Overall_Theme, active: bool) -> GR.Button_Theme {
    t := theme.button_theme;

    t.rectangle_shape.rounding_flags = .NORTH;

    if active {
        t.surface_color = theme.button_theme.surface_color_down;
    }
    
    return t;
}
