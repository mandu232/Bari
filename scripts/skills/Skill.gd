extends Node
class_name Skill
## 스킬 베이스 클래스
## 새 스킬은 이 클래스를 상속하고 execute(player) 만 오버라이드하면 됩니다.

@export var skill_name: String  = "스킬"
@export var cooldown:   float   = 3.0
@export var icon:       Texture2D = null

var _cd_remaining: float = 0.0

func _process(delta: float) -> void:
	if _cd_remaining > 0.0:
		_cd_remaining -= delta

## 쿨다운이 끝났으면 true
func can_use() -> bool:
	return _cd_remaining <= 0.0

## 쿨다운 진행도 0.0(준비)~1.0(방금 사용)
func cooldown_ratio() -> float:
	return clampf(_cd_remaining / cooldown, 0.0, 1.0)

## 스킬 실행 — 서브클래스에서 오버라이드
## can_use() 확인 + _start_cooldown() 호출은 서브클래스 책임
func execute(player: CharacterBody2D) -> void:
	pass

func _start_cooldown() -> void:
	_cd_remaining = cooldown
