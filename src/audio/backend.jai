sokol_audio_callback :: (buffer: *float, num_frames: s32, num_channels: s32) #c_call {
    push_context,defer_pop default_context;
    audio := get_audio_from_pack("game_core", "sound/music/monoco");
    if !audio {
        print("Audio was null!!\n");
        return;
    }
    if audio.data.count < 1 then return;

    for i : 0..num_frames-1 {
        if cur_sample >= audio.data.count {
            cur_sample = 0;
        }
        buffer[i] = audio.data[cur_sample] * 0.5;
        cur_sample += 1;
    }
}
