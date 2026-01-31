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

// Removes tasks from the mixer's task list that
// no longer have a reason to be on the task list.
// Eg. a sound that is .ONESHOT but has already been played.
mixer_clean_tasks :: () {
    mixer_lock(*g_mixer);
    defer mixer_unlock(*g_mixer);
    
}

mixer_add_task :: (task: Mixer_Play_Task) {
    mixer_lock(*g_mixer);
    defer mixer_unlock(*g_mixer);
    
}

mixer_get_samples :: (samples: *float, sampleCount: s32, channelCount: s32) {
    mixer_lock(*g_mixer);
    defer mixer_unlock(*g_mixer);
   
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
