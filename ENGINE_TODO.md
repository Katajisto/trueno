# Todo for engine feature polish

## Particles
- Particle counts quite limited, increase.

## Post-processing
- DOF and bloom are both doing this thing where they draw to a small resolution buffer.
- It's performant now compared to old approach, but is bad. We need to do the blur thing
  in a shader X and Y separately for both.

## Trile rendering
- Too many triangles in meshgen.
- Shadowmap should move with camera.
- Reflection trile rendering is taking forever compared to gbuffer pass even though it
  shouldn't really be doing much more.
- 
