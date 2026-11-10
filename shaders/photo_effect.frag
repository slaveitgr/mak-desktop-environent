#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float effectCode;
    float flipHorizontal;
};
layout(binding = 1) uniform sampler2D source;
vec3 linearRGB(vec3 value) {
    return mix(value / 12.92, pow((value + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), value));
}
float srgb(float value) {
    return value <= 0.0031308 ? 12.92 * value : 1.055 * pow(value, 1.0 / 2.4) - 0.055;
}
void main() {
    vec2 uv = qt_TexCoord0;
    if (effectCode > 2.5) uv.x = min(uv.x, 1.0 - uv.x);
    if (flipHorizontal > 0.5) uv.x = 1.0 - uv.x;
    vec4 pixel = texture(source, uv);
    vec3 color = pixel.a > 0.0 ? pixel.rgb / pixel.a : vec3(0.0);
    if (effectCode > 0.5 && effectCode < 2.5) {
        float luminance = dot(linearRGB(color), vec3(0.2126, 0.7152, 0.0722));
        float gray = floor(clamp(srgb(luminance), 0.0, 1.0) * 255.0 + 0.5) / 255.0;
        color = vec3(gray);
        if (effectCode > 1.5) {
            color = min(vec3(1.0), gray * vec3(1.15, 0.95, 0.70) + vec3(10.0, 8.0, 3.0) / 255.0);
            color = floor(color * 255.0 + 0.5) / 255.0;
        }
    }
    fragColor = vec4(color * pixel.a, pixel.a) * qt_Opacity;
}
