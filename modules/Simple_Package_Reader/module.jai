// create_*...

Create_Package :: struct {
    data: String_Builder;

    entries: [..] Entry_Info;
    pool: Pool;  // Stores entry names and user data.
}

Entry_Info :: struct {
    name: string;
    data: [] u8;
    offset_from_start_of_file: s64;
    size_of_entry: s64;  // Equal to data.count if we hae the data, but we might not have the data if loading Table_Of_Contents only!
}

deinit :: (using package: *Create_Package) {
    free_buffers(*data);
    array_reset(*entries);
    release(*pool);
}


KNOWN_HEADER_SIZE :: 64;
#assert size_of(Package_Header) == KNOWN_HEADER_SIZE;

Package_Header :: struct {
    magic:     u32;
    version:   u32;
    flags:     u32;
    reserved0: u32;

    table_of_contents_offset: s64;
    
    reserved:  [5] u64;
}

Load_Package :: struct {
    header: Package_Header;
    data: [] u8;

    table_of_contents: Table_Of_Contents;

    entries: [] Entry_Info;

    lookup: Table(string, *Entry_Info);
}

KNOWN_TABLE_OF_CONTENTS_SIZE :: 64;
#assert size_of(Table_Of_Contents) == KNOWN_TABLE_OF_CONTENTS_SIZE;

Table_Of_Contents :: struct {
    table_of_contents_magic: u32;
    reserved0:               u32;
    
    number_of_entries:       s64;

    reserved:                [6] u64;
}

append_struct :: (builder: *String_Builder, to_append: *$T) {
    append(builder, cast(*u8) to_append, size_of(T));
}


init_from_memory :: (package: *Load_Package, data: [] u8, name_for_debugging := "") -> bool {
    #assert(TARGET_IS_LITTLE_ENDIAN);  // We can endian-swap the header later.

    if data.count < KNOWN_HEADER_SIZE {
        log_error("Package '%' is too small to even contain a header! (It's % bytes).\n", name_for_debugging, data.count);
        return false;  // Too small!
    }

    _header := cast(*Package_Header) data.data;
    package.header = (.*) _header;

    header_success := check_header(*package.header, name_for_debugging, data.count);
    if !header_success return false;

    offset := package.header.table_of_contents_offset;
    toc_start := data;
    toc_start.data  += offset;
    toc_start.count -= offset;
    assert(toc_start.count >= 0);
    
    toc_success := load_table_of_contents(package, toc_start, data.data, name_for_debugging, offset);

    return toc_success;
}


load_table_of_contents :: (package: *Load_Package, data: [] u8, base_file_data_if_file_is_loaded: *u8, name_for_debugging: string, offset_for_debugging: s64) -> bool {
    toc := cast(*Table_Of_Contents) data.data;
    if toc.table_of_contents_magic != TABLE_OF_CONTENTS_MAGIC {
        log_error("In package '%', we skipped to the supposed table_of_contents at offset %, but did not find the magic number there that we expected to find. (We wanted %, but got %).\n", name_for_debugging, offset_for_debugging, formatInt(TABLE_OF_CONTENTS_MAGIC, base=16), formatInt(toc.table_of_contents_magic, base=16));
        return false;
    }

    entries: [..] Entry_Info;
    array_resize(*entries, toc.number_of_entries);

    s: string;
    s.data  = data.data  + KNOWN_TABLE_OF_CONTENTS_SIZE;
    s.count = data.count - KNOWN_TABLE_OF_CONTENTS_SIZE;

    assert(s.count >= 0);
    
    for 0..toc.number_of_entries-1 {
        entry := *entries[it];

        if s.count < 4 {
            log_error("Table_Of_Contents Entry % is too short!\n", it+1);
            return false;
        }
        
        name_length: u32;
        get(*s, *name_length);

        entry.name.data  = s.data;
        entry.name.count = name_length;

        if s.count < name_length + 1 + 16 { // The 16 is for the chunk size and offset.
            log_error("Table_Of_Contents Entry % is too short!\n", it+1);
            return false;
        }

        advance(*s, name_length + 1);

        chunk_size:   s64;
        chunk_offset: s64;
        
        get(*s, *chunk_size);
        get(*s, *chunk_offset);

        if chunk_offset >= package.header.table_of_contents_offset {
            log_error("The offset_from_start_of_file for Entry % is out of range; it must be before the table_of_contents, which starts at %, but it was %.\n", it+1, package.header.table_of_contents_offset, chunk_offset);
            return false;
        }

        base := base_file_data_if_file_is_loaded;
        if base {
            entry.data.data = base + chunk_offset;
            entry.data.count = chunk_size;
        }

        entry.size_of_entry = chunk_size;
        entry.offset_from_start_of_file = chunk_offset;

        table_add(*package.lookup, entry.name, entry);
    }

    package.entries = entries;

    return true;
}

