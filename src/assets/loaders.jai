create_texture_from_memory :: (data: []u8) -> (Texture, s32, s32) {
    x, y, channels : s32;
    image := stbi.stbi_load_from_memory(data.data, xx data.count, *x, *y, *channels, 4);
    texture := texture_create(x, y, .{x * y * 4, image});
    stbi.stbi_image_free(image);
    return texture, x, y;
}

create_string_from_memory :: (data: []u8) -> string {
    s: string;
    s.data = data.data;
    s.count = data.count;
    return s;
}

load_hex_palette_from_memory :: (data: []u8) -> [..]Palette_Entry {
    entries : [..]Palette_Entry;
    parse_hex_byte :: (s: string) -> (u8, bool) {
        val : u8 = 0;
        for i: 0..1 {
            c := s[i];
            digit : u8;
            if c >= #char "0" && c <= #char "9"       digit = c - #char "0";
            else if c >= #char "a" && c <= #char "f"  digit = c - #char "a" + 10;
            else if c >= #char "A" && c <= #char "F"  digit = c - #char "A" + 10;
            else return 0, false;
            val = val * 16 + digit;
        }
        return val, true;
    }

    s := create_string_from_memory(data);
    for line: split(s, "\n") {
        trimmed := trim(line);
        if trimmed.count != 6 then continue;
        rb, ok1 := parse_hex_byte(slice(trimmed, 0, 2));
        gb, ok2 := parse_hex_byte(slice(trimmed, 2, 2));
        bb, ok3 := parse_hex_byte(slice(trimmed, 4, 2));
        if !ok1 || !ok2 || !ok3 then continue;
        entry : Palette_Entry;
        entry.name = sprint("#%", trimmed);
        entry.r = cast(float)rb / 255.0;
        entry.g = cast(float)gb / 255.0;
        entry.b = cast(float)bb / 255.0;
        array_add(*entries, entry);
    }
    return entries;
}

// Decoded in full up front, so the mixer sees the same float samples as from a wav;
// only the pack stays small.
load_ogg_from_memory :: (data: []u8) -> Audio_Data {
    Vorbis :: #import "stb_vorbis";
    audio : Audio_Data;
    error : s32;
    v := Vorbis.stb_vorbis_open_memory(data.data, cast(s32) data.count, *error, null);
    if !v {
        log_error("Failed to load ogg file! (stb_vorbis error %)", error);
        return audio;
    }
    defer Vorbis.stb_vorbis_close(v);

    info   := Vorbis.stb_vorbis_get_info(v);
    frames := cast(s64) Vorbis.stb_vorbis_stream_length_in_samples(v);
    array_resize(*audio.data, frames * info.channels);
    got := Vorbis.stb_vorbis_get_samples_float_interleaved(v, info.channels, audio.data.data, cast(s32) audio.data.count);
    audio.data.count  = got * info.channels;
    audio.channels    = cast(s16) info.channels;
    audio.sample_rate = cast(s32) info.sample_rate;
    return audio;
}

load_wav_from_memory :: (data: []u8) -> Audio_Data {
    Wav :: #import "Wav_File";
    audio : Audio_Data;
    dataString : string;
    dataString.data = data.data;
    dataString.count = data.count;
    format, samples, success := Wav.get_wav_header(dataString);
    if !success log_error("Failed to load wav file!");
    audio_samples : []s16;
    audio_samples.data = cast(*s16)samples.data;
    audio_samples.count = samples.count / 2;
    array_resize(*audio.data, audio_samples.count);
    for i: 0..audio_samples.count - 1 {
        audio.data[i] = cast(float)audio_samples[i] / 32768.0;
    }
    audio.channels     = format.nChannels;
    audio.sample_rate  = format.nSamplesPerSec;
    return audio;
}
