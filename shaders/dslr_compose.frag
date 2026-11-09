#version 460 core
#include <flutter/runtime_effect.glsl>

// Match the exact uniform order from DslrCompositor.render in dslr_compositor.dart
uniform vec2 uSize;
uniform float uMaxRadius;
uniform float uUseDepth;
uniform float uFocusDepth;
uniform float uFocusRange;
uniform float uHlThreshold;
uniform float uHlBoost;
uniform float uLightsAmount;
uniform float uLightCell;
uniform float uLightDensity;
uniform float uFeather;
uniform float uSharpen;
uniform float uExposure;
uniform float uWarmth;
uniform float uSatSubject;
uniform float uSatBackground;
uniform float uGreenToOlive;
uniform float uContrast;
uniform float uShoulder;
uniform float vignette;
uniform vec3 uShadowTint;

uniform sampler2D uImage;
uniform sampler2D uMask;
uniform sampler2D uDepth;

out vec4 fragColor;

// Pseudo-random hash for bokeh disk jitter
float hash21(vec2 p) {
    p = fract(p * vec2(234.34, 435.345));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

// Convert RGB to Luminance
float luminance(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// Color temperature / warmth shift
vec3 applyWarmth(vec3 c, float w) {
    c.r += w * 0.15;
    c.b -= w * 0.15;
    return c;
}

// Saturation adjustment
vec3 applySaturation(vec3 c, float sat) {
    float l = luminance(c);
    return mix(vec3(l), c, sat);
}

// Foliage color shift (shift pure harsh green towards cinematic olive)
vec3 applyGreenToOlive(vec3 c, float amount) {
    if (amount <= 0.0) return c;
    if (c.g > c.r && c.g > c.b) {
        float excess = c.g - max(c.r, c.b);
        c.r += excess * 0.45 * amount;
        c.g -= excess * 0.20 * amount;
        c.b -= excess * 0.15 * amount;
    }
    return c;
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / uSize;

    // 1. Sample Mask and Depth
    // Mask is stored in R channel (1.0 = subject, 0.0 = background)
    float maskVal = texture(uMask, uv).r;

    // Smooth feathering at the mask edge if requested
    if (uFeather > 0.5) {
        vec2 d = vec2(uFeather) / uSize;
        float m0 = texture(uMask, uv + vec2(-d.x, 0.0)).r;
        float m1 = texture(uMask, uv + vec2( d.x, 0.0)).r;
        float m2 = texture(uMask, uv + vec2(0.0, -d.y)).r;
        float m3 = texture(uMask, uv + vec2(0.0,  d.y)).r;
        maskVal = (maskVal * 2.0 + m0 + m1 + m2 + m3) / 6.0;
    }

    float depthVal = texture(uDepth, uv).r;

    // 2. Compute Circle of Confusion / Blur Radius
    float blurFactor = 0.0;
    if (uMaxRadius > 0.01) {
        if (uUseDepth > 0.5) {
            float depthDiff = abs(depthVal - uFocusDepth);
            blurFactor = clamp(depthDiff / max(uFocusRange, 0.001), 0.0, 1.0);
            // Invert effect for subject: subject should stay sharp
            blurFactor = blurFactor * (1.0 - maskVal);
        } else {
            // Segmentation-only bokeh (everything not in mask gets blurred)
            blurFactor = 1.0 - maskVal;
        }
    }

    float radius = blurFactor * uMaxRadius;

    // 3. Multi-tap Bokeh Disk Blur
    vec3 col = vec3(0.0);
    float totalWeight = 0.0;

    if (radius < 0.75) {
        col = texture(uImage, uv).rgb;
        totalWeight = 1.0;
    } else {
        const int NUM_SAMPLES = 16;
        const float GOLDEN_ANGLE = 2.39996323;

        for (int i = 0; i < NUM_SAMPLES; i++) {
            float fi = float(i);
            float r = sqrt((fi + 0.5) / float(NUM_SAMPLES)) * radius;
            float theta = fi * GOLDEN_ANGLE;
            vec2 offset = vec2(cos(theta), sin(theta)) * r / uSize;

            vec3 sampleColor = texture(uImage, uv + offset).rgb;
            float sampleMask = texture(uMask, uv + offset).r;

            // Bokeh highlight boost
            float lum = luminance(sampleColor);
            float hlWeight = 1.0;
            if (lum > uHlThreshold) {
                hlWeight += pow((lum - uHlThreshold) / max(1.0 - uHlThreshold, 0.01), 2.0) * uHlBoost;
            }

            // Weight background samples more for blurred areas to prevent subject bleeding into bokeh
            float weight = hlWeight * (1.0 - sampleMask * 0.7);
            col += sampleColor * weight;
            totalWeight += weight;
        }

        col /= max(totalWeight, 0.0001);

        // Blend sharp subject back according to mask
        if (maskVal > 0.01) {
            vec3 sharpSubject = texture(uImage, uv).rgb;
            col = mix(col, sharpSubject, maskVal);
        }
    }

    // 4. Subject Sharpening (Unsharp masking)
    if (uSharpen > 0.01 && maskVal > 0.1) {
        vec2 p = 1.0 / uSize;
        vec3 center = texture(uImage, uv).rgb;
        vec3 blurredCenter = (
            texture(uImage, uv + vec2(-p.x, 0.0)).rgb +
            texture(uImage, uv + vec2( p.x, 0.0)).rgb +
            texture(uImage, uv + vec2(0.0, -p.y)).rgb +
            texture(uImage, uv + vec2(0.0,  p.y)).rgb
        ) * 0.25;
        vec3 sharp = center + (center - blurredCenter) * uSharpen;
        col = mix(col, sharp, maskVal);
    }

    // 5. Decorative Bokeh Circles / Fairy Lights
    if (uLightsAmount > 0.01 && uLightCell > 4.0 && (1.0 - maskVal) > 0.2) {
        vec2 grid = fragCoord / uLightCell;
        vec2 id = floor(grid);
        vec2 gv = fract(grid) - 0.5;

        float rnd = hash21(id);
        if (rnd < uLightDensity) {
            float dist = length(gv);
            float circle = smoothstep(0.45, 0.35, dist);
            vec3 lightColor = mix(vec3(1.0, 0.85, 0.65), vec3(0.7, 0.85, 1.0), hash21(id + 1.23));
            col += lightColor * circle * uLightsAmount * (1.0 - maskVal) * 0.6;
        }
    }

    // 6. Color Grading & Tone Curve
    // Exposure compensation
    col *= pow(2.0, uExposure);

    // Warmth adjustment
    col = applyWarmth(col, uWarmth);

    // Green to olive foliage grading
    col = applyGreenToOlive(col, uGreenToOlive);

    // Subject-aware saturation
    float targetSat = mix(uSatBackground, uSatSubject, maskVal);
    col = applySaturation(col, targetSat);

    // Contrast with highlight shoulder roll-off
    col = (col - 0.5) * uContrast + 0.5;
    if (uShoulder < 0.99) {
        vec3 over = max(col - vec3(uShoulder), vec3(0.0));
        col = col - over * 0.45;
    }

    // Shadow tint
    float l = luminance(col);
    float shadowFactor = clamp(1.0 - l * 2.0, 0.0, 1.0);
    col += uShadowTint * shadowFactor;

    // 7. Vignette
    if (vignette > 0.01) {
        vec2 coord = (uv - 0.5) * vec2(uSize.x / uSize.y, 1.0);
        float vig = clamp(1.0 - dot(coord, coord) * vignette * 1.8, 0.0, 1.0);
        col *= vig;
    }

    col = clamp(col, 0.0, 1.0);
    fragColor = vec4(col, 1.0);
}
