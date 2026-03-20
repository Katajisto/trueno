#if OS != .WASM {
    Thread :: #import "Thread";
}

Mixer_Bus :: enum {
    MUSIC;
    SOUND_EFFECT;
    DIALOGUE;
}

Play_Mode :: enum {
    ONESHOT;
    REPEAT;
}

Mixer_Play_Task :: struct {
    audio     : *Audio_Data;
    bus       : Mixer_Bus;
    mode      : Play_Mode;
    unique    : bool = true;
    curSample : s64 = 0;  // output frames consumed

    startTime           : float64 = 0;
    delay               : float64 = 0;
    silenceBeforeRepeat : float64 = 0;
}

Mixer_Config :: struct {
    musicVolume        : float = 0.5; @Slider,0,1,0.1
    masterVolume       : float = 0.5; @Slider,0,1,0.1
    dialogueVolume     : float = 0.5; @Slider,0,1,0.1
    soundEffectVolume  : float = 0.3; @Slider,0,1,0.1
}

g_mixer : Mixer;

Mixer :: struct {
    paused : bool = false;
    #if OS != .WASM {
        // If we are on WASM, the Thread module mutex does not work.
        // Fortunately we don't need a mutex for this, since sokol does
        // not do multithreading for audio on WASM.
        //
        // Let's just have the mutex as a part of the struct on all platforms
        // except WASM. It would probably be a good idea to have a mutex wrapper
        // thing that would use the Thread module Mutex or a mutex that works with
        // WASM. :NoMutexForWasm
        mutex : Thread.Mutex;
    }

    config     : Mixer_Config;
    tasks      : [..]Mixer_Play_Task;
}

mixer_add_task :: (task: Mixer_Play_Task) {
    mixer_lock(*g_mixer);
    defer mixer_unlock(*g_mixer);
    if task.unique {
        for g_mixer.tasks {
            if it.audio == task.audio then return;
        }
    }
    array_add(*g_mixer.tasks, task);
}

mixer_add_task :: (audio: *Audio_Data, bus: Mixer_Bus, mode: Play_Mode) {
    mixer_add_task(.{
        audio = audio,
        bus = bus,
        mode = mode
    });
}

mixer_get_samples :: (buffer: *float, frame_count: s32, channel_count: s32) {
    mixer_lock(*g_mixer);
    defer mixer_unlock(*g_mixer);

    total_samples := frame_count * channel_count;
    memset(buffer, 0, total_samples * size_of(float));

    if g_mixer.paused then return;
    if g_mixer.tasks.count < 1 then return;
   
    for < i : 0..g_mixer.tasks.count-1 {
        task := *g_mixer.tasks[i];

        if !task.audio {
            array_unordered_remove_by_index(*g_mixer.tasks, i);
            continue;
        }

        bus_vol := 1.0;
        if task.bus == {
            case .MUSIC;        bus_vol = g_mixer.config.musicVolume;
            case .SOUND_EFFECT; bus_vol = g_mixer.config.soundEffectVolume;
            case .DIALOGUE;     bus_vol = g_mixer.config.dialogueVolume;
        }
        
        vol := bus_vol * g_mixer.config.masterVolume;
        
        source_data     := task.audio.data;
        source_channels := cast(s64) task.audio.channels;
        src_rate        := cast(s64) task.audio.sample_rate;
        out_rate        := cast(s64) saudio_sample_rate();
        num_src_frames  := source_data.count / source_channels;

        task_finished := false;

        for f : 0..frame_count-1 {
            src_pos    := cast(float64)(task.curSample + f) * cast(float64)src_rate / cast(float64)out_rate;
            src_frame0 := cast(s64) src_pos;
            src_frame1 := src_frame0 + 1;
            t          := cast(float)(src_pos - cast(float64)src_frame0);

            if src_frame0 >= num_src_frames {
                if task.mode == .ONESHOT {
                    task_finished = true;
                    break;
                } else {
                    src_frame0 = src_frame0 % num_src_frames;
                    src_frame1 = src_frame1 % num_src_frames;
                }
            } else if src_frame1 >= num_src_frames {
                // At the very last source frame: clamp for ONESHOT, wrap for REPEAT.
                src_frame1 = ifx task.mode == .ONESHOT then src_frame0 else 0;
            }

            for ch : 0..channel_count-1 {
                out_index := (f * channel_count) + ch;
                src_ch    := ifx source_channels == 1 then 0 else ch;

                s0 := source_data[src_frame0 * source_channels + src_ch];
                s1 := source_data[src_frame1 * source_channels + src_ch];

                buffer[out_index] += (s0 + (s1 - s0) * t) * vol;
            }
        }

        task.curSample += frame_count;

        // Keep curSample bounded for REPEAT tracks so it never overflows.
        if task.mode == .REPEAT && out_rate > 0 && src_rate > 0 {
            loop_period := num_src_frames * out_rate / src_rate;
            if loop_period > 0 then task.curSample = task.curSample % loop_period;
        }

        if task_finished {
            array_unordered_remove_by_index(*g_mixer.tasks, i);
        }
    }
}

mixer_lock :: (mixer: *Mixer) {
    #if OS != .WASM {
        Thread.lock(*mixer.mutex);
    } else {
        return; // On WASM this is a no-op. See :NoMutexForWasm
    }
}

mixer_unlock :: (mixer: *Mixer) {
    #if OS != .WASM {
        Thread.unlock(*mixer.mutex);
    } else {
        return; // On WASM this is a no-op. See :NoMutexForWasm
    }
    
}
