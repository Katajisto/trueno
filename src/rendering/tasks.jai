#scope_export 

Rendering_Task_Type :: enum {
    INVALID;
    GROUND;    // We need to add an ability to invalidate buffer here too.
    SKY;
    SET_CAMERA;
    SET_LIGHT;
    TRILE;     // We need to add an ability to invalidate buffer instead of updating it constantly. Also probably have a buffer for static world triles and one for moving ones.
    TRILE_RDM;
    TRIXELS;
    BILLBOARD;
    PARTICLES;
    PARTICLES_BUFFER;
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
    faceDir     : Vector3 = .{-100, -100, -100};
}

Rendering_Task_Trile :: struct {
    #as using t : Rendering_Task;
    t.type      = .TRILE;
    trile       : string;
    chunk_key   : Chunk_Key;
    positions   : []Trile_Instance;
    worldConf   : *World_Config;
    preview_mode : s32  = 0;    // 0=normal, 1=add preview (blue), 2=delete preview (red)
    shadow_only  : bool = false; // only submit to shadow bucket (frustum-culled from camera)
    skip_main    : bool = false; // RDM-flagged instances still cast shadows / write gbuffer / reflect, but main pass uses the RDM pipeline
    lod_index    : s32  = 0;     // 0 = full detail, 1 = 4^3 LOD, 2 = 2^3 LOD
}

Rendering_Task_Trile_RDM :: struct {
    #as using t : Rendering_Task;
    t.type      = .TRILE_RDM;
    trile       : string;
    position    : Vector4;       // xyz=world position, w=orientation
    atlas_rect  : Vector4;       // global atlas UV rect (zeros until Step 6 wires the manifest)
    worldConf   : *World_Config;
}

Rendering_Task_Trixels :: struct {
    #as using t    : Rendering_Task;
    t.type         = .TRIXELS;
    colMultipliers : *[16][16][16]Vector3;
    trile          : *Trile;
    world_offset   : Vector3;
    brightness     : float = 1.0;
    tile_rotation  : Matrix4 = .{_11=1, _22=1, _33=1, _44=1};
    is_secondary   : bool;
}

Rendering_Task_Particles :: struct {
    #as using t     : Rendering_Task;
    t.type          = .PARTICLES;
    count           : s32;
    instance_offset : s32;
    blend_mode      : Particle_Blend_Mode;
    sheet           : sg_image;
}

Rendering_Task_Particles_Buffer :: struct {
    #as using t : Rendering_Task;
    t.type      = .PARTICLES_BUFFER;
    total_count : s32;
    pos_size    : [MAX_PARTICLES]Vector4;
    uv_rects    : [MAX_PARTICLES]Vector4;
    colors      : [MAX_PARTICLES]Vector4;
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
    trile_add_counter: s32 = 0;
    trile_rdm_add_counter: s32 = 0;
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
                updateCommand.trile          = trixelsTask.trile;
                updateCommand.colMultipliers = trixelsTask.colMultipliers;
                updateCommand.is_secondary   = trixelsTask.is_secondary;
                array_add(*render_command_buckets.setup, updateCommand);
                drawCommand := New(Render_Command_Draw_Trixels,, temp);
                drawCommand.world_offset  = trixelsTask.world_offset;
                drawCommand.brightness    = trixelsTask.brightness;
                drawCommand.tile_rotation = trixelsTask.tile_rotation;
                drawCommand.is_secondary  = trixelsTask.is_secondary;
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
                drawPositionsCmd.trile        = trileTask.trile;
                drawPositionsCmd.chunk_key    = trileTask.chunk_key;
                drawPositionsCmd.amount       = cast(s32)trileTask.positions.count;
                drawPositionsCmd.conf         = trileTask.worldConf;
                drawPositionsCmd.preview_mode = trileTask.preview_mode;
                drawPositionsCmd.offset_index = trile_add_counter;
                drawPositionsCmd.lod_index    = trileTask.lod_index;
                trile_add_counter += 1;
                if trileTask.shadow_only {
                    array_add(*render_command_buckets.shadow, drawPositionsCmd);
                } else if trileTask.preview_mode != 0 {
                    array_add(*render_command_buckets.main, drawPositionsCmd);
                } else if trileTask.skip_main {
                    array_add(*render_command_buckets.reflection, drawPositionsCmd);
                    array_add(*render_command_buckets.gbuffer, drawPositionsCmd);
                    array_add(*render_command_buckets.shadow, drawPositionsCmd);
                } else {
                    array_add(*render_command_buckets.reflection, drawPositionsCmd);
                    array_add(*render_command_buckets.main, drawPositionsCmd);
                    array_add(*render_command_buckets.gbuffer, drawPositionsCmd);
                    array_add(*render_command_buckets.shadow, drawPositionsCmd);
                }
            case .TRILE_RDM;
                rdmTask := (cast(*Rendering_Task_Trile_RDM)it);
                addCmd := New(Render_Command_Add_Trile_RDM_Position,, temp);
                addCmd.position = rdmTask.position;
                array_add(*render_command_buckets.setup, addCmd);
                drawCmd := New(Render_Command_Draw_Trile_RDM,, temp);
                drawCmd.trile        = rdmTask.trile;
                drawCmd.conf         = rdmTask.worldConf;
                drawCmd.atlas_rect   = rdmTask.atlas_rect;
                drawCmd.offset_index = trile_rdm_add_counter;
                trile_rdm_add_counter += 1;
                array_add(*render_command_buckets.main, drawCmd);
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
                commandDrawBillboard.faceDir = billboardTask.faceDir;
                commandDrawBillboard.animation = billboardTask.animation;
                array_add(*render_command_buckets.gbuffer, commandDrawBillboard);
                array_add(*render_command_buckets.main, commandDrawBillboard);
                array_add(*render_command_buckets.shadow, commandDrawBillboard);
                array_add(*render_command_buckets.reflection, commandDrawBillboard);
            case .PARTICLES_BUFFER;
                bufTask := cast(*Rendering_Task_Particles_Buffer)it;
                uploadCmd := New(Render_Command_Update_Particles,, temp);
                uploadCmd.total_count = bufTask.total_count;
                memcpy(uploadCmd.pos_size.data, bufTask.pos_size.data, bufTask.total_count * size_of(Vector4));
                memcpy(uploadCmd.uv_rects.data, bufTask.uv_rects.data, bufTask.total_count * size_of(Vector4));
                memcpy(uploadCmd.colors.data, bufTask.colors.data, bufTask.total_count * size_of(Vector4));
                array_add(*render_command_buckets.setup, uploadCmd);
            case .PARTICLES;
                particleTask := cast(*Rendering_Task_Particles)it;
                drawCmd := New(Render_Command_Draw_Particles,, temp);
                drawCmd.count           = particleTask.count;
                drawCmd.instance_offset = particleTask.instance_offset;
                drawCmd.blend_mode      = particleTask.blend_mode;
                drawCmd.sheet           = particleTask.sheet;
                array_add(*render_command_buckets.main, drawCmd);
                array_add(*render_command_buckets.reflection, drawCmd);
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
