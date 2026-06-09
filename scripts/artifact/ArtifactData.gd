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

## 원본 .tres 경로 — duplicate() 후 resource_path 를 덮어쓰지 않고 여기에 보존
## (resource_path 직접 할당은 Godot 리소스 캐시 충돌 에러를 유발)
var source_path: String = ""

@export_group("기본 정보")
@export var artifact_name: String       = "이름 없는 유물"
@export var description: String         = ""
@export var texture: Texture2D          = null
@export var era: Era                    = Era.UNKNOWN

@export_group("Echo 정보")
@export var echo_name: String           = "이름 없는 에코"
@export var echo_description: String    = ""
@export var echo_frames: SpriteFrames   = null
@export var echo_power: int             = 1
@export var wander_radius: float        = 64.0

@export_group("스킬")
@export var skill_script: Script = null   ## 이 유물 장착 시 발동되는 스킬 스크립트

@export_group("효과")
@export var essence_per_second: float   = 0.5
@export var passive_description: String = ""

@export_group("에코 욕구 감소율")
@export var stability_decay: float = 1.0
@export var output_decay:    float = 0.7
@export var activity_decay:  float = 2.2

@export_group("전시 스탯 보너스 범위")
@export var bonus_atk_max:      int   = 0    ## 공격력 보너스 상한 (전시 시 랜덤 결정)
@export var bonus_atk_spd_max:  int   = 0    ## 공격속도 보너스 상한 (%)
@export var bonus_def_max:      int   = 0    ## 방어력 보너스 상한
@export var bonus_move_spd_max: float = 0.0  ## 이동속도 보너스 상한
@export var bonus_hp_max:       int   = 0    ## 체력 보너스 상한

## 획득 시 roll_bonuses()로 결정되는 실제 수치 — 저장/로드 대상 (전시대에 올릴 때 적용)
var bonus_attack:       int   = 0
var bonus_attack_speed: int   = 0
var bonus_defense:      int   = 0
var bonus_move_speed:   float = 0.0
var bonus_max_health:   int   = 0

@export_group("장착 스탯 보너스 범위")
@export var equip_bonus_atk_max:      int   = 0    ## 공격력 장착 보너스 상한 (획득 시 랜덤 결정)
@export var equip_bonus_atk_spd_max:  int   = 0    ## 공격속도 장착 보너스 상한 (%)
@export var equip_bonus_def_max:      int   = 0    ## 방어력 장착 보너스 상한
@export var equip_bonus_move_spd_max: float = 0.0  ## 이동속도 장착 보너스 상한
@export var equip_bonus_hp_max:       int   = 0    ## 체력 장착 보너스 상한

## 획득 시 roll_equip_bonuses()로 결정되는 실제 수치
var equip_bonus_atk:      int   = 0
var equip_bonus_atk_spd:  int   = 0
var equip_bonus_def:      int   = 0
var equip_bonus_move_spd: float = 0.0
var equip_bonus_hp:       int   = 0

## 합성 강화 레벨 (최대 MAX_ENHANCE_LEVEL)
const MAX_ENHANCE_LEVEL: int = 5
var enhance_level: int = 0

# ── 강화 레벨 포함 전시 보너스 (전시대에 올릴 때 사용)
func total_attack() -> int:
	return bonus_attack + (enhance_level if bonus_attack > 0 else 0)

func total_attack_speed() -> int:
	return bonus_attack_speed + (enhance_level if bonus_attack_speed > 0 else 0)

func total_defense() -> int:
	return bonus_defense + (enhance_level if bonus_defense > 0 else 0)

func total_move_speed() -> float:
	return bonus_move_speed + (float(enhance_level) * 2.0 if bonus_move_speed > 0.0 else 0.0)

func total_max_health() -> int:
	return bonus_max_health + (enhance_level if bonus_max_health > 0 else 0)

# ── 강화 레벨 포함 장착 보너스 (유물 장착 시 사용)
func total_equip_atk() -> int:
	return equip_bonus_atk + (enhance_level if equip_bonus_atk > 0 else 0)

func total_equip_atk_spd() -> int:
	return equip_bonus_atk_spd + (enhance_level if equip_bonus_atk_spd > 0 else 0)

func total_equip_def() -> int:
	return equip_bonus_def + (enhance_level if equip_bonus_def > 0 else 0)

func total_equip_move_spd() -> float:
	return equip_bonus_move_spd + (float(enhance_level) * 2.0 if equip_bonus_move_spd > 0.0 else 0.0)

func total_equip_hp() -> int:
	return equip_bonus_hp + (enhance_level if equip_bonus_hp > 0 else 0)

func roll_bonuses() -> void:
	bonus_attack       = 0
	bonus_attack_speed = 0
	bonus_defense      = 0
	bonus_move_speed   = 0.0
	bonus_max_health   = 0

	var candidates: Array[StringName] = []
	if bonus_atk_max      > 0:   candidates.append(&"atk")
	if bonus_atk_spd_max  > 0:   candidates.append(&"atk_spd")
	if bonus_def_max      > 0:   candidates.append(&"def")
	if bonus_move_spd_max > 0.0: candidates.append(&"spd")
	if bonus_hp_max       > 0:   candidates.append(&"hp")
	if candidates.is_empty():
		return

	match candidates.pick_random():
		&"atk":     bonus_attack       = randi_range(1, bonus_atk_max)
		&"atk_spd": bonus_attack_speed = randi_range(1, bonus_atk_spd_max)
		&"def":     bonus_defense      = randi_range(1, bonus_def_max)
		&"spd":     bonus_move_speed   = randf_range(1.0, bonus_move_spd_max)
		&"hp":      bonus_max_health   = randi_range(1, bonus_hp_max)

func roll_equip_bonuses() -> void:
	equip_bonus_atk      = randi_range(1, equip_bonus_atk_max)           if equip_bonus_atk_max      > 0   else 0
	equip_bonus_atk_spd  = randi_range(1, equip_bonus_atk_spd_max)       if equip_bonus_atk_spd_max  > 0   else 0
	equip_bonus_def      = randi_range(1, equip_bonus_def_max)           if equip_bonus_def_max      > 0   else 0
	equip_bonus_move_spd = randf_range(1.0, equip_bonus_move_spd_max)    if equip_bonus_move_spd_max > 0.0 else 0.0
	equip_bonus_hp       = randi_range(1, equip_bonus_hp_max)             if equip_bonus_hp_max       > 0   else 0
