#scope_export 

Rendering_Task_Type :: enum {
    INVALID;
    GROUND;    // We need to add an ability to invalidate buffer here too.
    SKY;
    SET_CAMERA;
    SET_LIGHT;
    TRILE;     // We need to add an ability to invalidate buffer instead of updating it constantly. Also probably have a buffer for static world triles and one for moving ones.
    TRIXELS;
    BILLBOARD; 
    PARTICLES;
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

Rendering_Task_Set_Light :: struct {
    #as using t : Rendering_Task;
    t.type      = .SET_LIGHT;
    worldConfig : *World_Config;
}

Rendering_Task_Ground :: struct {
    #as using t : Rendering_Task;
    t.type      = .GROUND;
    world : *World;
}

Rendering_Task_Billboard :: struct {
    #as using t : Rendering_Task;
    t.type      = .BILLBOARD;
    position    : Vector3;
    animation   : *Animation;
    frame       : s32;
    flipX       : bool;
    flipY       : bool;
}

Rendering_Task_Trile :: struct {
    #as using t : Rendering_Task;
    t.type      = .TRILE;
    trile       : string;
    chunk_key   : Chunk_Key;
    positions   : []Vector4;
    worldConf   : *World_Config;
}

Rendering_Task_Trixels :: struct {
    #as using t    : Rendering_Task;
    t.type         = .TRIXELS;
    colMultipliers : *[16][16][16]Vector3;
    trile          : *Trile;
}

Rendering_Task_Set_Camera :: struct {
    #as using t : Rendering_Task;
    camera      : Camera;
    planeHeight : float;
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
            case .SET_LIGHT;
                lighttask := (cast(*Rendering_Task_Set_Light)it);
                lightcmd := New(Render_Command_Set_Light,, temp);
                lightcmd.worldConfig = lighttask.worldConfig;
                array_add(*render_command_buckets.setup, lightcmd);
            case .TRIXELS;
                trixelsTask := (cast(*Rendering_Task_Trixels)it);
                updateCommand := New(Render_Command_Update_Trixels,, temp);
                updateCommand.trile = trixelsTask.trile;
                updateCommand.colMultipliers = trixelsTask.colMultipliers;
                array_add(*render_command_buckets.setup, updateCommand);
                drawCommand := New(Render_Command_Draw_Trixels,, temp);
                array_add(*render_command_buckets.main, drawCommand);
                // Currently no need to draw trixels anywhere but the editor so no
                // need for drawing them in the planar reflection pass...
                // array_add(*render_command_buckets.reflection, drawCommand);

            case .TRILE;
                trileTask := (cast(*Rendering_Task_Trile)it);
                addPositionsCmd := New(Render_Command_Add_Trile_Positions,, temp);
                addPositionsCmd.positions = trileTask.positions;
                array_add(*render_command_buckets.setup, addPositionsCmd);
                drawPositionsCmd := New(Render_Command_Draw_Trile_Positions,, temp);
                drawPositionsCmd.trile = trileTask.trile;
                drawPositionsCmd.chunk_key = trileTask.chunk_key;
                drawPositionsCmd.amount = cast(s32)trileTask.positions.count;
                drawPositionsCmd.conf = trileTask.worldConf;
                array_add(*render_command_buckets.reflection, drawPositionsCmd);
                array_add(*render_command_buckets.main, drawPositionsCmd);
                array_add(*render_command_buckets.gbuffer, drawPositionsCmd);
                array_add(*render_command_buckets.shadow, drawPositionsCmd);
            case .SKY;
                command := New(Render_Command_Sky,, temp);
                command.worldConfig = (cast(*Rendering_Task_Sky)it).worldConfig;
                array_add(*render_command_buckets.reflection, command);
                array_add(*render_command_buckets.main, command);
            case .GROUND;
                commandDrawGround := New(Render_Command_Draw_Ground,, temp);
                commandDrawGround.worldConfig = *(cast(*Rendering_Task_Ground)it).world.conf;
                array_add(*render_command_buckets.main, commandDrawGround);
                array_add(*render_command_buckets.gbuffer, commandDrawGround);
            case .BILLBOARD;
                billboardTask := (cast(*Rendering_Task_Billboard)it);
                commandDrawBillboard := New(Render_Command_Draw_Billboard,, temp);
                commandDrawBillboard.position = billboardTask.position;
                commandDrawBillboard.frame = billboardTask.frame;
                commandDrawBillboard.flipX = billboardTask.flipX;
                commandDrawBillboard.flipY = billboardTask.flipY;
                commandDrawBillboard.animation = billboardTask.animation;
                array_add(*render_command_buckets.gbuffer, commandDrawBillboard);
                array_add(*render_command_buckets.main, commandDrawBillboard);
                array_add(*render_command_buckets.shadow, commandDrawBillboard);
                array_add(*render_command_buckets.reflection, commandDrawBillboard);
            case .SET_CAMERA;
                task := (cast(*Rendering_Task_Set_Camera)it);
                command := New(Render_Command_Set_Camera,, temp);
                command.camera = task.camera;
                array_add(*render_command_buckets.main, command);
                array_add(*render_command_buckets.gbuffer, command);
                commandReflected := New(Render_Command_Set_Camera,, temp);
                commandReflected.camera = task.camera;
                commandReflected.camera.target   *= Vector3.{1, -1, 1};
                commandReflected.camera.position *= Vector3.{1, -1, 1};
                commandReflected.camera.target.y += task.planeHeight * 2;
                commandReflected.camera.position.y += task.planeHeight * 2;
                array_add(*render_command_buckets.reflection, commandReflected);
        }
    }
    rendering_tasklist_clear();
}
