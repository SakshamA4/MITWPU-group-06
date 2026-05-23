//
//  CinematicDoFShader.metal
//  FilmsPage
//
//  Metal compute kernel for physically-based depth-of-field simulation.
//  Implements circle-of-confusion (CoC) based variable-radius disk blur
//  with bokeh shape approximation. Two passes:
//    Pass 1: Compute CoC map from depth buffer + camera parameters
//    Pass 2: Apply variable-radius gather blur weighted by CoC
//
//  Camera parameters:
//    - Focal length (mm)
//    - Aperture (f-stop)
//    - Focus distance (metres)
//    - Sensor width (mm)
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Uniforms

struct DoFUniforms {
    float focalLengthMM;      // Lens focal length in mm
    float aperture;           // f-stop number (e.g. 2.8)
    float focusDistanceM;     // Focus distance in metres
    float sensorWidthMM;      // Sensor width in mm
    float imageWidth;         // Output image width in pixels
    float imageHeight;        // Output image height in pixels
    float maxBlurRadius;      // Maximum blur radius in pixels (quality cap)
    float bokehRoundness;     // 0.0 = hexagonal, 1.0 = circular
    float cocScale;           // Artistic CoC scale multiplier
    float foregroundBleed;    // How much foreground blur bleeds into focus
};

// MARK: - Pass 1: Circle of Confusion Map

/// Computes the circle of confusion diameter for each pixel
/// based on the thin-lens equation:
///   CoC = |S2 - S1| / S2 * (f² / (N * (S1 - f)))
/// where:
///   f  = focal length
///   N  = aperture (f-number)
///   S1 = focus distance
///   S2 = pixel depth
kernel void computeCoC(
    texture2d<float, access::read>  depthTexture  [[texture(0)]],
    texture2d<float, access::write> cocTexture    [[texture(1)]],
    constant DoFUniforms &uniforms                [[buffer(0)]],
    uint2 gid                                     [[thread_position_in_grid]]
) {
    if (gid.x >= uint(uniforms.imageWidth) || gid.y >= uint(uniforms.imageHeight)) return;
    
    // Read depth value (0 = near, 1 = far, linearised)
    float depth = depthTexture.read(gid).r;
    
    // Convert normalised depth to world-space distance (approximate)
    // Map [0,1] to [0.1m, 100m] range with exponential distribution
    float nearPlane = 0.1;
    float farPlane = 100.0;
    float pixelDistanceM = nearPlane + depth * (farPlane - nearPlane);
    pixelDistanceM = max(pixelDistanceM, 0.1);
    
    // Thin lens CoC calculation
    float f = uniforms.focalLengthMM * 0.001;        // Convert mm to metres
    float N = uniforms.aperture;
    float S1 = uniforms.focusDistanceM;
    float S2 = pixelDistanceM;
    
    // Signed CoC: negative = foreground, positive = background
    float cocMetres = (f * f * (S2 - S1)) / (N * S2 * (S1 - f));
    
    // Convert CoC from metres to pixels
    float sensorW = uniforms.sensorWidthMM * 0.001;  // mm to metres
    float cocPixels = (cocMetres / sensorW) * uniforms.imageWidth;
    
    // Apply artistic scale
    cocPixels *= uniforms.cocScale;
    
    // Clamp to maximum blur radius
    float clampedCoC = clamp(cocPixels, -uniforms.maxBlurRadius, uniforms.maxBlurRadius);
    
    // Store: R = signed CoC, G = absolute CoC (for blur radius), B = depth, A = 1
    float absCoC = abs(clampedCoC);
    float signedNorm = clampedCoC / max(uniforms.maxBlurRadius, 1.0); // -1 to 1
    
    cocTexture.write(float4(signedNorm, absCoC, depth, 1.0), gid);
}

// MARK: - Pass 2: Gather Blur with Bokeh

