run_exe_tests :: () {
    for g_test_runner_state {
        print("SUITE: %\n", it.name);
        for it.tests {
            print("  TEST: %\n", it.name);
            for it.cmds {
                print("    CMD: %\n", it.type);
            }
        }
    }
}
