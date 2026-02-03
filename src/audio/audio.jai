#load "backend.jai";
#load "load.jai";
#load "mixer.jai";

audio_init :: () {
    // load_wav_file();
}

audio_cleanup :: () {
    saudio_shutdown();
}

mono_track : [..]float;

cur_sample : int = 0;

audio_samples : []s16;
