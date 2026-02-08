get_apollo_time :: () -> Apollo_Time {
    #if OS != .WASM {
        // Since we are making a game engine, we want the monotonic time.
        // This means that we won't take corrections to the time into account
        // since this could make a delta time negative and that would be bad.
        return current_time_monotonic();
    } else {
        // Implement a WASM Apollo_Time backend here.
        #assert false;
    }
    
}

get_time :: () -> float64 {
    return stm_sec(stm_now()); 
}
