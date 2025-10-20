#scope_file

Random :: #import "Random";

#scope_export

g_ssao_samples : [64][4]float;
g_ssao_noise   : [16*4]float;

init_ssao :: () {
    for 0..63 {
        vec := Vector3.{
            Random.random_get_zero_to_one() * 2 - 1,
            Random.random_get_zero_to_one() * 2 - 1,
            Random.random_get_zero_to_one(),
        };
        vec = normalize(vec);
        vec *= Random.random_get_zero_to_one();
        scale := cast(float)it/64.0;
        scale = lerp(0.1, 1.0, scale*scale);
        vec *= scale;
        g_ssao_samples[it][0] = vec.x;
        g_ssao_samples[it][1] = vec.y;
        g_ssao_samples[it][2] = vec.z;
        g_ssao_samples[it][3] = 0;
    }
    for 0..15 {
        g_ssao_noise[it*4+0] = Random.random_get_zero_to_one() * 2 - 1; 
        g_ssao_noise[it*4+1] = Random.random_get_zero_to_one() * 2 - 1; 
        g_ssao_noise[it*4+2] = 0.0; 
        g_ssao_noise[it*4+3] = 0.0; 
    }
}
