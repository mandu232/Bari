extends Resource
class_name TalismanData
## 부적 데이터 리소스 — 던전 전용 강화 아이템

enum Effect {
	NONE,
	LIFESTEAL,    # 적 처치 시 체력 회복
	SPEED_BURST,  # 적 처치 시 이동속도 일시 증가
	SHIELD,       # 첫 피격 1회 무효
	HOWL_MIMIC,   # 적 처치 시 주변 적 이동속도 감소 (둔화)
	GOBLIN_AMBUSH,   # 피격 없이 N초 경과 시 다음 기습 공격 3배 피해
	MOUNTAIN_WEIGHT, # 막기 마나 소모 절감 + 패링 성공 시 마나 회복
}

@export var talisman_name:  String    = "이름 없는 부적"
@export_multiline var description: String = ""
@export var icon:           Texture2D = null
@export var card_color:     Color     = Color(0.65, 0.50, 0.30, 1.0)  # 카드 테두리/배경 색

@export_group("스탯 보너스")
@export var bonus_atk:   int   = 0
@export var bonus_def:   int   = 0
@export var bonus_hp:    int   = 0    # 최대 체력 증가
@export var bonus_speed: float = 0.0

@export_group("특수 효과")
@export var effect:       Effect = Effect.NONE
@export var effect_value: float  = 0.0  # 효과 강도 (회복량, 지속시간 등)

## 부적 설명 한 줄 요약 (HUD 툴팁 등에서 사용)
func get_stat_summary() -> String:
	var parts: Array[String] = []
	if bonus_atk   > 0: parts.append("공격력 +%d"     % bonus_atk)
	if bonus_def   > 0: parts.append("방어력 +%d"     % bonus_def)
	if bonus_hp    > 0: parts.append("최대체력 +%d"   % bonus_hp)
	if bonus_speed > 0: parts.append("이동속도 +%.0f" % bonus_speed)
	match effect:
		Effect.LIFESTEAL:   parts.append("적 처치 시 HP 회복")
		Effect.SPEED_BURST: parts.append("적 처치 시 속도 증가")
		Effect.SHIELD:      parts.append("피격 1회 무효")
		Effect.HOWL_MIMIC:   parts.append("적 처치 시 주변 적 둔화")
		Effect.GOBLIN_AMBUSH:    parts.append("기습 공격 시 3배 피해")
		Effect.MOUNTAIN_WEIGHT:  parts.append("막기 마나 절감 + 패링 시 마나 회복")
	return "  ".join(parts)
