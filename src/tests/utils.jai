Test_Suite :: struct {
    name   : string;
    passed : int;
    failed : int;
}

begin_suite :: (name: string) -> Test_Suite {
    print("\n== % ==\n", name);
    return .{ name = name };
}

check :: (suite: *Test_Suite, name: string, condition: bool) {
    if condition {
        suite.passed += 1;
        print("  [PASS] %\n", name);
    } else {
        suite.failed += 1;
        print("  [FAIL] %\n", name);
    }
}

end_suite :: (suite: Test_Suite) {
    total := suite.passed + suite.failed;
    if suite.failed == 0 {
        print("  => All % tests passed.\n", total);
    } else {
        print("  => %/% passed, % FAILED.\n", suite.passed, total, suite.failed);
        assert(false, "Test suite '%' had % failure(s).", suite.name, suite.failed);
    }
}
