#version 460
#extension GL_EXT_scalar_block_layout : require
#extension GL_GOOGLE_include_directive : require
#include "../common.h"
#extension GL_EXT_ray_query : require

precision highp float;

const float PI = 3.14159265359;

layout(local_size_x = WORKGROUP_WIDTH, local_size_y = WORKGROUP_HEIGHT, local_size_z = 1) in;

layout(binding = BINDING_IMAGEDATA, set = 0, scalar) buffer storageBuffer
{
  vec3 imageData[];
};
layout(binding = BINDING_TLAS, set = 0) uniform accelerationStructureEXT tlas;
layout(binding = BINDING_VERTICES, set = 0, scalar) buffer Vertices
{
  vec3 vertices[];
};
layout(binding = BINDING_INDICES, set = 0, scalar) buffer Indices
{
  uint indices[];
};

layout(binding = BINDING_COLORS, set = 0, scalar) buffer Color
{
  vec4 colors[];
};

layout(binding = BINDING_ORIGINS, set = 0) buffer LayoutPixels
{
  LayoutPixel layoutbuf[];
};

layout(binding = BINDING_DEPTH, set = 0, scalar) buffer Depths
{
  vec3 depthData[];
};

layout(push_constant) uniform PushConsts
{
  PushConstants pushConstants;
};


// GGX

float ggx (vec3 N, vec3 V, vec3 L, float roughness, float F0) {
  float alpha = roughness*roughness;
  vec3 H = normalize(L - V);
  float dotLH = max(0.0, dot(L,H));
  float dotNH = max(0.0, dot(N,H));
  float dotNL = max(0.0, dot(N,L));
  float alphaSqr = alpha * alpha;
  float denom = dotNH * dotNH * (alphaSqr - 1.0) + 1.0;
  float D = alphaSqr / (3.141592653589793 * denom * denom);
  float F = F0 + (1.0 - F0) * pow(1.0 - dotLH, 5.0);
  float k = 0.5 * alpha;
  float k2 = k * k;
  return dotNL * D * F / (dotLH*dotLH*(1.0-k2)+k2);
}

vec3 fresnelSchlick(float cosTheta, vec3 F0) {
    //                               This clamp is different than in the exercise 7 instructions
    return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

float DistributionGGX(vec3 N, vec3 H, float roughness) {
    float a      = roughness*roughness;
    float a2     = a*a;
    float NdotH  = max(dot(N, H), 0.0);
    float NdotH2 = NdotH*NdotH;
    float num   = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;
    return num / denom;
}

float GeometrySchlickGGX(float NdotV, float roughness) {
    float r = (roughness + 1.0);
    float k = (r*r) / 8.0;
    float num   = NdotV;
    float denom = NdotV * (1.0 - k) + k;
    return num / denom;
}

float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness) {
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx2  = GeometrySchlickGGX(NdotV, roughness);
    float ggx1  = GeometrySchlickGGX(NdotL, roughness);
    return ggx1 * ggx2;
}

float GGXPDF(vec3 wo, vec3 wi, vec3 normal, float roughness) {
  return (GeometrySchlickGGX(dot(wi, normal), roughness) * GeometrySchlickGGX(dot(wo, normal), roughness)) / GeometrySchlickGGX(dot(wi, normal), roughness);
}

vec3 SampleVndf_GGX(vec2 u, vec3 wi, float alpha, vec3 n)
{
    // decompose the vector in parallel and perpendicular components
    vec3 wi_z = n * dot(wi, n);
    vec3 wi_xy = wi - wi_z;
    // warp to the hemisphere configuration
    vec3 wiStd = normalize(wi_z - alpha * wi_xy);
    // sample a spherical cap in (-wiStd.z, 1]
    float wiStd_z = dot(wiStd, n);
    float phi = (2.0f * u.x - 1.0f) * PI;
    float z = (1.0f - u.y) * (1.0f + wiStd_z) - wiStd_z;
    float sinTheta = sqrt(clamp(1.0f - z * z, 0.0f, 1.0f));
    float x = sinTheta * cos(phi);
    float y = sinTheta * sin(phi);
    vec3 cStd = vec3(x, y, z);
    // reflect sample to align with normal
    vec3 up = vec3(0, 0, 1);
    vec3 wr = n + up;
    float wrz_safe = max(wr.z, 1e-6);
    vec3 c = dot(wr, cStd) * wr / wrz_safe - cStd;
    // compute halfway direction as standard normal
    vec3 wmStd = c + wiStd;
    vec3 wmStd_z = n * dot(n, wmStd);
    vec3 wmStd_xy = wmStd_z - wmStd;
    // warp back to the ellipsoid configuration
    vec3 wm = normalize(wmStd_z + alpha * wmStd_xy);
    // return final normal
    return wm;
}

