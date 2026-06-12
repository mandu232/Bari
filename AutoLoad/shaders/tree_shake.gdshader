shader_type canvas_item;

// 바람 (잎 스프라이트용 — Body는 wind_strength=0으로 설정)
uniform float wind_speed    : hint_range(0.1, 5.0)   = 1.2;
uniform float wind_strength : hint_range(0.0, 20.0)  = 0.0;
uniform float time_offset   : hint_range(0.0, 100.0) = 0.0;

// 피격 흔들림 — GDScript에서 hit_strength를 1.0→0.0으로 트위닝
uniform float hit_strength  : hint_range(0.0, 1.0)   = 0.0;
uniform float hit_speed     : hint_range(1.0, 60.0)  = 26.0;
uniform float hit_amplitude : hint_range(0.0, 40.0)  = 14.0;

void vertex() {
	// UV.y=0: 텍스처 상단(나뭇가지/잎) → 최대 흔들림
	// UV.y=1: 텍스처 하단(뿌리)        → 고정
	float influence = 1.0 - UV.y;

	// 바람 흔들림
	float t    = TIME * wind_speed + time_offset;
	float wind = (sin(t) + sin(t * 2.7 + 1.3) * 0.15) * wind_strength;

	// 피격 흔들림 (hit_strength 감쇠로 자연스럽게 소멸)
	float hit  = sin(TIME * hit_speed) * hit_strength * hit_amplitude;

	VERTEX.x += (wind + hit) * influence;
}
