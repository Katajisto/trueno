#load "backend.jai";
#load "load.jai";

Mixer_Bus :: enum {
    MUSIC;
    SOUND_EFFECT;
    DIALOGUE;
}

Mixer :: struct {
    
}

mixer_get_samples :: (buffer: *float, mixer: *Mixer, sampleCount: s32, channelCount: s32) {
    
}

audio_init :: () {
    load_wav_file();
}

audio_cleanup :: () {
    saudio_shutdown();
}

mono_track : [..]float;

cur_sample : int = 0;

audio_samples : []s16;
