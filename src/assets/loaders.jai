create_texture_from_memory :: (data: []u8) -> (sg_image, s32, s32) {
    x, y, channels : s32;
    image := stbi.stbi_load_from_memory(data.data, xx data.count, *x, *y, *channels, 4);

    subimg : [6][16]sg_range;
    subimg[0][0] = .{
        ptr = image,
        size = xx (x * y * 4)
    };

    img := sg_alloc_image();

    sg_init_image(img, *(sg_image_desc.{
        width = x,
        height = y,
        pixel_format = sg_pixel_format.RGBA8,
        data = .{
            subimage = subimg
        }
    }));

    stbi.stbi_image_free(image);
    return img, x, y;
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
    for sample: audio_samples {
        array_add(*audio.data, cast(float)sample / 32768.0);
    }
    audio.channels     = format.nChannels;
    audio.sample_rate  = format.nSamplesPerSec;
    return audio;
}
