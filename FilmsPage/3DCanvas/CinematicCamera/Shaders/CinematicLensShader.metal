//
//  CinematicLensShader.metal
//  FilmsPage
//
//  Metal compute kernel for realtime cinematic lens simulation.
//  Applies barrel/pincushion distortion, anamorphic stretch,
//  radial vignette, edge softness, and chromatic aberration
//  in a single GPU pass.
//
//  Uniform buffer layout matches LensSimulationEngine.generateShaderUniforms().
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Uniform Buffer

struct LensUniforms {
    float distortionK1;       // Brown-Conrady radial K1
    float distortionK2;       // Brown-Conrady radial K2
    float vignetteStrength;   // Radial darkening intensity
    float vignetteStart;      // Vignette falloff start radius (0-1)
    float edgeSoftness;       // Edge blur falloff amount
    float chromaticAberration;// Lateral CA offset amount
    float breathingShift;     // FOV shift from breathing (normalised)
    float bloomStrength;      // Bloom intensity (passed to bloom shader)
    float halationStrength;   // Halation intensity (passed to bloom shader)
    float flareIntensity;     // Lens flare (reserved)
    float anamorphicSqueeze;  // Anamorphic squeeze ratio (1.0 = spherical)
    float anamorphicStreak;   // Anamorphic streak intensity
    float grainAmount;        // Film grain (reserved for bloom pass)
    float aspectRatio;        // Output aspect ratio
    float sensorCropX;        // Sensor crop horizontal
    float sensorCropY;        // Sensor crop vertical
};

// MARK: - Helper Functions

/// Converts UV coordinates to centered coordinates (-1 to 1).
inline float2 uvToCentered(float2 uv) {
    return uv * 2.0 - 1.0;
}

/// Converts centered coordinates back to UV (0 to 1).
inline float2 centeredToUV(float2 centered) {
    return centered * 0.5 + 0.5;
}

/// Applies Brown-Conrady radial distortion.
inline float2 applyDistortion(float2 centered, float k1, float k2) {
    float r2 = dot(centered, centered);
    float r4 = r2 * r2;
    float factor = 1.0 + k1 * r2 + k2 * r4;
    return centered * factor;
}

/// Calculates vignette darkening factor.
inline float calculateVignette(float2 centered, float strength, float start) {
    float dist = length(centered);
    float falloff = smoothstep(start, 1.4, dist);
    return 1.0 - falloff * strength;
}

/// Calculates edge softness factor (1 = sharp, 0 = fully soft).
inline float calculateEdgeSoftness(float2 centered, float amount) {
    float dist = length(centered);
    float softStart = 1.0 - amount;
    float factor = 1.0 - smoothstep(softStart, 1.2, dist) * amount;
    return clamp(factor, 0.0, 1.0);
}

// MARK: - Main Kernel

kernel void cinematicLensKernel(
    texture2d<float, access::sample>  inTexture  [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant LensUniforms &uniforms            [[buffer(0)]],
    uint2 gid                                  [[thread_position_in_grid]]
) {
    // Bounds check
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }
    
    float2 texSize = float2(inTexture.get_width(), inTexture.get_height());
    float2 uv = float2(gid) / texSize;
    float2 centered = uvToCentered(uv);
    
    // Apply anamorphic squeeze (stretch horizontally for desqueeze)
    if (uniforms.anamorphicSqueeze > 1.001) {
        centered.x *= uniforms.anamorphicSqueeze;
    }
    
    // Apply sensor crop
    centered.x *= uniforms.sensorCropX;
    centered.y *= uniforms.sensorCropY;
    
    // Apply breathing shift (slight zoom)
    centered *= (1.0 + uniforms.breathingShift);
    
    // --- Chromatic Aberration ---
    // Shift R, G, B channels by different distortion amounts
    float caAmount = uniforms.chromaticAberration;
    
    // Red channel: slightly more distortion (shifts outward)
    float convergenceR = 1.0 + caAmount * 0.02;
    float2 centeredR = centered * convergenceR;
    float2 distortedR = applyDistortion(centeredR, uniforms.distortionK1, uniforms.distortionK2);
    float2 uvR = centeredToUV(distortedR);
    
    // Green channel: base distortion
    float2 distortedG = applyDistortion(centered, uniforms.distortionK1, uniforms.distortionK2);
    float2 uvG = centeredToUV(distortedG);
    
    // Blue channel: slightly less distortion (shifts inward)
    float convergenceB = 1.0 - caAmount * 0.02;
    float2 centeredB = centered * convergenceB;
    float2 distortedB = applyDistortion(centeredB, uniforms.distortionK1, uniforms.distortionK2);
    float2 uvB = centeredToUV(distortedB);
    
    // Sample each channel
    constexpr sampler texSampler(coord::normalized, address::clamp_to_edge, filter::linear);
    
    float r = inTexture.sample(texSampler, uvR).r;
    float g = inTexture.sample(texSampler, uvG).g;
    float b = inTexture.sample(texSampler, uvB).b;
    float a = inTexture.sample(texSampler, uvG).a;
    
    float4 color = float4(r, g, b, a);
    
    // --- Vignette ---
    float vignette = calculateVignette(centered, uniforms.vignetteStrength, uniforms.vignetteStart);
    color.rgb *= vignette;
    
    // --- Edge Softness ---
    // Blend with a slightly blurred sample at edges
    if (uniforms.edgeSoftness > 0.001) {
        float softFactor = calculateEdgeSoftness(centered, uniforms.edgeSoftness);
        if (softFactor < 0.999) {
            // Sample neighbours for box blur approximation at edges
            float2 offset = 1.5 / texSize;
            float4 blurred = float4(0.0);
            blurred += inTexture.sample(texSampler, uvG + float2(-offset.x, -offset.y));
            blurred += inTexture.sample(texSampler, uvG + float2( offset.x, -offset.y));
            blurred += inTexture.sample(texSampler, uvG + float2(-offset.x,  offset.y));
            blurred += inTexture.sample(texSampler, uvG + float2( offset.x,  offset.y));
            blurred *= 0.25;
            blurred.rgb *= vignette;
            
            color = mix(blurred, color, softFactor);
        }
    }
    
    // --- Anamorphic Streak ---
    if (uniforms.anamorphicStreak > 0.001) {
        // Horizontal streak from bright areas
        float luminance = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
        float streakMask = smoothstep(0.7, 1.0, luminance) * uniforms.anamorphicStreak;
        
        // Sample horizontal neighbours for streak
        float4 streak = float4(0.0);
        for (int i = 1; i <= 4; i++) {
            float w = 1.0 / float(i);
            float2 offsetH = float2(float(i) * 3.0 / texSize.x, 0.0);
            streak += inTexture.sample(texSampler, uvG + offsetH) * w;
            streak += inTexture.sample(texSampler, uvG - offsetH) * w;
        }
        streak /= 8.0;
        
        // Tint streak slightly blue for anamorphic feel
        streak.rgb *= float3(0.7, 0.8, 1.2);
        color.rgb += streak.rgb * streakMask * 0.5;
    }
    
    outTexture.write(color, gid);
}
