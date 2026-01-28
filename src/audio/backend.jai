sokol_audio_callback :: (buffer: *float, num_frames: s32, num_channels: s32) #c_call {
    push_context,defer_pop default_context;

    if mono_track.count < 1 then return;

    for i : 0..num_frames-1 {
        buffer[i] = mono_track[cur_sample] * 0.1;
        cur_sample += 1;
    }
}