#scope_file

MAGIC :: #run (.*) cast(*u32) "simp".data;
TABLE_OF_CONTENTS_MAGIC :: #run (.*) cast(*u32) "toc!".data;

FILE_VERSION :: 1;
TARGET_IS_LITTLE_ENDIAN :: true;  // @Endian: Need a way to change this based on target CPU!

// @Copypasta from the game!
put :: (builder: *String_Builder, x: $T)
#modify {
    using Type_Info_Tag;
    
    ti := cast(*Type_Info) T;
    if ti.type == INTEGER return true;  // Accept integers.
    if ti.type == FLOAT   return true;  // Accept floats.
    if ti.type == BOOL    return true;  // Accept bools.
    if ti.type == ENUM    return true;  // Accept enums.

    return false;                       // Reject anything else.
}
{
    ensure_contiguous_space(builder, size_of(T));

    #if TARGET_IS_LITTLE_ENDIAN {
        // @Speed: Just write the target type!
        simple_memcpy(builder, x);
    } else {
        // @Incomplete: Do a slow-path if we know we are not little-endian. This can be generated by #run_and_insert?
        assert(false);
    }
}

get :: (s: *string, x: *$T)
#modify {  // @Cutnpaste from put
    using Type_Info_Tag;
    
    ti := cast(*Type_Info) T;
    if ti.type == INTEGER return true;  // Accept integers.
    if ti.type == FLOAT   return true;  // Accept floats.
    if ti.type == BOOL    return true;  // Accept bools.
    if ti.type == ENUM    return true;  // Accept enums.

    return false;                  // Reject anything else.
}
{
    assert(s.count >= size_of(T));

    if TARGET_IS_LITTLE_ENDIAN {
        memcpy(x, s.data, size_of(T));
    } else {
        // @Incomplete: Do a slow-path if we know we are not little-endian. This can be generated by #run_and_insert?
        assert(false);
    }

    s.data  += size_of(T);
    s.count -= size_of(T);
}

check_header :: (header: *Package_Header, name: string, file_size_in_bytes_or_minus_1: s64) -> bool {
    using header;

    if magic != MAGIC {
        log_error("Package '%' has an incorrect magic number! (Wanted %, got %).\n", name, formatInt(MAGIC, base=16), formatInt(magic, base=16));
        return false;
    }

    if version > FILE_VERSION {  // 'version' is unsigned, so, don't check < 0.
        log_error("Package '%' has an invalid version number, or a version created by code that is newer than we are, so we don't understand the format. (Its version is %; our highest known version is %).\n", name, version, FILE_VERSION);
        return false;
    }

    if file_size_in_bytes_or_minus_1 >= 0 {
        size := file_size_in_bytes_or_minus_1;
        if table_of_contents_offset + KNOWN_TABLE_OF_CONTENTS_SIZE >= size {
            log_error("Package '%' has an invalid table_of_contents_offset; it claims to be %, but the file is only % bytes long.\n", name, table_of_contents_offset, size);
            return false;
        }
    }
    
    return true;
}

#import "Basic";
#import "Hash_Table";
#import "Pool";
