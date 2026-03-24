engine_exe_tests_add :: () {
    start_test_suite("Pause menu");
    start_test("Esc opens pause menu");
    add_command(.{type = .WAIT});
}