/// Variable-radius disk blur that samples neighboring pixels weighted by
/// their CoC values. Approximates bokeh shapes through angular weighting.
kernel void applyDoFBlur(
    texture2d<float, access::read>  sourceTexture [[texture(0)]],
    texture2d<float, access::read>  cocTexture    [[texture(1)]],
    texture2d<float, access::write> outputTexture [[texture(2)]],
    constant DoFUniforms &uniforms                [[buffer(0)]],
    uint2 gid                                     [[thread_position_in_grid]]
) {
    if (gid.x >= uint(uniforms.imageWidth) || gid.y >= uint(uniforms.imageHeight)) return;
    
    float4 cocData = cocTexture.read(gid);
    float centerCoC = cocData.y;  // Absolute CoC radius
    float centerSign = cocData.x; // Signed normalised CoC
    
    // If CoC is tiny, pixel is in focus — skip blur
    if (centerCoC < 0.5) {
        outputTexture.write(sourceTexture.read(gid), gid);
        return;
    }
    
    // Adaptive sample count based on blur radius
    float blurRadius = min(centerCoC, uniforms.maxBlurRadius);
    int sampleRadius = int(ceil(blurRadius));
    sampleRadius = min(sampleRadius, 16); // Cap for performance
    
    float4 colorSum = float4(0.0);
    float weightSum = 0.0;
    
    // Disk sampling with concentric rings
    int numRings = max(sampleRadius / 2, 1);
    
    for (int ring = 0; ring <= numRings; ring++) {
        float ringRadius = (float(ring) / float(max(numRings, 1))) * blurRadius;
        
        // Number of samples per ring scales with radius
        int samplesInRing = (ring == 0) ? 1 : max(ring * 6, 6);
        
        for (int s = 0; s < samplesInRing; s++) {
            float angle = float(s) / float(samplesInRing) * 6.28318530718;
            
            // Bokeh shape: interpolate between hexagonal and circular
            float shapeMultiplier = 1.0;
            if (uniforms.bokehRoundness < 1.0) {
                // Hexagonal approximation (6-sided)
                float hexAngle = fmod(angle, 1.0471975512); // π/3
                float hexRadius = cos(0.5235987756) / cos(hexAngle - 0.5235987756); // π/6
                shapeMultiplier = mix(hexRadius, 1.0, uniforms.bokehRoundness);
            }
            
            float2 offset = float2(
                cos(angle) * ringRadius * shapeMultiplier,
                sin(angle) * ringRadius * shapeMultiplier
            );
            
            int2 samplePos = int2(gid) + int2(round(offset.x), round(offset.y));
            
            // Bounds check
            if (samplePos.x < 0 || samplePos.x >= int(uniforms.imageWidth) ||
                samplePos.y < 0 || samplePos.y >= int(uniforms.imageHeight)) {
                continue;
            }
            
            uint2 uSamplePos = uint2(samplePos);
            float4 sampleColor = sourceTexture.read(uSamplePos);
            float4 sampleCoC = cocTexture.read(uSamplePos);
            float sampleCoCRadius = sampleCoC.y;
            float sampleCoCSign = sampleCoC.x;
            
            // Weight calculation:
            // 1. Samples should contribute proportional to their own CoC
            // 2. Background samples shouldn't bleed into foreground focus area
            // 3. Foreground samples can bleed slightly (controlled by foregroundBleed)
            
            float weight = 1.0;
            
            // Distance-based weight (samples closer to center are stronger)
            float dist = length(offset);
            weight *= smoothstep(blurRadius + 1.0, blurRadius * 0.5, dist);
            
            // CoC-based weight: only accept samples that are also blurry
            float cocWeight = smoothstep(0.0, 2.0, sampleCoCRadius);
            weight *= cocWeight;
            
            // Foreground/background separation
            if (centerSign > 0.0 && sampleCoCSign < -0.1) {
                // Center is background, sample is foreground — reduce weight
                weight *= uniforms.foregroundBleed;
            }
            
            // Bokeh highlight boost (bright samples contribute more)
            float luminance = dot(sampleColor.rgb, float3(0.2126, 0.7152, 0.0722));
            float highlightBoost = 1.0 + max(luminance - 0.8, 0.0) * 3.0;
            weight *= highlightBoost;
            
            colorSum += sampleColor * weight;
            weightSum += weight;
        }
    }
    
    float4 result = (weightSum > 0.0) ? colorSum / weightSum : sourceTexture.read(gid);
    result.a = 1.0;
    
    outputTexture.write(result, gid);
}

// MARK: - Combined Quick DoF (Single Pass for Preview)

/// Simplified single-pass DoF for realtime preview.
/// Uses fewer samples and simpler CoC calculation for performance.
kernel void applyQuickDoF(
    texture2d<float, access::read>  sourceTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant DoFUniforms &uniforms                [[buffer(0)]],
    uint2 gid                                     [[thread_position_in_grid]]
) {
    if (gid.x >= uint(uniforms.imageWidth) || gid.y >= uint(uniforms.imageHeight)) return;
    
    float4 centerColor = sourceTexture.read(gid);
    
    // Approximate depth from vertical position (top = far, bottom = near)
    // This is a rough approximation when no actual depth buffer is available
    float approxDepth = float(gid.y) / uniforms.imageHeight;
    
    // Simple CoC calculation
    float f = uniforms.focalLengthMM * 0.001;
    float N = uniforms.aperture;
    float S1 = uniforms.focusDistanceM;
    float S2 = 0.5 + approxDepth * 20.0; // Approximate scene depth
    
    float cocMetres = abs((f * f * (S2 - S1)) / (N * S2 * (S1 - f)));
    float sensorW = uniforms.sensorWidthMM * 0.001;
    float cocPixels = (cocMetres / sensorW) * uniforms.imageWidth * uniforms.cocScale;
    float blurRadius = min(cocPixels, uniforms.maxBlurRadius * 0.5);
    
    if (blurRadius < 0.5) {
        outputTexture.write(centerColor, gid);
        return;
    }
    
    // Quick 8-sample disk blur
    float4 sum = centerColor;
    float weight = 1.0;
    
    for (int i = 0; i < 8; i++) {
        float angle = float(i) * 0.7853981633975; // π/4
        float2 offset = float2(cos(angle), sin(angle)) * blurRadius;
        
        int2 samplePos = int2(gid) + int2(round(offset.x), round(offset.y));
        samplePos = clamp(samplePos, int2(0), int2(uniforms.imageWidth - 1, uniforms.imageHeight - 1));
        
        float4 sampleColor = sourceTexture.read(uint2(samplePos));
        float w = 1.0;
        sum += sampleColor * w;
        weight += w;
    }
    
    float4 result = sum / weight;
    result.a = 1.0;
    outputTexture.write(result, gid);
}
