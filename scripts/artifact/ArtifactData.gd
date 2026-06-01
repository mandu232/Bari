extends Resource
class_name ArtifactData

@export_group("기본 정보")
@export var artifact_name: String       = "이름 없는 유물"
@export var description: String         = ""
@export var texture: Texture2D          = null   # 전시대 위에 표시될 스프라이트

@export_group("Echo 정보")
@export var echo_name: String           = "이름 없는 에코"
@export var echo_frames: SpriteFrames   = null   # Echo 프레임
@export var echo_power: int             = 1      # Echo의 강도 (던전 버프 등에 사용)
@export var wander_radius: float        = 64.0   # 전시대 주변 배회 반경

@export_group("효과")
@export var essence_per_second: float   = 0.5    # 초당 영력 생성량
@export var passive_description: String = ""     # 패시브 효과 설명 (UI 표시용)

@export_group("플레이어 스탯 보너스 (기본값)")
## 유물 획득 시 ±2 범위 내에서 랜덤 산출되는 기준값
@export var base_health_bonus: int   = 0    # 기본 체력 보너스
@export var base_damage_bonus: int   = 0    # 기본 공격력 보너스
@export var base_speed_bonus:  float = 0.0  # 기본 이동속도 보너스

## 획득 시 확정된 실제 스탯 (roll_stats() 로 설정됨)
var rolled_health: int   = 0
var rolled_damage: int   = 0
var rolled_speed:  float = 0.0

## 유물 획득 시 한 번 호출 — 기본값 기준 ±2 범위에서 실제 스탯 산출
func roll_stats() -> void:
	rolled_health = maxi(0, base_health_bonus + randi_range(-2, 2))
	rolled_damage = maxi(0, base_damage_bonus + randi_range(-2, 2))
	rolled_speed  = maxf(0.0, base_speed_bonus + randf_range(-2.0, 2.0))

@export_group("에코 욕구 감소율")
## 기본값은 모든 에코 공통 — 유물마다 다르게 설정하면 해당 에코에만 적용됩니다
@export var stability_decay: float = 1.0   ## 안정도 초당 감소량 (기본 1.0)
@export var output_decay:    float = 0.7   ## 출력 초당 감소량 (기본 0.7)
@export var activity_decay:  float = 2.2   ## 활성도 초당 감소량 (기본 2.2)
