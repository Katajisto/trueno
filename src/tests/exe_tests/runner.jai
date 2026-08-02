// A single test gets this long to run its commands before it is declared hung
// and the run moves on. This only fires while frames are still being produced;
// a genuine freeze has to be caught by a timeout around the process itself,
// which is what run_tests.sh does.
EXE_TEST_TIMEOUT_SECONDS :: 30.0;

Exe_Runner :: struct {
    suite_idx     : int;
    test_idx      : int;
    cmd_idx       : int;
    wait_until    : float64;
    test_failed   : bool;
    test_started  : bool;
    done          : bool;
    passed        : int;
    failed        : int;
    test_deadline : float64;
}

g_exe_runner : Exe_Runner;

// Ends the process with a status that reflects the run, so a failing exe test
// actually fails the build instead of quitting quietly with 0.
finish_exe_tests :: (r: *Exe_Runner) {
    total := r.passed + r.failed;
    if r.failed == 0 {
        print("[exe tests] All % test(s) passed.\n", total);
    } else {
        print("[exe tests] %/% passed, % FAILED.\n", r.passed, total, r.failed);
    }
    r.done = true;
    sapp_request_quit();
    status : s32 = ifx r.failed > 0 then cast(s32) 1 else cast(s32) 0;
    exit(status);
}

run_exe_tests :: () {
    r := *g_exe_runner;
    if r.done then return;
    if g_test_runner_state.count == 0 {
        r.done = true;
        return;
    }

    if r.suite_idx >= g_test_runner_state.count {
        print("[exe tests] All suites complete.\n");
        finish_exe_tests(r);
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
        r.test_started  = true;
        r.test_deadline = get_time() + EXE_TEST_TIMEOUT_SECONDS;
    }

    // A test that outlives its budget is failed where it stands rather than
    // being allowed to stall the whole run.
    if get_time() > r.test_deadline {
        print("[exe tests] TIMEOUT '%' / '%' after %s (cmd % of %)\n",
              suite.name, test.name, EXE_TEST_TIMEOUT_SECONDS, r.cmd_idx, test.cmds.count);
        r.test_failed = true;
        r.cmd_idx     = test.cmds.count;
    }

    if r.cmd_idx >= test.cmds.count {
        if r.test_failed {
            r.failed += 1;
            print("[exe tests] FAIL '%' / '%'\n", suite.name, test.name);
        } else {
            r.passed += 1;
            print("[exe tests] PASS '%' / '%'\n", suite.name, test.name);
        }
        // Cleared here too: timing out mid-WAIT leaves a stale deadline behind,
        // which would make the next test's first WAIT elapse instantly.
        r.wait_until   = 0;
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
