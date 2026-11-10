#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float radius;
    vec2 panelSize;
    vec2 captureSize;
    vec2 captureOffset;
    float tintAmount;
    float darkAmount;
    float refraction;
    float materialization;
    float frost;
};
layout(binding = 1) uniform sampler2D sharpSource;
layout(binding = 2) uniform sampler2D softSource;
float roundBox(vec2 p, vec2 halfSize, float r) {
    vec2 q = abs(p) - halfSize + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
void main() {
    vec2 p = qt_TexCoord0 * panelSize;
    vec2 centered = p - panelSize * 0.5;
    float r = min(radius, min(panelSize.x, panelSize.y) * 0.5);
    float d = roundBox(centered, panelSize * 0.5 - 0.5, r);
    float aa = max(fwidth(d), 0.6);
    float mask = 1.0 - smoothstep(-aa, aa, d);
    vec2 q = abs(centered) - (panelSize * 0.5 - vec2(r + 0.5));
    vec2 normal = normalize(max(q, vec2(0.0001))) * sign(centered);
    if (max(q.x, q.y) < 0.0)
        normal = q.x > q.y ? vec2(sign(centered.x), 0) : vec2(0, sign(centered.y));
    float depth = max(-d, 0.0);
    float lens = exp(-depth / 7.0);
    vec2 bend = -normal * lens * refraction * materialization;
    vec2 uv = clamp((p + captureOffset + bend) / captureSize, vec2(0.001), vec2(0.999));
    vec3 blurred = texture(softSource, uv).rgb;
    vec3 clear = texture(sharpSource, uv).rgb;
    vec3 color = mix(blurred, clear, lens * (1.0 - frost) * 0.42);
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color = mix(vec3(luma), color, 1.12);
    vec3 tint = mix(vec3(0.98, 0.985, 1.0), vec3(0.095, 0.105, 0.12), darkAmount);
    float adaptiveTint = tintAmount + (1.0 - darkAmount) * (1.0 - luma) * 0.055;
    color = mix(color, tint, clamp(adaptiveTint, 0.0, 1.0));
    // Directional specular rim and inner falloff, rather than a uniform border.
    float light = dot(normal, normalize(vec2(-0.36, -0.93)));
    float rim = exp(-depth * 1.6) * materialization;
    float highlight = (0.15 + max(light, 0.0) * 0.40) * rim;
    float innerShadow = exp(-abs(depth - 1.6) * 1.3) * (0.025 + max(-light, 0.0) * 0.055);
    color = color * (1.0 - innerShadow) + vec3(highlight);
    float grain = fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
    color += grain / 420.0;
    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0) * mask * qt_Opacity;
}
