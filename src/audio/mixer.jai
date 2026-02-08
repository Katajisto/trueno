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
    curSample : s64 = 0;

    startTime           : float64 = 0;
    delay               : float64 = 0;
    silenceBeforeRepeat : float64 = 0;
}

Mixer_Config :: struct {
    musicVolume        : float = 0.5; @Slider,0,1,0.1
    masterVolume       : float = 0.5; @Slider,0,1,0.1
    dialogueVolume     : float = 0.5; @Slider,0,1,0.1
    soundEffectVolume  : float = 0.5; @Slider,0,1,0.1
}

g_mixer : Mixer;

Mixer :: struct {
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
        source_channels := task.audio.channels; 

        task_finished := false;

        for f : 0..frame_count-1 {
            if task.curSample >= source_data.count {
                if task.mode == .ONESHOT {
                    task_finished = true;
                    break;
                } else {
                    task.curSample = 0;
                }
            }

            cursor := task.curSample;

            for ch : 0..channel_count-1 {
                out_index := (f * channel_count) + ch;
                offset := ifx source_channels == 1 then 0 else ch;
                
                sample : float = 0;
                
                if cursor + offset < source_data.count {
                    sample = source_data[cursor + offset];
                }

                buffer[out_index] += sample * vol;
            }

            task.curSample += source_channels;
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
