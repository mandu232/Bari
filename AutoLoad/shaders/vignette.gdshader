shader_type canvas_item;
uniform float intensity : hint_range(0.0, 3.0) = 0.55;
uniform float softness : hint_range(0.1, 1.0) = 0.40;
uniform vec4 tint_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
void fragment() {
    vec2 uv = UV - 0.5;
    float dist = length(uv * vec2(1.0, 1.15));
    float vig = smoothstep(softness, softness + max(intensity, 0.001), dist);
    COLOR = vec4(tint_color.rgb, vig * tint_color.a * step(0.001, intensity));
}
