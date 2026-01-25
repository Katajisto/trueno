sign :: (x: float) -> float {
    if x < 0 then return -1;
    return 1;
}

mix :: (a: float, b: float, mix: float) -> float {
    mixFactor := max(0.0, min(mix, 1.0));    
    return a * (1.0 - mixFactor) + mixFactor * b;
}
