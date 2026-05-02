AUDIO_THREAD_TEMP_STORAGE_SIZE :: 4096;
audio_thread_temp_storage      : Temporary_Storage;
audio_thread_temp_storage_data : [AUDIO_THREAD_TEMP_STORAGE_SIZE] u8 #align 64;
audio_thread_context_ready     : bool = false;
audio_thread_context           : #Context;

audio_init_thread_context :: () {
    audio_thread_context = default_context;
    audio_thread_context.temporary_storage = *audio_thread_temp_storage;
    audio_thread_temp_storage.data = audio_thread_temp_storage_data.data;
    audio_thread_temp_storage.size = audio_thread_temp_storage_data.count;

    // Iprof's zone stack/hash are global. The audio callback runs on a separate
    // thread, so any instrumented call from inside it races with the main thread
    // and corrupts those globals. Mark this context as "inside profiler runtime"
    // so Automatic_Zone_Guarded skips the begin/end on this thread.
    #if FLAG_IPROF_ENABLED {
        audio_thread_context.already_inside_profiler_runtime = true;
    }

    audio_thread_context_ready = true;
}

sokol_audio_callback :: (buffer: *float, num_frames: s32, num_channels: s32) #c_call {
    if !audio_thread_context_ready then return;
    push_context,defer_pop audio_thread_context;
    mixer_get_samples(buffer, num_frames, num_channels);
}
