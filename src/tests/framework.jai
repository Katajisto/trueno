// Test framework only — no test cases. This is loaded under every test flag so
// that the game side can write suites and exe tests exactly like the engine does.
//
// Unit tests need nothing beyond this: put them in a #if FLAG_TEST_GAME block
// next to the code they cover, with a local #run to call them, and a failing
// check turns into a compile error.
//
// Exe tests are registered from game_exe_tests_add(), which the engine calls
// during init when built with test_exe_game.

#load "utils.jai";
#load "exe_tests/index.jai";
