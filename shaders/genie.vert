#version 440
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    vec2 windowSize;
    vec4 destination;
};
void main() {
    qt_TexCoord0 = qt_MultiTexCoord0;
    vec2 uv = qt_MultiTexCoord0;
    float t = clamp(progress, 0.0, 1.0);
    float funnel = smoothstep(0.0, 0.68, t);
    float suction = smoothstep(0.28, 1.0, t);
    float neck = funnel * smoothstep(0.0, 1.0, uv.y);
    float collapse = mix(neck, 1.0, suction);
    float center = mix(windowSize.x * 0.5, destination.x + destination.z * 0.5, collapse);
    float span = mix(windowSize.x, destination.z, collapse);
    vec2 p;
    p.x = center + (uv.x - 0.5) * span;
    float rowTravel = smoothstep(0.07 * (1.0 - uv.y), 1.0, t);
    p.y = mix(qt_Vertex.y, destination.y + uv.y * destination.w, rowTravel);
    gl_Position = qt_Matrix * vec4(p, qt_Vertex.zw);
}
