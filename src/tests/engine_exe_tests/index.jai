engine_exe_tests_add :: () {
    start_test_suite("Settings menu");
    start_test("Esc opens and closes settings menu");
    add_command(.{type = .WAIT, wait_seconds = 0.5});
    add_command(.{type = .KEYPRESS, key = .ESCAPE});
    add_command(.{type = .WAIT, wait_seconds = 0.2});
    add_command(.{type = .CHECK, check = () -> bool { return settings_menu_blocks_game(); }});
    add_command(.{type = .KEYPRESS, key = .ESCAPE});
    add_command(.{type = .WAIT, wait_seconds = 0.2});
    add_command(.{type = .CHECK, check = () -> bool { return !settings_menu_blocks_game(); }});
    
    start_test_suite("World creation");
    start_test("Create world via console");
    add_command(.{type = .WAIT, wait_seconds = 0.5});
    add_command(.{type = .OP, op = () -> void {nworld("test_world");}});
    add_command(.{type = .OP, op = () -> void {sworld();}});
    for 0..5 {
        add_command(.{type = .OP, op = () -> void {lworld("test_world");}});
        add_command(.{type = .WAIT, wait_seconds = 0.5});
    }
}
