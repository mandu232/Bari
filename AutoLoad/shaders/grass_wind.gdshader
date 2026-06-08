shader_type canvas_item;
uniform float wind_speed : hint_range(0.1, 5.0) = 1.5;
uniform float wind_strength : hint_range(0.0, 10.0) = 2.0;
uniform float time_offset : hint_range(0.0, 100.0) = 0.0;
uniform float bend : hint_range(-40.0, 40.0) = 0.0;
void vertex() {
    float t = 1.0 - UV.y;
    float sway = sin(TIME * wind_speed + time_offset) * wind_strength
               + sin(TIME * wind_speed * 2.3 + time_offset + 0.7) * wind_strength * 0.2;
    VERTEX.x += sway * t + bend * t * t;
}
void fragment() {
    COLOR = texture(TEXTURE, UV);
}
