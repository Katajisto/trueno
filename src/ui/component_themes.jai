t_label_left :: (theme: *GR.Overall_Theme) -> GR.Label_Theme {
    t := theme.label_theme;
    t.alignment = GR.Text_Alignment.Left;
    return t;
}
