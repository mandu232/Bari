shader_type canvas_item;
uniform float wind_speed : hint_range(0.1, 5.0) = 1.2;
uniform float wind_strength : hint_range(0.0, 20.0) = 3.5;
uniform float time_offset : hint_range(0.0, 100.0) = 0.0;
void vertex() {
    float t = TIME * wind_speed + time_offset;
    float sway = sin(t) * wind_strength + sin(t * 2.7 + 1.3) * wind_strength * 0.15;
    float influence = 1.0 - UV.y;
    VERTEX.x += sway * influence;
}