float pdf_vndf_isotropic(vec3 wo, vec3 wi, float alpha, vec3 n)
{
    float alphaSquare = alpha * alpha;
    vec3 wm = normalize(wo + wi);
    float zm = dot(wm, n);
    float zi = dot(wi, n);
    float nrm = inversesqrt((zi * zi) * (1.0f - alphaSquare) + alphaSquare);
    float sigmaStd = (zi * nrm) * 0.5f + 0.5f;
    float sigmaI = sigmaStd / nrm;
    float nrmN = (zm * zm) * (alphaSquare - 1.0f) + 1.0f;
    return alphaSquare / (PI * 4.0f * nrmN * nrmN * sigmaI);
}

// ----- SKY SHADER -------

const float time = 0.0;
const float cirrus = 0.5;
const float cumulus = 0.6;

vec4 skyBase =  vec4(0.3843, 0.8117, 0.9568, 1.0); //vec4(0.3843, 0.8117, 0.9568, 1.0);
vec4 skyTop = vec4(0.17, 0.4, 0.95, 1.0); //vec4(0.17, 0.4, 0.95, 1.0);
vec4 sunDisk = vec4(1.0, 1.0, 1.0, 1.0); //vec4(1.0, 1.0, 1.0, 1.0);
vec4 horizonHalo = vec4(1.0, 1.0, 1.0, 1.0); //vec4(1.0, 1.0, 1.0, 1.0);
vec4 sunHalo = vec4(1.0, 1.0, 1.0, 1.0); //vec4(1.0, 1.0, 1.0, 1.0);

float hash(float n)
{
    return fract(sin(n) * 43758.5453123);
}

float noise(vec3 x)
{
    vec3 f = fract(x);
    float n = dot(floor(x), vec3(1.0, 157.0, 113.0));
    return mix(mix(mix(hash(n +   0.0), hash(n +   1.0), f.x),
    mix(hash(n + 157.0), hash(n + 158.0), f.x), f.y),
    mix(mix(hash(n + 113.0), hash(n + 114.0), f.x),
    mix(hash(n + 270.0), hash(n + 271.0), f.x), f.y), f.z);
}

const mat3 m = mat3(0.0, 1.60,  1.20, -1.6, 0.72, -0.96, -1.2, -0.96, 1.28);
float fbm(vec3 p)
{
    float f = 0.0;
    f += noise(p) / 2.0; p = m * p * 1.1;
    f += noise(p) / 4.0; p = m * p * 1.2;
    f += noise(p) / 6.0; p = m * p * 1.3;
    f += noise(p) / 12.0; p = m * p * 1.4;
    f += noise(p) / 24.0;
    return f;
}

vec3 sky(vec3 skypos, vec3 sunpos) {
    vec3 sunCol = sunDisk.xyz;
    vec3 baseSky = skyBase.xyz;
    vec3 topSky = skyTop.xyz;

    float sDist = dot(normalize(skypos), normalize(sunpos));

    vec3 npos = normalize(skypos);


    vec3 skyGradient = mix(baseSky, topSky, clamp(skypos.y * 2.0, 0.0, 0.7));

    vec3 final = skyGradient;
    final += sunHalo.xyz * clamp((sDist - 0.95) * 10.0, 0.0, 0.8) * 0.2;

    // Sun disk
    if(sDist > 0.9999) {
        final = sunDisk.xyz;
    }

    // Horizon halo
    final += mix(horizonHalo.xyz, vec3(0.0,0.0,0.0), clamp(abs(npos.y) * 80.0, 0.0, 1.0)) * 0.1;

    final = vec3(final);

    // Cirrus Clouds
    float density = smoothstep(1.0 - cirrus, 1.0, fbm(npos.xyz / npos.y * 2.0 + time * 0.05)) * 0.3;
    final.rgb = mix(final.rgb, vec3(1.0, 1.0, 1.0), max(0.0, npos.y) * density * 2.0);

    final += noise(skypos * 1000.0) * 0.02;
    return final;
}

