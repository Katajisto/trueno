Exe_Runner :: struct {
    suite_idx    : int;
    test_idx     : int;
    cmd_idx      : int;
    wait_until   : float64;
    test_failed  : bool;
    test_started : bool;
    done         : bool;
}

g_exe_runner : Exe_Runner;

run_exe_tests :: () {
    r := *g_exe_runner;
    if r.done then return;
    if g_test_runner_state.count == 0 {
        r.done = true;
        return;
    }

    if r.suite_idx >= g_test_runner_state.count {
        print("[exe tests] All suites complete.\n");
        r.done = true;
        sapp_request_quit();
        return;
    }

    suite := *g_test_runner_state[r.suite_idx];

    if r.test_idx >= suite.tests.count {
        print("[exe tests] Suite '%' complete.\n", suite.name);
        r.suite_idx  += 1;
        r.test_idx    = 0;
        r.cmd_idx     = 0;
        r.test_failed = false;
        return;
    }

    test := *suite.tests[r.test_idx];

    if !r.test_started {
        print("[exe tests] Starting '%' / '%'\n", suite.name, test.name);
        r.test_started = true;
    }

    if r.cmd_idx >= test.cmds.count {
        if r.test_failed {
            print("[exe tests] FAIL '%' / '%'\n", suite.name, test.name);
        } else {
            print("[exe tests] PASS '%' / '%'\n", suite.name, test.name);
        }
        r.test_idx    += 1;
        r.cmd_idx      = 0;
        r.test_failed  = false;
        r.test_started = false;
        return;
    }

    if r.test_failed {
        r.cmd_idx += 1;
        return;
    }

    cmd := test.cmds[r.cmd_idx];

    if cmd.type == {
        case .WAIT;
            if r.wait_until == 0 {
                r.wait_until = get_time() + cast(float64) cmd.wait_seconds;
            }
            if get_time() >= r.wait_until {
                r.wait_until = 0;
                r.cmd_idx   += 1;
            }
        case .KEYPRESS;
            input_button_states[cmd.key] = input_button_states[cmd.key] | .START | .DOWN;
            r.cmd_idx += 1;
        case .CHECK;
            if cmd.check == null || cmd.check() {
                r.cmd_idx += 1;
            } else {
                print("[exe tests] CHECK failed in '%' / '%' (cmd %)\n", suite.name, test.name, r.cmd_idx);
                r.test_failed = true;
                r.cmd_idx    += 1;
            }
        case .INVALID;
            r.cmd_idx += 1;
        case .OP;
            if cmd.op != null {
                cmd.op();
                r.cmd_idx += 1;
            }
            
    }
}
