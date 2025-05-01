#load "bindings.jai";

#if OS == .WINDOWS ||  OS == .PS5 || OS == .WASM {
    #scope_module
    FILE :: void;
} else #if OS_IS_UNIX {
    #import "POSIX";
    #library,system,link_always "libm";
} else {
    #assert false;
}