// --- END SKY ----


// Random number generation using pcg32i_random_t, using inc = 1. Our random state is a uint.
uint stepRNG(uint rngState)
{
  return rngState * 747796405 + 1;
}

// Steps the RNG and returns a floating-point value between 0 and 1 inclusive.
float stepAndOutputRNGFloat(inout uint rngState)
{
  // Condensed version of pcg_output_rxs_m_xs_32_32, with simple conversion to floating-point [0,1].
  rngState  = stepRNG(rngState);
  uint word = ((rngState >> ((rngState >> 28) + 4)) ^ rngState) * 277803737;
  word      = (word >> 22) ^ word;
  return float(word) / 4294967295.0f;
}

// Returns the color of the sky in a given direction (in linear color space)
vec3 skyColor(vec3 direction)
{
  // +y in world space is up, so:
  if(direction.y > 0.0f)
  {
    return mix(vec3(1.0f), vec3(0.25f, 0.5f, 1.0f), direction.y);
  }
  else
  {
    return vec3(0.03f);
  }
}

vec3 randomSpherePoint(vec3 rand) {
  float ang1 = (rand.x + 1.0) * PI; // [-1..1) -> [0..2*PI)
  float u = rand.y; // [-1..1), cos and acos(2v-1) cancel each other out, so we arrive at [-1..1)
  float u2 = u * u;
  float sqrt1MinusU2 = sqrt(1.0 - u2);
  float x = sqrt1MinusU2 * cos(ang1);
  float y = sqrt1MinusU2 * sin(ang1);
  float z = u;
  return vec3(x, y, z);
}

vec3 randomHemispherePoint(vec3 rand, vec3 n) {
  vec3 v = randomSpherePoint(rand);
  vec3 v2 = v * sign(dot(v, n));
  if(length(v2) < 0.0001) {
    return n;
  }
  return v2;
}

struct HitInfo
{
  vec3 color;
  vec3 worldPosition;
  vec3 worldNormal;
  vec3 emission;
  int isWater;
  float metallic;
  float roughness;
};

