#scope_export 

Rendering_Task_Type :: enum {
    INVALID;
    GROUND;
    SKY;
    SET_CAMERA;
    TRILE;     // not implemented yet
    SPRITE;    // not implemented yet
    PARTICLES; // not implemented yet
};

Rendering_Task :: struct {
    type          : Rendering_Task_Type = .INVALID;
};

Rendering_Task_World :: struct {
    #as using t : Rendering_Task;
    world       : *World;
}

Rendering_Task_Sky :: struct {
    #as using t : Rendering_Task;
    t.type      = .SKY;
    worldConfig : *World_Config;
}

Rendering_Task_Ground :: struct {
    #as using t : Rendering_Task;
    t.type      = .GROUND;
    world : *World;
}

Rendering_Task_Set_Camera :: struct {
    #as using t : Rendering_Task;
    camera      : Camera;
}

rendering_tasklist_clear :: () {
    array_reset_keeping_memory(*rendering_tasklist);
}

add_rendering_task :: (task: $T) {
    task_ptr := New(T,, temp);
    task_ptr.* = task;
    array_add(*rendering_tasklist, task_ptr);
}

rendering_tasklist : [..]*Rendering_Task;

tasks_to_commands :: () {
    for rendering_tasklist {
        if it.type == {
            case .SKY;
                command := New(Render_Command_Sky,, temp);
                command.type = .DRAW_SKY;
                command.worldConfig = (cast(*Rendering_Task_Sky)it).worldConfig;
                array_add(*render_command_buckets.reflection, command);
                array_add(*render_command_buckets.main, command);
            case .GROUND;
                commandDrawGround := New(Render_Command_Draw_Ground,, temp);
                commandDrawGround.type = .DRAW_GROUND;
                commandDrawGround.worldConfig = *(cast(*Rendering_Task_Ground)it).world.conf;
                commandGenGround := New(Render_Command_Generate_Ground_Texture,, temp);
                commandGenGround.type = .GENERATE_GROUND;
                commandGenGround.world = (cast(*Rendering_Task_Ground)it).world;
                array_add(*render_command_buckets.setup, commandGenGround);
                array_add(*render_command_buckets.main, commandDrawGround);
            case .SET_CAMERA;
                command := New(Render_Command_Set_Camera,, temp);
                command.type = .SET_CAMERA;
                command.camera = (cast(*Rendering_Task_Set_Camera)it).camera;
                array_add(*render_command_buckets.main, command);
                commandReflected := New(Render_Command_Set_Camera,, temp);
                commandReflected.type = .SET_CAMERA;
                commandReflected.camera = (cast(*Rendering_Task_Set_Camera)it).camera;
                commandReflected.camera.target   *= Vector3.{1, -1, 1};
                commandReflected.camera.position *= Vector3.{1, -1, 1};
                array_add(*render_command_buckets.reflection, commandReflected);
        }
    }
    rendering_tasklist_clear();
}
