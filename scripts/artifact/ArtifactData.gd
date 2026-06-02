extends Resource
class_name ArtifactData

enum Era {
	UNKNOWN       = 0,
	PALEOLITHIC   = 1,   # 구석기
	NEOLITHIC     = 2,   # 신석기
	BRONZE_AGE    = 3,   # 청동기
	IRON_AGE      = 4,   # 철기
	THREE_KINGDOMS = 5,  # 삼국
	UNIFIED_SILLA = 6,   # 통일신라
	GORYEO        = 7,   # 고려
	JOSEON        = 8,   # 조선
}

static func era_label(e: Era) -> String:
	match e:
		Era.PALEOLITHIC:    return "구석기"
		Era.NEOLITHIC:      return "신석기"
		Era.BRONZE_AGE:     return "청동기"
		Era.IRON_AGE:       return "철기"
		Era.THREE_KINGDOMS: return "삼국"
		Era.UNIFIED_SILLA:  return "통일신라"
		Era.GORYEO:         return "고려"
		Era.JOSEON:         return "조선"
		_:                  return "미분류"

@export_group("기본 정보")
@export var artifact_name: String       = "이름 없는 유물"
@export var description: String         = ""
@export var texture: Texture2D          = null   # 전시대 위에 표시될 스프라이트
@export var era: Era                    = Era.UNKNOWN

@export_group("Echo 정보")
@export var echo_name: String           = "이름 없는 에코"
@export var echo_frames: SpriteFrames   = null   # Echo 프레임
@export var echo_power: int             = 1      # Echo의 강도 (던전 버프 등에 사용)
@export var wander_radius: float        = 64.0   # 전시대 주변 배회 반경

@export_group("효과")
@export var essence_per_second: float   = 0.5    # 초당 영력 생성량
@export var passive_description: String = ""     # 패시브 효과 설명 (UI 표시용)

@export_group("에코 욕구 감소율")
## 기본값은 모든 에코 공통 — 유물마다 다르게 설정하면 해당 에코에만 적용됩니다
@export var stability_decay: float = 1.0   ## 안정도 초당 감소량 (기본 1.0)
@export var output_decay:    float = 0.7   ## 출력 초당 감소량 (기본 0.7)
@export var activity_decay:  float = 2.2   ## 활성도 초당 감소량 (기본 2.2)

@export_group("플레이어 스탯 보너스 범위")
@export var bonus_health_max:    int   = 0     ## 최대 체력 보너스 상한 (획득 시 0~이 값 사이 랜덤)
@export var bonus_damage_max:    int   = 0     ## 공격력 보너스 상한
@export var bonus_speed_max:     float = 0.0   ## 이동 속도 보너스 상한
@export var bonus_dash_max:      float = 0.0   ## 대시 쿨타임 감소 상한

## 획득 시 roll_bonuses()로 결정되는 실제 수치 — 저장/로드 대상
var bonus_max_health:    int   = 0
var bonus_attack_damage: int   = 0
var bonus_move_speed:    float = 0.0
var bonus_dash_cooldown: float = 0.0

func roll_bonuses() -> void:
	bonus_max_health    = 0
	bonus_attack_damage = 0
	bonus_move_speed    = 0.0
	bonus_dash_cooldown = 0.0

	# 상한이 0보다 큰 스탯 중 하나만 랜덤으로 선택
	var candidates: Array[StringName] = []
	if bonus_health_max > 0:   candidates.append(&"health")
	if bonus_damage_max > 0:   candidates.append(&"damage")
	if bonus_speed_max  > 0.0: candidates.append(&"speed")
	if bonus_dash_max   > 0.0: candidates.append(&"dash")
	if candidates.is_empty():
		return

	match candidates.pick_random():
		&"health": bonus_max_health    = randi_range(1, bonus_health_max)
		&"damage": bonus_attack_damage = randi_range(1, bonus_damage_max)
		&"speed":  bonus_move_speed    = randf_range(0.1, bonus_speed_max)
		&"dash":   bonus_dash_cooldown = randf_range(0.05, bonus_dash_max)