HitInfo getObjectHitInfo(rayQueryEXT rayQuery)
{
  HitInfo result;
  // Get the ID of the triangle
  const int primitiveID = rayQueryGetIntersectionPrimitiveIndexEXT(rayQuery, true);
  uint offset = rayQueryGetIntersectionInstanceShaderBindingTableRecordOffsetEXT(rayQuery, true);
  int colorOffset = rayQueryGetIntersectionInstanceCustomIndexEXT(rayQuery, true);

  
  // Get the indices of the vertices of the triangle
  const uint i0 = indices[offset + 3 * primitiveID + 0];
  const uint i1 = indices[offset + 3 * primitiveID + 1];
  const uint i2 = indices[offset + 3 * primitiveID + 2];

  // Get the vertices of the triangle
  const vec3 v0 = vertices[i0];
  const vec3 v1 = vertices[i1];
  const vec3 v2 = vertices[i2];

  // Get the barycentric coordinates of the intersection
  vec3 barycentrics = vec3(0.0, rayQueryGetIntersectionBarycentricsEXT(rayQuery, true));
  barycentrics.x    = 1.0 - barycentrics.y - barycentrics.z;

  // Compute the coordinates of the intersection
  const vec3 objectPos = v0 * barycentrics.x + v1 * barycentrics.y + v2 * barycentrics.z;
  const mat4x3 objectToWorld = rayQueryGetIntersectionObjectToWorldEXT(rayQuery, true);
  result.worldPosition       = objectToWorld * vec4(objectPos, 1.0f);

  const vec3 objectNormal = cross(v1 - v0, v2 - v0);
  // Transform normals from object space to world space. These use the transpose of the inverse matrix,
  // because they're directions of normals, not positions:
  const mat4x3 objectToWorldInverse = rayQueryGetIntersectionWorldToObjectEXT(rayQuery, true);
  result.worldNormal                = normalize((objectNormal * objectToWorldInverse).xyz);
  
  result.emission = vec3(0);
  
  if(colorOffset == 121212) {
    result.color = vec3(0.9, 0.9, 1.0);
    result.isWater = 1;
    return result;
  }

  // Calculate position inside the model, and use it to get the color for the trixel...
  //result.color = vec3(objectPos.x, objectPos.y, objectPos.z);
  const vec3 objectTexturePos = objectPos - objectNormal * 0.005;
  int cx = int(objectTexturePos.z * 16);
  int cy = int(objectTexturePos.y * 16);
  int cz = int(objectTexturePos.x * 16);

  
  if(cx > 15) cx = 15;
  if(cy > 15) cy = 15;
  if(cz > 15) cz = 15;
  vec4 color = colors[colorOffset + cx + cy * 16 + cz * 16 * 16];
  result.color = color.xyz;
  // result.color = vec3(0.5, 0.2, 0.6);
  int packedMaterial = int(color.w * 255.0);
  float emittance = float((packedMaterial >> 1) & 0x3) / 3.0;
  result.roughness = max(float((packedMaterial >> 5) & 0x7) / 7.0, 0.01);
  result.metallic = float((packedMaterial >> 3) & 0x3) / 3.0;
  bool roughFlag = (packedMaterial & 0x1) != 0;
  
  if(emittance > 0) {
    result.color = vec3(1.0, 1.0, 1.0);
    result.emission = result.color * 50.0 * emittance;
  }
  // result.color = vec3(float(cx) / 15.0, float(cy) / 15.0, 0.0);
  // result.color = vec3(result.worldNormal);
  result.isWater = 0;

  const float dotX = dot(result.worldNormal, vec3(0.0, 1.0, 0.0));

  return result;
}

vec3 wave(vec4 wave, vec3 p, inout vec3 tangent, inout vec3 binormal) {
    float steepness = wave.z;
    float wavelength = wave.w;
    float k = 2.0 * 3.141 / wavelength;
	float c = 2.0;
	vec2 d = normalize(vec2(wave.x, wave.y));
	float f = k * (dot(d, p.xz) - c * (0.0 * 0.3));
	float a = steepness / k;
	
	tangent += vec3(
		-d.x * d.x * (steepness * sin(f)),
		d.x * (steepness * cos(f)),
		-d.x * d.y * (steepness * sin(f))
	);
    
	binormal += vec3(
		-d.x * d.y * (steepness * sin(f)),
		d.y * (steepness * cos(f)),
		-d.y * d.y * (steepness * sin(f))
	);
    
	return vec3(
		d.x * (a * cos(f)),
		a * sin(f),
		d.y * (a * cos(f))
	);
}

vec3 ImportanceSampleGGX(vec2 Xi, vec3 N, float roughness)
{
    float a = roughness*roughness;
	
    float phi = 2.0 * PI * Xi.x;
    float cosTheta = sqrt((1.0 - Xi.y) / (1.0 + (a*a - 1.0) * Xi.y));
    float sinTheta = sqrt(1.0 - cosTheta*cosTheta);
	
    // from spherical coordinates to cartesian coordinates
    vec3 H;
    H.x = cos(phi) * sinTheta;
    H.y = sin(phi) * sinTheta;
    H.z = cosTheta;
	
    // from tangent-space vector to world-space sample vector
    vec3 up        = abs(N.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
    vec3 tangent   = normalize(cross(up, N));
    vec3 bitangent = cross(N, tangent);
	
    vec3 sampleVec = tangent * H.x + bitangent * H.y + N * H.z;
    return normalize(sampleVec);
}  

vec3 BRDF_spec_ggx(vec3 normal, vec3 incoming, vec3 outgoing, vec3 color, float metallic, float roughness) {
  vec3 N = normal;
  vec3 L = outgoing;
  vec3 V = incoming;
  vec3 H = normalize(V + L);
  vec3 F0 = vec3(0.04);
  F0 = mix(F0, color, metallic);
  vec3 F = fresnelSchlick(max(dot(H,V), 0.0), F0);
  float NDF = DistributionGGX(N, H, roughness);
  float G = GeometrySmith(N, V, L, roughness);
  vec3 numerator = NDF * G * F;
  float denominator = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0)  + 0.001;
  vec3 specular = numerator / denominator;
  vec3 kD = vec3(1.0) - F;
  kD *= 1.0 - metallic;
  return specular;
}

