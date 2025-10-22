Pack_Item :: struct {
    id: string;
    w: u32;
    h: u32;
    x: u32;
    y: u32;
}

// Give this a list of items, and then it will pack them and fill in their positions in the atlas.
// It will return the size of the atlas. The atlas will always be a square. It will start with a 1028x1028
// atlas and double the atlas size with each failed try. 
pack :: (items: []Pack_Item) -> u32 {
    // @Incomplete: current packing is 0iq, it should probably be improved.
}
