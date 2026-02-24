get_apollo_time :: () -> Apollo_Time {
    #if OS != .WASM {
        // Since we are making a game engine, we want the monotonic time.
        // This means that we won't take corrections to the time into account
        // since this could make a delta time negative and that would be bad.
        return current_time_monotonic();
    } else {
        // stm_now() returns uint64 nanoseconds since sokol time init.
        // Apollo_Time is S128 nanoseconds; we fill only the low word since
        // the elapsed time will never overflow 64 bits.
        result: Apollo_Time;
        result.low = stm_now();
        return result;
    }
    
}

get_time :: () -> float64 {
    return stm_sec(stm_now()); 
}
