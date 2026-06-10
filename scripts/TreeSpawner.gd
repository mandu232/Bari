@tool
extends Node2D
class_name TreeSpawner
## 지정한 영역 안에 Tree 씬을 랜덤으로 뿌리는 스폰어.
## GrassSpawner / SmallGrassSpawner 와 동일한 방식으로 동작.
## 씬에 Node2D 를 만들고 이 스크립트를 붙여 사용.

const TREE_SCENES: Array = [
	"res://AutoLoad/scenes/Tree/Tree_type1.tscn",
	"res://AutoLoad/scenes/Tree/Tree_type2.tscn",
]

@export_group("영역")
@export var area_size: Vector2 = Vector2(200, 80):
	set(v): area_size = v; queue_redraw()

@export_group("배치")
@export var count: int = 6:
	set(v): count = v; queue_redraw()

## 0 = 실행마다 랜덤 / 양수 = 고정 시드 (에디터 미리보기도 고정됨)
@export var rand_seed: int = 1:
	set(v): rand_seed = v; queue_redraw()

## 그리드 스냅 간격 픽셀 (0 = 비활성)
@export_range(0, 64, 1) var grid_snap: int = 16:
	set(v): grid_snap = v; queue_redraw()

## 나무 간 최소 거리 (픽셀). 너무 붙어서 심기는 것을 방지.
@export_range(0, 200, 1) var min_distance: int = 32:
	set(v): min_distance = v; queue_redraw()

## 각 나무의 스케일을 랜덤으로 살짝 변화 (1.0 = 변화 없음)
@export var scale_min: float = 0.85:
	set(v): scale_min = v; queue_redraw()
@export var scale_max: float = 1.15:
	set(v): scale_max = v; queue_redraw()

# ── 런타임 전용: 실제 스폰 ─────────────────────────────
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = rand_seed if rand_seed != 0 else randi()

	var placed: Array[Vector2] = []

	for _i in count:
		var pos := _try_place(rng, placed)
		if pos == Vector2.INF:
			continue
		placed.append(pos)

		var scene_path: String = TREE_SCENES[rng.randi() % TREE_SCENES.size()]
		var packed := load(scene_path) as PackedScene
		if packed == null:
			continue
		var tree := packed.instantiate() as Node2D
		tree.position = pos
		var s := rng.randf_range(scale_min, scale_max)
		tree.scale    = Vector2(s, s)
		add_child(tree)

# ── 에디터 기즈모: 영역 + 배치 예상 위치 표시 ─────────
func _draw() -> void:
	if not Engine.is_editor_hint():
		return

	var rect := Rect2(-area_size * 0.5, area_size)
	draw_rect(rect, Color(0.35, 0.55, 0.15, 0.08), true)
	draw_rect(rect, Color(0.35, 0.55, 0.15, 0.75), false, 1.5)

	if rand_seed == 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = rand_seed
	var placed: Array[Vector2] = []

	for _i in count:
		var pos := _try_place(rng, placed)
		if pos == Vector2.INF:
			continue
		placed.append(pos)
		# 나무 크기 가늠할 수 있도록 원으로 표시
		draw_circle(pos, 8.0, Color(0.3, 0.7, 0.1, 0.55))
		draw_circle(pos, 3.0, Color(0.5, 0.9, 0.2, 0.90))

# ── 배치 시도: min_distance 만족할 때만 허용 (최대 20회 재시도) ──
func _try_place(rng: RandomNumberGenerator, placed: Array[Vector2]) -> Vector2:
	var max_tries := 20
	for _t in max_tries:
		var pos := _random_pos(rng)
		if _is_far_enough(pos, placed):
			return pos
	return Vector2.INF

# ── 기존 배치와 최소 거리 충족 여부 ───────────────────
func _is_far_enough(pos: Vector2, placed: Array[Vector2]) -> bool:
	var dist_sq := float(min_distance * min_distance)
	for p in placed:
		if pos.distance_squared_to(p) < dist_sq:
			return false
	return true

# ── 공통 헬퍼 ─────────────────────────────────────────
func _random_pos(rng: RandomNumberGenerator) -> Vector2:
	var x := rng.randf_range(-area_size.x * 0.5, area_size.x * 0.5)
	var y := rng.randf_range(-area_size.y * 0.5, area_size.y * 0.5)
	if grid_snap > 0:
		x = snappedf(x, float(grid_snap))
		y = snappedf(y, float(grid_snap))
	return Vector2(x, y)
