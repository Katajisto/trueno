g_test_runner_state : [..]Exe_Test_Suite;

#load "runner.jai";

Exe_Test_Suite :: struct {
    name : string;
    tests : [..]Exe_Test;
}

Exe_Test :: struct {
    name : string;
    cmds : [..]Exe_Test_Command;
}

Exe_Test_Command_Type :: enum {
    INVALID;
    WAIT;
    KEYPRESS;
    CHECK;
    OP;
}

Exe_Test_Command :: struct {
    type         : Exe_Test_Command_Type = .INVALID;
    wait_seconds : float = 0;
    key          : Key_Code;
    check        : () -> bool;
    op           : () -> void;
}

start_test_suite :: (name: string) {
    array_add(*g_test_runner_state, .{ name = name });
}

start_test :: (name: string) {
    assert(g_test_runner_state.count > 0);
    latest_suite := *g_test_runner_state[g_test_runner_state.count - 1];
    array_add(*latest_suite.tests, Exe_Test.{ name = name });
}

add_command :: (cmd: Exe_Test_Command) {
    assert(g_test_runner_state.count > 0);
    latest_suite := *g_test_runner_state[g_test_runner_state.count - 1];
    assert(latest_suite.tests.count > 0);
    latest_test := *latest_suite.tests[latest_suite.tests.count - 1];
    array_add(*latest_test.cmds, cmd);
}