vec3 BRDF_spec(vec3 normal, vec3 incoming, vec3 outgoing, vec3 color, float metallic, float roughness) {
  vec3 N = normal;
  vec3 L = outgoing;
  vec3 V = incoming;
  vec3 H = normalize(V + L);
  vec3 F0 = vec3(0.04);
  F0 = mix(F0, color, metallic);
  vec3 F = fresnelSchlick(max(dot(H,V), 0.0), F0);
  float denominator = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0)  + 0.001;
  vec3 specular = F / denominator;
  return specular;
}

vec3 BRDF_diff(vec3 normal, vec3 incoming, vec3 outgoing, vec3 color, float metallic, float roughness) {
  vec3 N = normal;
  vec3 L = outgoing;
  vec3 V = incoming;
  vec3 H = normalize(V + L);
  vec3 F0 = vec3(0.04);
  F0 = mix(F0, color, metallic);
  vec3 F = fresnelSchlick(max(dot(H,V), 0.0), F0);
  vec3 kD = vec3(1.0) - F;
  kD *= 1.0 - metallic;
  return (kD * color / PI);
}

vec3 BRDF(vec3 normal, vec3 incoming, vec3 outgoing, vec3 color, float metallic, float roughness) {
  vec3 N = normal;
  vec3 L = outgoing;
  vec3 V = incoming;
  vec3 H = normalize(V + L);
  vec3 F0 = vec3(0.04);
  F0 = mix(F0, color, metallic);
  vec3 F = fresnelSchlick(max(dot(H,V), 0.0), F0);
  float NDF = DistributionGGX(N, H, roughness);
  float G = GeometrySmith(N, V, L, roughness);
  vec3 numerator = NDF * G * F;
  float denominator = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0)  + 0.001;
  vec3 specular = numerator / denominator;
  vec3 kD = vec3(1.0) - F;
  kD *= 1.0 - metallic;
  return (kD * color / PI + specular);
}

vec3 filmic_aces(vec3 v)
{
    v = v * mat3(
        0.59719f, 0.35458f, 0.04823f,
        0.07600f, 0.90834f, 0.01566f,
        0.02840f, 0.13383f, 0.83777f
    );
    return (v * (v + 0.0245786f) - 9.0537e-5f) /
        (v * (0.983729f * v + 0.4329510f) + 0.238081f) * mat3(
        1.60475f, -0.53108f, -0.07367f,
        -0.10208f,  1.10813f, -0.00605f,
        -0.00327f, -0.07276f,  1.07602f
    );
}

vec3 ImportanceSampleCosine(vec2 Xi, vec3 N) {
    // Create basis from normal
    vec3 B1, B2;
    if (abs(N.x) < abs(N.y)) {
        B1 = normalize(cross(N, vec3(1.0, 0.0, 0.0)));
    } else {
        B1 = normalize(cross(N, vec3(0.0, 1.0, 0.0)));
    }
    B2 = cross(N, B1);

    // Cosine weighted sampling
    float phi = 2.0 * PI * Xi.x;
    float cosTheta = sqrt(Xi.y);
    float sinTheta = sqrt(1.0 - cosTheta * cosTheta);

    // Convert to cartesian coordinates
    vec3 H;
    H.x = cos(phi) * sinTheta;
    H.y = sin(phi) * sinTheta;
    H.z = cosTheta;

    // Transform from local space to world space
    return normalize(H.x * B1 + H.y * B2 + H.z * N);
}

