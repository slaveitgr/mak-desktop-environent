#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    vec2 windowSize;
    vec4 destination;
};
layout(binding = 1) uniform sampler2D source;
void main() {
    vec2 q = abs(qt_TexCoord0 * windowSize - windowSize * 0.5) - windowSize * 0.5 + 25.0;
    float d = length(max(q,0.0)) + min(max(q.x,q.y),0.0) - 25.0;
    float mask = 1.0 - smoothstep(-1.0,0.5,d);
    fragColor = texture(source, qt_TexCoord0) * qt_Opacity * mask;
}
