Audio_Data :: struct {
    channels: u16;
    data: []float;
}

Wav :: #import "Wav_File";

audio_info : Wav.Waveformatex;

load_wav_file :: () {
    audio := load_string_from_pack("./game/resources/sound/music/monoco.wav");    
    format, samples, success := Wav.get_wav_header(audio);
    if !success print("Failed to load wav file!!!!!\n");
    audio_info = format;
    audio_samples.data = cast(*s16)samples.data;
    audio_samples.count = samples.count / 2;
    print("Format: %\n", format.wBitsPerSample);
    for sample, i:  audio_samples {
        if i % 2 == 0 {
            array_add(*mono_track, cast(float)sample / 32768.0);
        }
    }
    print("Converted % samples", mono_track.count);
}