void main()
{
    const uvec2 resolution = uvec2(pushConstants.render_width, pushConstants.render_height);
  
    const uvec2 pixel = gl_GlobalInvocationID.xy;
    if((pixel.x >= resolution.x) || (pixel.y >= resolution.y)) {
      return;
    }

    uint linearIndex = resolution.x * pixel.y + pixel.x;

    uint rngState = (pushConstants.sample_batch * resolution.y + pixel.y) * 3 * (pushConstants.sample_batch + 20) * resolution.x + pixel.x;

    const vec3 cameraOrigin = vec3(5.0, 5.0, 5.0);
    const vec3 lookAt = vec3(2.5, 0.0, 2.5);
    const vec3 generalDirection = normalize(lookAt - cameraOrigin);
    const vec3 up = vec3(0.0, 1.0, 0.0);
    const vec3 right = cross(generalDirection, up);

    const float fovVerticalSlope = 1.0 / 5.0;
    highp vec3 summedPixelColor = vec3(0.0);

    const int NUM_SAMPLES = 10;

    float depth = 99999999.0;

    for(int sampleIdx = 0; sampleIdx < NUM_SAMPLES; sampleIdx++) {
      // vec3 rayOrigin = cameraOrigin;
      

      // const vec2 randomPixelCenter = vec2(pixel) + vec2(stepAndOutputRNGFloat(rngState), stepAndOutputRNGFloat(rngState));
      // const vec2 screenUV = vec2(2.0 * (float(randomPixelCenter.x) + 0.5 - 0.5 * resolution.x) / resolution.y,    //
      //                            -(2.0 * (float(randomPixelCenter.y) + 0.5 - 0.5 * resolution.y) / resolution.y)  // Flip the y axis
      // );
    
      // vec3 rayDirection = vec3(generalDirection + right * screenUV.x + up * screenUV.y);
      // rayDirection = normalize(rayDirection);


      vec2 Xi;
      Xi.x = stepAndOutputRNGFloat(rngState);
      Xi.y = stepAndOutputRNGFloat(rngState);
    
      float rayDirectionArr[3] = layoutbuf[linearIndex].direction;
      float rayOriginArr[3] = layoutbuf[linearIndex].origin;
      float rayRoughness = layoutbuf[linearIndex].roughness;
      vec3 rayDirection = vec3(rayDirectionArr[0], rayDirectionArr[1], rayDirectionArr[2]);
      vec3 rayOrigin = vec3(rayOriginArr[0], rayOriginArr[1], rayOriginArr[2]);
      
      if(rayRoughness < 0.98) {
        vec3 H = ImportanceSampleGGX(Xi, rayDirection, max(0.01, rayRoughness));
        vec3 L = normalize(2.0 * dot(rayDirection, H) * H - rayDirection);
        rayDirection = L;
      } else {
        vec3 randV;
        randV.x = stepAndOutputRNGFloat(rngState);
        randV.y = stepAndOutputRNGFloat(rngState);
        randV.z = stepAndOutputRNGFloat(rngState);
        randV = normalize(randV);
        rayDirection = randomHemispherePoint(randV, rayDirection);
      }
      
      vec3 attenuation = vec3(1.0);
       
      // vec3 sunDir = normalize(vec3(0.7, 0.6, 0.6));
      vec3 sunDir = normalize(vec3(pushConstants.sunPosition.x, pushConstants.sunPosition.y, pushConstants.sunPosition.z));
      // vec3 sunDir = normalize(vec3(0.3, 0.6, 0.4));
    
      vec3 randV;
      randV.x = stepAndOutputRNGFloat(rngState);
      randV.y = stepAndOutputRNGFloat(rngState);
      randV.z = stepAndOutputRNGFloat(rngState);
      randV = normalize(randV);

      float regularization = 1.0;
      for(int tracedSegments = 0; tracedSegments < 12; tracedSegments++) {
        float raySelector = stepAndOutputRNGFloat(rngState); 
        rayQueryEXT rayQuery;
        rayQueryInitializeEXT(rayQuery, tlas, gl_RayFlagsOpaqueEXT, 0xFF, rayOrigin, 0.0, rayDirection, 10000.0);
        while(rayQueryProceedEXT(rayQuery)) {}
        if(rayQueryGetIntersectionTypeEXT(rayQuery, true) == gl_RayQueryCommittedIntersectionTriangleEXT) {
          HitInfo hitInfo = getObjectHitInfo(rayQuery);

          if(tracedSegments == 0) {
            depth = min(depth, length(hitInfo.worldPosition - rayOrigin));
            if(depth < 0.01) {
              
              break;
            }
          }
      
          if(hitInfo.isWater == 1) {
            // vec3 waterTangent = vec3(1.0, 0.0, 0.0);
            // vec3 waterBinormal = vec3(0.0, 0.0, 1.0);
            vec3 p = vec3(0.0);
            // p += wave(vec4(1.0, 0.0, 0.06, 1.0), hitInfo.worldPosition, waterTangent, waterBinormal);
            // p += wave(vec4(1.0, 1.0, 0.04, 0.3), hitInfo.worldPosition, waterTangent, waterBinormal);
            // p += wave(vec4(1.0, 0.5, 0.04, 0.2), hitInfo.worldPosition, waterTangent, waterBinormal);
            // vec3 waterNormal = normalize(cross(normalize(waterBinormal), normalize(waterTangent)));
            hitInfo.worldNormal = faceforward(hitInfo.worldNormal, rayDirection, hitInfo.worldNormal);
            rayOrigin = hitInfo.worldPosition + 0.01 * hitInfo.worldNormal;
            vec3 oldDirection = rayDirection;
            rayDirection = normalize(reflect(rayDirection, hitInfo.worldNormal));
            rayQueryInitializeEXT(rayQuery, tlas, gl_RayFlagsOpaqueEXT, 0xFF, rayOrigin, 0.0, normalize(sunDir), 10000.0);
            while(rayQueryProceedEXT(rayQuery)) {}
            // if(rayQueryGetIntersectionTypeEXT(rayQuery, true) != gl_RayQueryCommittedIntersectionTriangleEXT) {
            //   summedPixelColor += max(dot(normalize(sunDir - oldDirection), waterNormal), 0.0) * attenuation * 0.3;
            // }
            attenuation *= hitInfo.color;
          } else {
            // Add emission:
            summedPixelColor += attenuation * hitInfo.emission;

            hitInfo.worldNormal = faceforward(hitInfo.worldNormal, rayDirection, hitInfo.worldNormal);
            rayOrigin = hitInfo.worldPosition + 0.001 * hitInfo.worldNormal;
            vec3 randV;
            randV.x = stepAndOutputRNGFloat(rngState);
            randV.y = stepAndOutputRNGFloat(rngState);
            randV.z = stepAndOutputRNGFloat(rngState);
            randV = normalize(randV);
          
            vec3 oldDirection = rayDirection;
          
            if(raySelector > 0.5) { // DIFFUSE
              // Cast ray towards sun to check sun situation:

              rayDirection = randomHemispherePoint(randV, hitInfo.worldNormal);
              rayDirection = normalize(rayDirection);
              float regularizationGamma = 0.5;
              float bsdf_pdf = (1.0 / (PI * 2.0)) * 0.5;
              if(bsdf_pdf != 0.0f) regularization *= max(1 - regularizationGamma / pow(bsdf_pdf, 0.25f), 0.0f);
              hitInfo.roughness = 1.0f - ((1.0f - hitInfo.roughness) * regularization);
              attenuation *= abs(dot(rayDirection, hitInfo.worldNormal));
              attenuation *= BRDF_diff(hitInfo.worldNormal, -oldDirection, rayDirection, hitInfo.color, hitInfo.metallic, hitInfo.roughness);
              attenuation /= bsdf_pdf;
              rayQueryInitializeEXT(rayQuery, tlas, gl_RayFlagsOpaqueEXT, 0xFF, rayOrigin, 0.0, normalize(sunDir), 10000.0);
              while(rayQueryProceedEXT(rayQuery)) {}
              if(rayQueryGetIntersectionTypeEXT(rayQuery, true) != gl_RayQueryCommittedIntersectionTriangleEXT) {
                summedPixelColor += attenuation * BRDF_diff(hitInfo.worldNormal, -oldDirection, sunDir, hitInfo.color, hitInfo.metallic, hitInfo.roughness)  * vec3(pushConstants.sunIntensity) * max(0.0, dot(sunDir, hitInfo.worldNormal));
              }
            } else { // SPECULAR
              if(hitInfo.roughness > 0.01) {
                vec3 microfacetNormal = SampleVndf_GGX(vec2(randV.x, randV.y), -oldDirection, hitInfo.roughness, hitInfo.worldNormal);
                rayDirection = reflect(oldDirection, microfacetNormal);
                rayDirection = normalize(rayDirection);
                float regularizationGamma = 0.5;
                float bsdf_pdf = pdf_vndf_isotropic(rayDirection, -oldDirection, hitInfo.roughness, hitInfo.worldNormal) * 0.5;
                if(bsdf_pdf != 0.0f) regularization *= max(1 - regularizationGamma / pow(bsdf_pdf, 0.25f), 0.0f);
                hitInfo.roughness = 1.0f - ((1.0f - hitInfo.roughness) * regularization);
                attenuation *= abs(dot(rayDirection, hitInfo.worldNormal));
                attenuation *= BRDF_spec_ggx(hitInfo.worldNormal, -oldDirection, rayDirection, hitInfo.color, hitInfo.metallic, hitInfo.roughness);
                attenuation /= bsdf_pdf;
              } else {
                vec3 microfacetNormal = hitInfo.worldNormal;
                rayDirection = reflect(oldDirection, microfacetNormal);
                rayDirection = normalize(rayDirection);
                float regularizationGamma = 0.5;
                hitInfo.roughness = 1.0f - ((1.0f - hitInfo.roughness) * regularization);
                attenuation *= abs(dot(rayDirection, hitInfo.worldNormal));
                attenuation *= BRDF_spec(hitInfo.worldNormal, -oldDirection, rayDirection, hitInfo.color, hitInfo.metallic, hitInfo.roughness);
                attenuation /= 0.5;
              }
              rayQueryInitializeEXT(rayQuery, tlas, gl_RayFlagsOpaqueEXT, 0xFF, rayOrigin, 0.0, normalize(sunDir), 10000.0);
              while(rayQueryProceedEXT(rayQuery)) {}
              if(rayQueryGetIntersectionTypeEXT(rayQuery, true) != gl_RayQueryCommittedIntersectionTriangleEXT) {
                summedPixelColor += attenuation * BRDF_spec_ggx(hitInfo.worldNormal, -oldDirection, sunDir, hitInfo.color, hitInfo.metallic, hitInfo.roughness)  * vec3(pushConstants.sunIntensity) * max(0.0, dot(sunDir, hitInfo.worldNormal));
              }
            }
          }
        } else {
          summedPixelColor += sky(rayDirection, sunDir) * attenuation;
          // summedPixelColor += rayDirection * attenuation;
          break;
        }
      }
    }
    
    // Get the index of this invocation in the buffer:
    // Blend with the averaged image in the buffer:
    vec3 averagePixelColor = vec3(summedPixelColor / float(NUM_SAMPLES));
    if(any(isnan(averagePixelColor))) {
      averagePixelColor = vec3(0.0, 0.0, 0.0);
    }
    if(pushConstants.sample_batch != 0)
    {
      averagePixelColor = (pushConstants.sample_batch * imageData[linearIndex] + vec3(averagePixelColor)) / (pushConstants.sample_batch + 1);
    }
    if(pushConstants.sample_batch == pushConstants.max_batch - 1) {
      imageData[linearIndex] = averagePixelColor;
      depthData[linearIndex] = vec3(depth, 0.0, 0.0);
    } else {
      imageData[linearIndex] = averagePixelColor;
    }
}
