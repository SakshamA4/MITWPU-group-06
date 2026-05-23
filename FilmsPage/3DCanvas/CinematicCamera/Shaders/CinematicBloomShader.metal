//
//  CinematicBloomShader.metal
//  FilmsPage
//
//  Metal compute kernels for cinematic bloom, halation, and film grain.
//  Uses a two-pass approach:
//    Pass 1: Extract bright pixels + horizontal Gaussian blur
//    Pass 2: Vertical Gaussian blur + composite bloom/halation/grain
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Uniform Buffer

struct BloomUniforms {
    float bloomStrength;      // Overall bloom intensity
    float bloomThreshold;     // Luminance threshold for bloom extraction
    float bloomRadius;        // Blur radius in pixels
    float halationStrength;   // Warm highlight bleed intensity
    float halationRadius;     // Halation blur radius
    float grainIntensity;     // Film grain overlay strength
    float grainSize;          // Grain particle size (1.0 = fine, 3.0 = coarse)
    float time;               // Animation time for grain variation
    float exposureBoost;      // Pre-bloom exposure adjustment
    float padding1;
    float padding2;
    float padding3;
};

// MARK: - Helpers

/// Fast luminance calculation (Rec. 709).
inline float luminance(float3 color) {
    return dot(color, float3(0.2126, 0.7152, 0.0722));
}

/// Hash function for procedural grain noise.
inline float hash(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

/// Value noise for organic-looking grain.
inline float valueNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f); // smoothstep
    
    float a = hash(i);
    float b = hash(i + float2(1.0, 0.0));
    float c = hash(i + float2(0.0, 1.0));
    float d = hash(i + float2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// MARK: - Pass 1: Bright Extract + Horizontal Blur

kernel void bloomExtractAndBlurH(
    texture2d<float, access::read>  inTexture   [[texture(0)]],
    texture2d<float, access::write> outTexture  [[texture(1)]],
    constant BloomUniforms &uniforms            [[buffer(0)]],
    uint2 gid                                   [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }
    
    float2 texSize = float2(inTexture.get_width(), inTexture.get_height());
    
    // Gaussian weights for 13-tap kernel
    const int KERNEL_SIZE = 6;
    float weights[7] = { 0.1964825, 0.2969069, 0.2195946, 0.1216216, 0.0540540, 0.0162162, 0.0032432 };
    
    float radius = uniforms.bloomRadius;
    
    // Horizontal Gaussian blur on bright-extracted pixels
    float4 result = float4(0.0);
    
    for (int i = -KERNEL_SIZE; i <= KERNEL_SIZE; i++) {
        int2 samplePos = int2(gid) + int2(i, 0) * int2(max(1, int(radius / float(KERNEL_SIZE))));
        samplePos.x = clamp(samplePos.x, 0, int(texSize.x) - 1);
        samplePos.y = clamp(samplePos.y, 0, int(texSize.y) - 1);
        
        float4 sampleColor = inTexture.read(uint2(samplePos));
        
        // Apply exposure boost
        sampleColor.rgb *= (1.0 + uniforms.exposureBoost);
        
        // Extract bright pixels above threshold
        float lum = luminance(sampleColor.rgb);
        float brightMask = smoothstep(uniforms.bloomThreshold, uniforms.bloomThreshold + 0.3, lum);
        sampleColor.rgb *= brightMask;
        
        float weight = weights[abs(i)];
        result += sampleColor * weight;
    }
    
    outTexture.write(result, gid);
}

// MARK: - Pass 2: Vertical Blur + Composite

kernel void bloomBlurVAndComposite(
    texture2d<float, access::read>  originalTexture [[texture(0)]],
    texture2d<float, access::read>  bloomTexture    [[texture(1)]],
    texture2d<float, access::write> outTexture      [[texture(2)]],
    constant BloomUniforms &uniforms                [[buffer(0)]],
    uint2 gid                                       [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }
    
    float2 texSize = float2(originalTexture.get_width(), originalTexture.get_height());
    float2 uv = float2(gid) / texSize;
    
    // --- Vertical Gaussian blur on bloom texture ---
    const int KERNEL_SIZE = 6;
    float weights[7] = { 0.1964825, 0.2969069, 0.2195946, 0.1216216, 0.0540540, 0.0162162, 0.0032432 };
    
    float radius = uniforms.bloomRadius;
    float4 bloomResult = float4(0.0);
    
    for (int i = -KERNEL_SIZE; i <= KERNEL_SIZE; i++) {
        int2 samplePos = int2(gid) + int2(0, i) * int2(max(1, int(radius / float(KERNEL_SIZE))));
        samplePos.x = clamp(samplePos.x, 0, int(texSize.x) - 1);
        samplePos.y = clamp(samplePos.y, 0, int(texSize.y) - 1);
        
        float4 sampleColor = bloomTexture.read(uint2(samplePos));
        float weight = weights[abs(i)];
        bloomResult += sampleColor * weight;
    }
    
    // --- Halation (warm-tinted wider bloom) ---
    float4 halation = float4(0.0);
    if (uniforms.halationStrength > 0.001) {
        float halRadius = uniforms.halationRadius;
        for (int i = -KERNEL_SIZE; i <= KERNEL_SIZE; i++) {
            int2 samplePos = int2(gid) + int2(0, i) * int2(max(1, int(halRadius / float(KERNEL_SIZE))));
            samplePos.x = clamp(samplePos.x, 0, int(texSize.x) - 1);
            samplePos.y = clamp(samplePos.y, 0, int(texSize.y) - 1);
            
            float4 sampleColor = bloomTexture.read(uint2(samplePos));
            float weight = weights[abs(i)];
            halation += sampleColor * weight;
        }
        // Warm tint for halation (film-like red/amber bleed)
        halation.rgb *= float3(1.3, 0.9, 0.6);
    }
    
    // --- Film Grain ---
    float grain = 0.0;
    if (uniforms.grainIntensity > 0.001) {
        float2 grainUV = uv * texSize / uniforms.grainSize;
        grainUV += float2(uniforms.time * 100.0, uniforms.time * 73.0);
        
        grain = valueNoise(grainUV) * 2.0 - 1.0;
        // Add a second octave for more organic feel
        grain += (valueNoise(grainUV * 2.7) * 2.0 - 1.0) * 0.5;
        grain *= 0.667; // Normalise
    }
    
    // --- Composite ---
    float4 original = originalTexture.read(gid);
    float4 finalColor = original;
    
    // Add bloom (additive)
    finalColor.rgb += bloomResult.rgb * uniforms.bloomStrength;
    
    // Add halation (additive with warm tint)
    finalColor.rgb += halation.rgb * uniforms.halationStrength;
    
    // Apply grain (multiplicative for shadow-heavy grain, additive for uniform)
    if (uniforms.grainIntensity > 0.001) {
        float lum = luminance(finalColor.rgb);
        // Grain is more visible in midtones, less in deep shadows and highlights
        float grainMask = smoothstep(0.05, 0.3, lum) * smoothstep(0.95, 0.7, lum);
        finalColor.rgb += grain * uniforms.grainIntensity * grainMask * 0.15;
    }
    
    // Clamp to valid range
    finalColor = clamp(finalColor, 0.0, 1.0);
    finalColor.a = original.a;
    
    outTexture.write(finalColor, gid);
}
