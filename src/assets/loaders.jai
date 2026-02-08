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

load_wav_from_memory :: (data: []u8) -> Audio_Data {
    Wav :: #import "Wav_File";
    audio : Audio_Data;
    dataString : string;
    dataString.data = data.data;
    dataString.count = data.count;
    format, samples, success := Wav.get_wav_header(dataString);
    if !success print("Failed to load wav file!\n");
    audio_samples : []s16;
    audio_samples.data = cast(*s16)samples.data;
    audio_samples.count = samples.count / 2;
    for sample, i:  audio_samples {
        if i % 2 == 0 {
            array_add(*audio.data, cast(float)sample / 32768.0);
        }
    }
    audio.channels = format.nChannels;
    return audio;
}
