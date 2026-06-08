@tool
extends Node2D
class_name SmallGrassSpawner
## 지정한 영역 안에 SmallGrass 씬을 자동으로 뿌리는 스폰어.
## 던전 씬에 Node2D 를 만들고 이 스크립트를 붙여 사용.

const SMALL_GRASS_SCENE := preload("res://AutoLoad/scenes/SmallGrass.tscn")

@export_group("영역")
@export var area_size: Vector2 = Vector2(96, 20):
	set(v): area_size = v; queue_redraw()

@export_group("배치")
@export var count: int = 12:
	set(v): count = v; queue_redraw()

## 0 = 실행마다 랜덤 / 양수 = 고정 시드 (에디터 미리보기도 고정됨)
@export var rand_seed: int = 1:
	set(v): rand_seed = v; queue_redraw()

## 그리드 스냅 간격 픽셀 (0 = 비활성)
@export_range(0, 32, 1) var grid_snap: int = 8:
	set(v): grid_snap = v; queue_redraw()

# ── 런타임 전용: 실제 스폰 ─────────────────────────────
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = rand_seed if rand_seed != 0 else randi()
	for _i in count:
		var pos := _random_pos(rng)
		var grass := SMALL_GRASS_SCENE.instantiate() as Node2D
		grass.position = pos
		add_child(grass)

# ── 에디터 기즈모: 영역 + 배치 예상 위치 표시 ─────────
func _draw() -> void:
	if not Engine.is_editor_hint():
		return

	var rect := Rect2(-area_size * 0.5, area_size)
	draw_rect(rect, Color(0.2, 0.9, 0.3, 0.07), true)
	draw_rect(rect, Color(0.2, 0.9, 0.3, 0.6), false, 1.0)

	if rand_seed == 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = rand_seed
	for _i in count:
		var pos := _random_pos(rng)
		draw_circle(pos, 2.0, Color(0.2, 1.0, 0.3, 0.8))

# ── 공통 헬퍼 ─────────────────────────────────────────
func _random_pos(rng: RandomNumberGenerator) -> Vector2:
	var x := rng.randf_range(-area_size.x * 0.5, area_size.x * 0.5)
	var y := rng.randf_range(-area_size.y * 0.5, area_size.y * 0.5)
	if grid_snap > 0:
		x = snappedf(x, float(grid_snap))
		y = snappedf(y, float(grid_snap))
	return Vector2(x, y)
